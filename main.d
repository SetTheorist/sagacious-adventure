//import core.thread;
import std.algorithm;
import std.conv;
import std.math;
import std.random;
import std.stdio;
import std.string;

immutable bool use_sdl = true;
static if (use_sdl) {
    import derelict.sdl2.sdl;
    //import derelict.sdl2.image;
    //import derelict.sdl2.mixer;
    //import derelict.sdl2.ttf;
    //import derelict.sdl2.net;
} else {
    import terminal;
}

import item;
import map;
import path;
import priority_queue;
import rational_lib;
import rng;
import ui;
import util;

////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

static if (use_sdl)
SDL_Texture* LoadSprite(string file, SDL_Renderer *renderer, out int texture_w, out int texture_h)
{
    SDL_Surface* surf;
    SDL_Texture* texture;

    /* Load the texture image */
    surf = SDL_LoadBMP(toStringz(file));
    if (surf == null) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't load %s: %s\n", toStringz(file), SDL_GetError());
        return null;
    }
    texture_w = surf.w;
    texture_h = surf.h;

    /* Set transparent pixel as the pixel at (0,0) */
    if (surf.format.palette) {
        SDL_SetColorKey(surf, SDL_TRUE, *cast(Uint8 *) surf.pixels);
    } else {
        switch (surf.format.BitsPerPixel) {
        case 15:
            SDL_SetColorKey(surf, SDL_TRUE, (*cast(Uint16 *) surf.pixels) & 0x00007FFF);
            break;
        case 16:
            SDL_SetColorKey(surf, SDL_TRUE, *cast(Uint16 *) surf.pixels);
            break;
        case 24:
            SDL_SetColorKey(surf, SDL_TRUE, (*cast(Uint32 *) surf.pixels) & 0x00FFFFFF);
            break;
        case 32:
            SDL_SetColorKey(surf, SDL_TRUE, *cast(Uint32 *) surf.pixels);
            break;
        default:
            break;
        }
    }

    /* Create textures from the image */
    texture = SDL_CreateTextureFromSurface(renderer, surf);
    if (!texture) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't create texture: %s\n", SDL_GetError());
        SDL_FreeSurface(surf);
        return null;
    }
    SDL_FreeSurface(surf);

    return texture;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

abstract class actor {
private:
    tick ui_clock = tick(-1);
public:
    void set_ui_tick(tick ui_tick) { ui_clock = ui_tick; }
    tick get_ui_tick() { return ui_clock; }

    void go(world w, out tick used_play_ticks, out bool ui_ticked);
};

class entity_actor : actor {
public:
    entity e;
    this(entity ie) {
        e = ie;
    }
    override void go(world w, out tick used_ticks, out bool ui_ticked) {
        ui_ticked = (e == w.p);
        if (e.is_dead) {
            ui_ticked = false;
            used_ticks = tick(tick.tps*3600); // TODO: hack
        } else {
            w.attempt_action(e, e.brain.think(e, w), used_ticks);
        }
    }
}

void handle_actors(world w) {
    bool ui_ticked = false;
    ++w.ui_clock;
    // here we track and let an actor act at most once per ui_tick
    // progress ui if _either_ player moves/ticks or hit actor with second move
    while (!ui_ticked && w.actor_queue.size() && w.actor_queue.top().get_ui_tick()<w.ui_clock) {
        tick start_play_ticks;
        actor a = w.actor_queue.pop(start_play_ticks);
        tick used_play_ticks;
        a.go(w, used_play_ticks, ui_ticked);
        a.set_ui_tick(w.ui_clock);
        w.actor_queue.push(a, start_play_ticks + used_play_ticks);
        w.play_clock = start_play_ticks;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

void handle_uievents(world w) {
    while (w.ui_queue.size() && w.ui_queue.top_priority()<=w.ui_clock) {
        tick start_ui_ticks;
        uievent a = w.ui_queue.pop(start_ui_ticks);
        tick ui_delay_ticks;
        a.go(w, ui_delay_ticks);
        if (ui_delay_ticks.value > 0)
            w.ui_queue.push(a, start_ui_ticks + ui_delay_ticks);
    }
}

abstract class uievent {
private:
public:
    void go(world w, out tick delay_ui_ticks);
};

class mold_ui : uievent {
private:
    int x, y, l;
    int count;
    static int n = 3;
public:
    this(int ix, int iy, int il) {
        x = ix;
        y = iy;
        l = il;
        count = n*11;
    }
    override void go(world w, out tick delay_ui_ticks) {
        delay_ui_ticks = tick(count ? 1 : 0);
        if (w.p.z.l == l) {
            for (int i=max(0,x-(count/n)/2); i<=min(w.d.nx-1, x+(count/n)/2); ++i) {
                for (int j=max(0,y-(count/n)/2); j<=min(w.d.ny-1, y+(count/n)/2); ++j) {
                    static if (use_sdl) {
                        real r_bg = w.ui_rng.uniform(1.0);
                        w.display[i][j].bg += 
                              ((cast(uint)(((Color.green&0x0000FF)    )*r_bg)&0xFF)    )
                            | ((cast(uint)(((Color.green&0x00FF00)>>8 )*r_bg)&0xFF)<<8 )
                            | ((cast(uint)(((Color.green&0xFF0000)>>16)*r_bg)&0xFF)<<16);
                    } else {
                        w.display[i][j].bg = (w.ui_rng.uniform(1.0) < 0.75) ? Color.black|Bright : Color.yellow;
                        if (w.ui_rng.uniform(1.0)<0.25)
                            w.display[i][j].fg = Color.yellow|Bright;
                    }
                }
            }
        }
        --count;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////

enum action_type {
    nop,
    wait, move, attack_melee, attack_missile, activate,
    wield, unwield, pickup, drop, use,
    abilify
};
Rational!long[action_type] base_action_ticks;
static this() {
    base_action_ticks = [
        action_type.nop             : rational(0L),
        action_type.wait            : rational(2L),
        action_type.move            : rational(1L),
        action_type.attack_melee    : rational(1L),
        action_type.attack_missile  : rational(1L),
        action_type.activate        : rational(1L),
        action_type.wield           : rational(1L,2L),
        action_type.unwield         : rational(1L,3L),
        action_type.pickup          : rational(1L),
        action_type.drop            : rational(1L,4L),
        action_type.use             : rational(1L),
        action_type.abilify         : rational(1L),
    ];
}

struct action {
    action_type type;
    xyl         target;
    union {
        ability abil;
        gameobj item;
    };
};

////////////////////////////////////////////////////////////////////////////////////////////////////

class entity {
public:
    string  name;
    xyl     z;
    int     faction;
    ai      brain;
    ability abilities[];
    bool    is_dead;
    gameobj self;

    this(string iname, rng r, xyl iz, int ifaction, ai ibrain, gameobj iself) {
        name = iname;
        z = iz;
        faction = ifaction;
        brain = ibrain;
        is_dead = false;
        self = iself;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////

abstract class ai {
public:
    action think(entity e, world w);

    xy[] find_path(world w, xy f, xy t, int l) {
        real[xy] bump_map;
        foreach (m; w.monsters)
            if (m.z.l == l)
                bump_map[xy(m.z.x,m.z.y)] = 4.0;
        real step_cost(const xy fz, const xy tz) {
            real bump = bump_map.get(tz, 0.0);
            return fz.dist(tz) + bump - w.play_rng.uniform(0.002)+0.001;
        }
        real estimate(const xy fz, const xy tz) { return fz.dist(tz); }
        bool not_wall(cell_type ct) { return ct != cell_type.wall; }
        xy[] edges(const xy z) { return w.d.levels[l].cells.neighbors(z,&not_wall); }
        real[xy] result;
        xy[] path = astar(f, t, &step_cost, &edges, &edges, &estimate, result);
        return path;
    }
};

class player_ai : ai {
public:
    override action think(entity e, world w) {
        if (w.input_queue.length) {
            xyl oldz = e.z;
            char ch = w.input_queue[0];
            w.input_queue.length = 0;
            action a = action(action_type.wait);
            switch (ch) {
            case 'k': a = action(action_type.move, e.z + xyl.n ); break;
            case 'j': a = action(action_type.move, e.z + xyl.s ); break;
            case 'h': a = action(action_type.move, e.z + xyl.w ); break;
            case 'l': a = action(action_type.move, e.z + xyl.e ); break;
            case 'u': a = action(action_type.move, e.z + xyl.nw); break;
            case 'i': a = action(action_type.move, e.z + xyl.ne); break;
            case 'n': a = action(action_type.move, e.z + xyl.sw); break;
            case 'm': a = action(action_type.move, e.z + xyl.se); break;
            case '>': a = action(action_type.move, e.z + xyl.d ); break;
            case '<': a = action(action_type.move, e.z + xyl.u ); break;
            case 'w': a = action(action_type.wield); break;
            case 'e': a = action(action_type.unwield); break;
            default: break;
            }
            return a;
        } else {
            return action(action_type.nop);
        }
    }
};

class orc_ai : ai {
public:
    override action think(entity e, world w) {
        if (e.z.l != w.p.z.l) {
            return action(action_type.wait);
        } else {
            // TODO: actually choose attack action (with appropriate weapon...)
            xy[] path = find_path(w, xy(e.z.x,e.z.y), xy(w.p.z.x,w.p.z.y), e.z.l);
            return action(action_type.move, xyl(path[1].x, path[1].y, e.z.l));
        }
    }
};

class mold_ai : ai {
public:
    override action think(entity e, world w) {
        if (w.p.z.l != e.z.l) {
            return action(action_type.wait);
        } else if (e.z.dist2(w.p.z) < 25) {
            return action(action_type.abilify, e.z, e.abilities[0]);
        } else {
            return action(action_type.wait);
        }
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////

abstract class ability {
    void activate(entity e, world e);
};

class mold_ability : ability { // TODO: turn into gameobj / property
public:
    tick last_used;
    tick refractory;
    this(tick irefractory) {
        last_used = tick(0);
        refractory = irefractory;
    }
    override void activate(entity e, world w) {
        if ((w.play_clock - last_used) > refractory) {
            global_console.append(format("The %s releases a burst of noxious gas.", e.name), Color.yellow);
            w.ui_queue.push(new mold_ui(e.z.x,e.z.y,e.z.l), w.ui_clock+1);
            last_used = w.play_clock;
        }
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////

struct ui_cell {
    char    ch;
    int     fg;
    int     bg;
    bool    visible;
    bool    seen;
};

class world {
public:
    rng  rule_rng;
    rng  gen_rng;
    rng  play_rng;
    rng  ui_rng;

    bool running_flag;
    PriorityQueue!(actor,tick) actor_queue;
    PriorityQueue!(uievent,tick) ui_queue;

    tick    play_clock = tick(0);
    tick    ui_clock = tick(0);

    static if (use_sdl) {
        int WINDOW_WIDTH;
        int WINDOW_HEIGHT;
        int char_width, char_height;
        SDL_Texture *texture;
        int texture_w, texture_h;
        SDL_Window *window;
        SDL_Renderer *renderer;
    } else {
        Terminal terminal;
    }
    char[] input_queue;

    dungeon d;
    ui_cell display[][];

    // TODO: merge player & monsters
    // add "factions" to avoid monster-monster attacks
    entity p;
    entity[] monsters;
    gameobj player_go;
    gameobj[] monsters_go;

    this(uint seed, int d_nx, int d_ny, Display the_display) {
        running_flag = true;
        actor_queue = new PriorityQueue!(actor,tick)();
        ui_queue = new PriorityQueue!(uievent,tick)();

        rule_rng = new rng(seed);
        gen_rng = new rng(seed);
        play_rng = new rng(seed);
        ui_rng = new rng(seed);

        static if (use_sdl) {
            WINDOW_WIDTH = the_display.WINDOW_WIDTH;
            WINDOW_HEIGHT = the_display.WINDOW_HEIGHT;
            char_width = the_display.char_width;
            char_height = the_display.char_height;
            texture = the_display.texture;
            texture_w = the_display.texture_w;
            texture_h = the_display.texture_h;
            window = the_display.window;
            renderer = the_display.renderer;
        } else {
            terminal = the_display.terminal;
        }

        int nl = 10;
        int nr = 4;
        int nx = d_nx;
        int ny = d_nx;
        d = new dungeon(gen_rng, nl, nr, nx, ny);

        gameobj r_finger = new gameobj()
            .add(new display_property('/', "right finger"), 0)
            .add(new body_part_property("finger", 0, null, null), 1);
        gameobj r_hand = new gameobj()
            .add(new display_property('/', "right hand"), 0)
            .add(new body_part_property("hand", 2, null, [r_finger], null, weapons["fist"]), 1);
        gameobj r_arm = new gameobj()
            .add(new display_property('/', "right arm"), 0)
            .add(new body_part_property("arm", 0, null, [r_hand]), 1);
        gameobj l_finger = new gameobj()
            .add(new display_property('/', "left finger"), 0)
            .add(new body_part_property("finger", 0, null, null), 1);
        gameobj l_hand = new gameobj()
            .add(new display_property('/', "left hand"), 0)
            .add(new body_part_property("hand", 2, null, [l_finger], null, weapons["fist"]), 1);
        gameobj l_arm = new gameobj()
            .add(new display_property('/', "left arm"), 0)
            .add(new body_part_property("arm", 0, null, [l_hand]), 1);
        gameobj r_foot = new gameobj()
            .add(new display_property('/', "right foot"), 0)
            .add(new body_part_property("foot", 0, null, null), 1);
        gameobj r_leg = new gameobj()
            .add(new display_property('/', "right leg"), 0)
            .add(new body_part_property("leg", 0, null, [r_foot]), 1);
        gameobj l_foot = new gameobj()
            .add(new display_property('/', "left foot"), 0)
            .add(new body_part_property("hand", 0, null, null), 1);
        gameobj l_leg = new gameobj()
            .add(new display_property('/', "left leg"), 0)
            .add(new body_part_property("leg", 0, null, [l_foot]), 1);
        gameobj torso = new gameobj()
            .add(new display_property('/', "torso"), 0)
            .add(new body_part_property("torso", 0, null, [r_arm, l_arm, r_leg, l_leg, /*head*/], skin.clone()), 1);
        player_go = new gameobj()
            .add(new xp_property(), 1)
            .add(new inventory_property(10), 2)
            .add(new body_property(8, 8, 2, tick(tick.tps()), [torso.clone()]), 10);
        p = new entity("you", play_rng, xyl(1,1,0), 0, new player_ai(), player_go);
        monsters = [p];
        actor_queue.push(new entity_actor(p), tick(1));
        {
            message m;
            m = new message("Wielding");
            m["Entity"] = p.self;
            m["Wielded"] = weapons["glaive"].clone();
            p.self.handle_message(m);

            m = new message("Donning");
            m["Entity"] = p.self;
            m["Donned"] = ring_of_speed.clone();
            p.self.handle_message(m);

            m = new message("Donning");
            m["Entity"] = p.self;
            m["Donned"] = ring_of_damage.clone();
            p.self.handle_message(m);
        }

        for (int i=0; i<nl; ++i) {
            for (int j=0; j<2*(i+1); ++j) {
                int x, y;
                d.find_floor(gen_rng, i, x, y);
                entity m;
                gameobj m_go;
                if (gen_rng.uniform(1.0) < 0.50) {
                    // TODO: random hp/hd
                    m_go = new gameobj()
                        .add(new display_property('o', "orc"), 1)
                        .add(new xp_property(), 1)
                        .add(new body_property(6, 6, 2, tick(gen_rng.uniform(60*60)+25*tick.tps()/10), [r_arm.clone()]), 10);
                    m = new entity("orc", gen_rng, xyl(x,y,i), 1, new orc_ai(), m_go);
                    actor_queue.push(new entity_actor(m), tick(251+gen_rng.uniform(60*60)));
                } else  {
                    m_go = new gameobj()
                        .add(new display_property('m', "mold"), 1)
                        .add(new xp_property(), 1)
                        .add(new body_property(3, 3, 1, tick(gen_rng.uniform(60*60)+3*tick.tps()), []), 10); // TODO: random hp/hd
                    m = new entity("mold", gen_rng, xyl(x,y,i), 2, new mold_ai(), m_go);
                    m.abilities ~= new mold_ability(tick(3*tick.tps()));
                    actor_queue.push(new entity_actor(m), tick(500+gen_rng.uniform(60*60)));
                }
                monsters ~= m;
                monsters_go ~= m_go;
            }
        }

        display = new ui_cell[][](nx,ny);
    }

    void update_display() {
        for (int i=0; i<d.nx; ++i) {
            for (int j=0; j<d.ny; ++j) {
                char ch;
                int color_fg = Color.white, color_bg = Color.black;
                switch (d[i,j,p.z.l]) {
                    case cell_type.floor:       ch = '.'; color_fg = Color.white    ; break;
                    case cell_type.wall:        ch = '#'; color_bg = Color.yellow   ; break;
                    case cell_type.door_open:   ch = '_'; color_fg = Color.white    ; break;
                    case cell_type.door_closed: ch = '+'; color_fg = Color.white    ; break;
                    case cell_type.stairs_up:   ch = '<'; color_fg = Color.white    ; break;
                    case cell_type.stairs_down: ch = '>'; color_fg = Color.white    ; break;
                    default:                    ch = '?'; color_fg = Color.red      ; break;
                }
                display[i][j] = ui_cell(ch, color_fg, color_bg, display[i][j].visible, display[i][j].seen);
                static if (use_sdl) {
                    if (display[i][j].visible) {
                        display[i][j].fg |= 0x0F0F07;
                        display[i][j].bg |= 0x0F0F07;
                    } else if (display[i][j].seen) {
                        display[i][j].fg &= 0x1F1F1F;
                        display[i][j].bg &= 0x1F1F1F;
                    } else {
                        display[i][j].ch = ' ';
                        display[i][j].fg = Color.black;
                        display[i][j].bg = Color.black;
                    }
                }
            }
        }
        foreach (m; monsters)
            if (m.z.l == p.z.l)
                display[m.z.x][m.z.y] = ui_cell(cast(char)m.self.get("Symbol").i, Color.red|Bright, Color.black);
        static if (use_sdl)
            display[p.z.x][p.z.y] = ui_cell('\x01', Color.white|Bright, Color.black);
        else
            display[p.z.x][p.z.y] = ui_cell('@', Color.white|Bright, Color.black);
    }

    bool attempt_action(entity e, action a, out tick used_ticks) {
        field f = {i:a.type};
        message mess = new message("GetSpeed", ["ActionType":f]);
        e.self.handle_message(mess);
        used_ticks = tick((base_action_ticks[a.type] * mess["Speed"].t.value).trunc);
        switch (a.type) {
        case action_type.wait:
            return true;
        case action_type.move:
            // change move to attack if target is occupied square
            foreach (m; monsters) {
                if (m.z == a.target) {
                    if (m.faction == e.faction) {
                        goto case action_type.wait;
                    } else {
                        foreach (p; e.self._properties) {
                            if (body_property b = cast(body_property)p) {
                                foreach (bp; b._body_parts) {
                                    gameobj g = bp.handle_message(new message("GetWielded"))["Wielded"].g;
                                    if (g !is null) {
                                        a.item = g;
                                        goto found_wielded;
                                    }
                                }
                            }
                        }
                        found_wielded:
                        goto case action_type.attack_melee;
                    }
                }
            }
            if (d[a.target] != cell_type.wall
                && !(e.z.l<a.target.l && d[a.target]!=cell_type.stairs_up)
                && !(e.z.l>a.target.l && d[a.target]!=cell_type.stairs_down))
            {
                if (abs(e.z.x-a.target.x)+abs(e.z.y-a.target.y)==2) // cost for diagonal move
                    used_ticks += (used_ticks*408)/985; // approx(sqrt(2)-1)
                e.z = a.target;
                return true;
            } else {
                goto case action_type.wait;
            }
            break;
        case action_type.attack_melee:
            foreach (m; monsters) {
                if (m.z == a.target) {
                    gameobj wielded = a.item;
                    if (wielded is null) {
                        global_console.append(format("WARNING: null wielded in %s", a), Color.red, Color.yellow);
                        break;
                    }
                    int dam = wielded.handle_message(new message("ComputeMeleeDamage"))["MeleeDamage"].i;
                    message mess2 = new message("TakeDamage");
                    mess2["Damage"] = dam;
                    m.self.handle_message(mess2);
                    // TODO: send ComputeMeleeDamage message to entity_go - it passes it to wielded... etc.
                    // TODO: meleeattack via messages
                    // TODO: handle sufferDeath message appropriately
                    if (e == p) {
                        global_console.append(format("You hit the %s for %d damage.", m.name, dam));
                    } else {
                        global_console.append(format("The %s hits you for %d damage.", e.name, dam), Color.red);
                    }
                    if (m.self.get("HP").i <= 0) {
                        // TODO: handle this via messages appropriately...
                        if (m == p) {
                            global_console.append("You die!", Color.red|Bright, Color.yellow);
                            running_flag = false;
                        } else {
                            global_console.append(format("The %s dies.", m.name), Color.green);
                            {
                                message xpmess = new message("AddXP");
                                xpmess["XP"] = m.self.get("HPMax").i;
                                player_go.handle_message(xpmess);
                            }
                            {
                                message xpmess = new message("AddXP");
                                xpmess["XP"] = 1+m.self.get("HPMax").i/10;
                                wielded.handle_message(xpmess);
                            }
                            m.is_dead = true;
                            m.z = xyl(-1,-1,-1); // TODO: ugly hack
                        }
                    }
                    return true;
                }
            }
            return false;
        case action_type.attack_missile:
            break;
        case action_type.abilify:
            a.abil.activate(e,this);
            return true;
        case action_type.activate:
            break;
        case action_type.wield:
            break;
        case action_type.unwield:
            break;
        case action_type.pickup:
            break;
        case action_type.drop:
            break;
        case action_type.use:
            break;
        default:
            return false;
        }
        return false;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////

gameobj skin;
gameobj[string] weapons;
gameobj ring_of_damage, ring_of_speed;

static this() {
    weapons["glaive"] = new gameobj()
        .add(new display_property('/', "glaive"), 0)
        .add(new wieldable_property(3, 11, 9), 1)
        .add(new weapon_property(roller("2d6")), 1)
        .add(new ench_property(0), 2)
        .add(new xp_property(), 3);

    weapons["fist"] = new gameobj()
        .add(new display_property('/', "fist"), 0)
        .add(new wieldable_property(1, 5, 5), 1)
        .add(new weapon_property(roller("1d3-1")), 1)
        .add(new ench_property(0), 2)
        .add(new xp_property(), 3);

    weapons["dagger"] = new gameobj()
        .add(new display_property('/', "dagger"), 0)
        .add(new wieldable_property(1, 5, 5), 1)
        .add(new weapon_property(roller("1d4")), 1)
        .add(new ench_property(0), 2)
        .add(new xp_property(), 3);

    skin = new gameobj()
        .add(new display_property('[', "skin"), 0)
        .add(new wearable_property("torso"), 1)
        .add(new armor_property(0), 1)
        .add(new ench_property(0), 2);

    ring_of_damage = new gameobj()
        .add(new display_property('"', "ring"), 0)
        .add(new wearable_property("finger", new damage_effect_property(35)), 1);

    ring_of_speed = new gameobj()
        .add(new display_property('"', "ring"), 0)
        .add(new wearable_property("finger", new speedup_effect_property(50)), 1);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

version(Windows) {
    extern (C) void _STD_conio(); // properly closes handles
    extern (C) void _STI_conio(); // initializes DM access to conin, conout
}
version(Posix) {
    extern (C) void* setup_ui_state();
    extern (C) void restore_ui_state(void*);
}

world global_world = void;
ConsoleWindow global_console = void;

class Display {
    static if (use_sdl) {
        immutable int WINDOW_WIDTH  = 1000;
        immutable int WINDOW_HEIGHT = 600;
        string spritefile = "curses_800x600.bmp";
        //string spritefile = "curses_square_16x16.bmp";
        int char_width, char_height;
        SDL_Texture* texture;
        int texture_w, texture_h;
        SDL_Window* window;
        SDL_Renderer* renderer;
        this() {
            if (SDL_CreateWindowAndRenderer(WINDOW_WIDTH, WINDOW_HEIGHT, 0, &window, &renderer) < 0)
                throw new Throwable("Unable to create SDL window");

            if ((texture = LoadSprite(spritefile, renderer, texture_w, texture_h)) is null)
                throw new Throwable("Unable to load texture");

            uint format;
            int access;
            SDL_QueryTexture(texture, &format, &access, &char_width, &char_height);
            char_width /= 16;
            char_height /= 16;
        }
    } else {
        Terminal terminal;
        this () {
            terminal = new Terminal(ConsoleOutputType.cellular);
        }
    }
}

int main(string[] argv)
{
    static if (use_sdl) {
        // Load the SDL 2 libraries
        DerelictSDL2.load();
        //DerelictSDL2Image.load();
        //DerelictSDL2Mixer.load();
        //DerelictSDL2ttf.load();
        //DerelictSDL2Net.load();
        scope(exit) SDL_Quit();

	    /* Enable standard application logging */
        SDL_LogSetPriority(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_INFO);
    } else {
        version(Windows) {
            _STI_conio();
            scope(exit) _STD_conio();
        }
        version(Posix) {
            void* old_ui_state = setup_ui_state();
            scope(exit) restore_ui_state(old_ui_state);
        }
    }

    int d_nx = 29, d_ny = 29;
    Display display = new Display();
    static if (use_sdl) {
        int[] size = [display.WINDOW_WIDTH/display.char_width, display.WINDOW_HEIGHT/display.char_height];
    } else {
        display.terminal.hideCursor();
        display.terminal.setTitle("Rogue-gamesh");
        int[] size = display.terminal.getSize();
    }
    WindowManager wm = new WindowManager(size[0], size[1]-1);
    Window w_map = new Window(0, size[1]-d_ny-2, 0, d_nx, d_ny);
    wm.add(w_map);
    Window w_header = new Window(0, size[1]-2, 0, size[0]-1, 1);
    wm.add(w_header);
    Window w_player = new Window(0, size[1]-d_ny-2-2, 0, size[0]-1, 2);
    wm.add(w_player);
    global_console = new ConsoleWindow(0, 0, 0, size[0]-1, 5);
    wm.add(global_console);
    Window w_body_parts = new Window(size[0]-41, size[1]-22, 0, 40, 20);
    for (int i=0; i<w_body_parts.nx; ++i)
        for (int j=0; j<w_body_parts.ny; ++j)
            w_body_parts.set(i, j, ' ', Color.black, Color.blue);
    wm.add(w_body_parts);

    world w = global_world = new world(13, d_nx, d_ny, display);

    int target_fps = 60;
    tick target_ticks = tick(tick.tps() / target_fps);
    tick last_tick = tick(0);
    tick average_tick_length = tick(0);
    int num_ave = 0;
    while (w.running_flag) {
        tick tick_start = getTicks();
        if (last_tick.value) {
            tick sleepy_time = target_ticks - (tick_start - last_tick);
            if (num_ave)
                sleep(sleepy_time - (average_tick_length/num_ave - target_ticks));
            else
                sleep(sleepy_time);
            tick act_tick_end = getTicks();

            ++num_ave;
            average_tick_length += act_tick_end-last_tick;
            w_header.set(0, 0, format("%s %s %s", average_tick_length/num_ave, w.ui_clock, w.play_clock), Color.blue|Bright, Color.black);
        }
        last_tick = tick_start;

        handle_actors(w);
        w.update_display();
        handle_uievents(w);

        {
            foreach (ref qr; w.display)
                foreach (ref q; qr)
                    q.visible = false;

            w.display[w.p.z.x][w.p.z.y].seen = true;
            w.display[w.p.z.x][w.p.z.y].visible = true;

            int radius = 20;

            for (int x=max(0,w.p.z.x-radius); x<=min(w.d.nx-1,w.p.z.x+radius); ++x) {
                xy[] p = bresenham(xy(w.p.z.x,w.p.z.y), xy(x, max(0,w.p.z.y-radius)));
                foreach (z; p[1..$]) {
                    //w.display[z.x][z.y].bg = Color.green;
                    w.display[z.x][z.y].visible = w.display[z.x][z.y].seen = true;
                    if (w.d[z.x,z.y,w.p.z.l] != cell_type.floor) break;
                }
            }
            for (int x=max(0,w.p.z.x-radius); x<=min(w.d.nx-1,w.p.z.x+radius); ++x) {
                xy[] p = bresenham(xy(w.p.z.x,w.p.z.y), xy(x, min(w.d.ny-1,w.p.z.y+radius)));
                foreach (z; p[1..$]) {
                    //w.display[z.x][z.y].bg = Color.red;
                    w.display[z.x][z.y].visible = w.display[z.x][z.y].seen = true;
                    if (w.d[z.x,z.y,w.p.z.l] != cell_type.floor) break;
                }
            }
            for (int y=max(0,w.p.z.y-radius); y<=min(w.d.ny-1,w.p.z.y+radius); ++y) {
                xy[] p = bresenham(xy(w.p.z.x,w.p.z.y), xy(max(0,w.p.z.x-radius),y));
                foreach (z; p[1..$]) {
                    //w.display[z.x][z.y].bg = Color.cyan;
                    w.display[z.x][z.y].visible = w.display[z.x][z.y].seen = true;
                    if (w.d[z.x,z.y,w.p.z.l] != cell_type.floor) break;
                }
            }
            for (int y=max(0,w.p.z.y-radius); y<=min(w.d.ny-1,w.p.z.y+radius); ++y) {
                xy[] p = bresenham(xy(w.p.z.x,w.p.z.y), xy(min(w.d.nx-1,w.p.z.x+radius),y));
                foreach (z; p[1..$]) {
                    //w.display[z.x][z.y].bg = Color.magenta;
                    w.display[z.x][z.y].visible = w.display[z.x][z.y].seen = true;
                    if (w.d[z.x,z.y,w.p.z.l] != cell_type.floor) break;
                }
            }

            static if (!use_sdl)
            foreach (ref qr; w.display) {
                foreach (ref q; qr) {
                    if (!q.seen) {
                        q.ch = ' ';
                        q.fg = Color.black;
                        q.bg = Color.black;
                    } else if (!q.visible) {
                        q.fg = Color.black|Bright;
                        q.bg = Color.black;
                    }
                }
            }
        }
        //////// ////////
        for (int i=0; i<w.d.nx; ++i)
            for (int j=0; j<w.d.ny; ++j)
                w_map.set(i, j, cast(char)w.display[i][j].ch, w.display[i][j].fg, w.display[i][j].bg);
        w_player.set(0, 0,
                     format("HP:%s/%s %s [x%s y%s l%s]",
                            w.p.self.get("HP").i, w.p.self.get("HPMax").i, w.player_go.get("DisplayName").s, w.p.z.x, w.p.z.y, w.p.z.l),
                     Color.white, Color.black);
        //w_player.set(0, 1, format("Wielded: %s", w.p.wielded.get("DisplayName").s), Color.white, Color.black);

        {
            field[] bps = w.p.self.get("BodyParts").fa;
            for (int i=0; i<bps.length; ++i) {
                string bp_name = bps[i].g.get("ShortDisplayName").s;
                gameobj bp_wielded = bps[i].g.get("Wielded").g;
                gameobj bp_worn = bps[i].g.get("Worn").g;
                w_body_parts.set(0, i,
                    format("%s : %s%s",
                        bp_name,
                        ((bp_wielded is null) ? "" : bp_wielded.get("DisplayName").s),
                        ((bp_worn is null) ? "" : bp_worn.get("DisplayName").s)
                        ),
                    Color.white, Color.blue);
            }
        }

        static if (use_sdl) {
            wm.refresh(w.window, w.renderer, w.texture);
        } else {
            wm.refresh(w.terminal);
            w.terminal.flush();
        }
        //////// ////////

        static if (use_sdl) {
            SDL_Event event;
            /* Check for events */
            while (SDL_PollEvent(&event)) {
                switch (event.type) {
                case SDL_QUIT:
                    w.running_flag = 0;
                    break;
                case SDL_KEYDOWN:
                    //writefln("%s %s='%s'", event.key, event.key.keysym.sym, cast(char)event.key.keysym.sym);
                    switch (event.key.keysym.sym) {
                        case 'q': w.running_flag = 0; break;
                        default:
                            // HACK
                            if (event.key.keysym.sym >= 32) {
                                char ch = cast(char)event.key.keysym.sym;
                                if (ch=='.' && ((event.key.keysym.mod&KMOD_LSHIFT)||(event.key.keysym.mod&KMOD_RSHIFT)))
                                    ch = '>';
                                if (ch==',' && ((event.key.keysym.mod&KMOD_LSHIFT)||(event.key.keysym.mod&KMOD_RSHIFT)))
                                    ch = '<';
                                w.input_queue ~= ch;
                            }
                            break;
                    }
                    break;
                default:
                    break;
                }
            }
        } else {
            if (keyReady()) { 
                char ch;
                switch(ch=cast(char)getKey()) {
                case 'q': w.running_flag = 0; break;
                case 'c': w.terminal.reset(); w.terminal.clear(); break;
                default: w.input_queue ~= ch; break;
                }
            }
        }
    }

    Window w_dead = new Window(5, size[1]-6, 1000, size[1]-1, 2);
    w_dead.set(0,0,"YOU DEAD!!!!!", Color.red|Bright, Color.white);
    w_dead.set(0,1,cast(string)w.input_queue, Color.white, Color.red);
    wm.add(w_dead);
    static if (use_sdl) {
        wm.refresh(w.window, w.renderer, w.texture);
    } else {
        wm.refresh(w.terminal);
    }

    static if (use_sdl) {
        SDL_Event event;
        while (SDL_WaitEvent(&event))
            if (event.type == SDL_QUIT || event.type == SDL_KEYDOWN)
                break;
    } else {
        while (getKey()!=' ') {}
    }
    return 0;
}


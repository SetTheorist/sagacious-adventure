module item;

import std.algorithm;
import std.conv;
import std.stdio;
import std.string;

import main : action_type, global_console, global_world;
import map : xy, xyl;
import rng;
import ui : Color, Bright;
import util;

////////////////////////////////////////////////////////////////////////////////

// ECS system (v3)

union field {
    string  s;
    int     i;
    real    r;
    gameobj g;
    field[] fa;
    tick    t;
    xy      z;
    xyl     zl;
}
class gameobj {
    private static ulong _next = 1L;
    private ulong _id;
    this() { _id = _next++; }

    gameobj clone() {
        gameobj g = new gameobj();
        foreach (p; _properties)
            g._properties ~= p.clone();
        return g;
    }

    @property ulong id() const { return _id; }

    property[] _properties;

    gameobj add(property p, int priority) {
        p._priority = priority;
        _properties ~= p;
        sort!((a,b) => (a._priority<b._priority))(_properties);
        return this;
    }
    gameobj remove(property p) {
        for (int i=0; i<_properties.length; ++i) {
            if (p == _properties[i]) {
                _properties[i..$-1] = _properties[i+1..$];
                --_properties.length;
                break;
            }
        }
        return this;
    }

    field get(string field_name) {
        message mess = new message("Get"~field_name);
        handle_message(mess);
        return mess[field_name];
    }

    MT handle_message(MT : message)(MT m) {
        gameobj old_sender = m._sender;
        m._sender = this;
        foreach (p; _properties)
            if ((m = p.handle_message(m)) is null)
                break;
        m._sender = old_sender;
        return cast(MT)m;
    }

    override string toString() const {
        return format("go#%s", _id);
    }
}
class message {
    private string _id;
    gameobj _sender;
    private field[string] _fields;
    this(string id) { _id = id; }
    this(string id, field[string] fields) {
        _id = id;
        _fields = fields.dup();
    }

    @property string id() const { return _id; }

    override string toString() const {
        return format("{%s-%s: %s}", _id, _sender, _fields);
    }

    ref field opIndex(string f) {
        if (f !in _fields) _fields[f] = field();
        return _fields[f];
    }
    ref field opIndexAssign(string sv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].s = sv;
        return _fields[f];
    }
    ref field opIndexAssign(int iv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].i = iv;
        return _fields[f];
    }
    ref field opIndexAssign(real rv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].r = rv;
        return _fields[f];
    }
    ref field opIndexAssign(gameobj gv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].g = gv;
        return _fields[f];
    }
    ref field opIndexAssign(tick tv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].t = tv;
        return _fields[f];
    }
    ref field opIndexAssign(xy zv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].z = zv;
        return _fields[f];
    }
    ref field opIndexAssign(xyl zlv, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].zl = zlv;
        return _fields[f];
    }
    ref field opIndexAssign(field[] fav, string f) {
        if (f !in _fields) _fields[f] = field();
        _fields[f].fa = fav;
        return _fields[f];
    }
}
class property {
    private string _id;
    int _priority;
    this(string id) { _id = id; _priority = 0; }
    message handle_message(message m) { return m; }
    property clone() { return new property(_id); }
}
class display_property : property {
    char _symbol;
    string _name;
    this(char symbol, string name) {
        super("display");
        _symbol = symbol;
        _name = name;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetSymbol":
            m["Symbol"] = _symbol;
            break;
        case "GetShortDisplayName":
            m["ShortDisplayName"] = _name;
            break;
        case "GetDisplayName":
            m["DisplayName"] = _name;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new display_property(_symbol, _name); }
}
class physics_property : property {
    real _weight;
    real _volume;
    int  _x;
    int  _y;
    int  _l;
    this(real weight, real volume, int x, int y, int l) {
        super("physics");
        _weight = weight;
        _volume = volume;
        _x = x;
        _y = y;
        _l = l;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetWeight":
            m["Weight"] = _weight;
            break;
        case "GetVolume":
            m["Volume"] = _volume;
            break;
        case "GetXY":
            m["XY"] = xy(_x,_y);
            break;
        case "GetXYL":
            m["XYL"] = xyl(_x,_y,_l);
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new physics_property(_weight, _volume, _x, _y, _l); }
}
class wieldable_property : property {
    int _size;
    int _min_str;
    int _min_dex;
    this(int size, int min_str, int min_dex) {
        super("wieldable");
        _size = size;
        _min_str = min_str;
        _min_dex = min_dex;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetSize":
            m["Size"].i = _size;
            break;
        //case "Wielding":
        //    break;
        //case "Unwielding":
        //    break;
        default: break;
        }
        return m;
    }
    override property clone() { return new wieldable_property(_size, _min_str, _min_dex); }
}
class cursed_property : property {
    bool _known;
    this(bool known) {
        super("cursed");
        _known = known;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            if (_known)
                m["DisplayName"] = m["DisplayName"].s ~ " {cursed}";
            break;
        case "Donning":
        case "Wielding":
            global_console.append(format("The %s appears to be cursed.", m._sender.get("ShortDisplayName").s), Color.yellow);
            _known = true;
            break;
        case "Doffing":
        case "Unwielding":
            global_console.append(format("You cannot remove the cursed %s.", m._sender.get("ShortDisplayName").s), Color.yellow);
            _known = true;
            message m2 = new message("Cancelled"~m.id);
            m2._sender = m._sender;
            m = m2;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new cursed_property(_known); }
}
class body_property : property {
    int       _hp;
    int       _hp_max;
    int       _size;
    gameobj[] _root_body_parts; // "roots" to body-part "tree/forest": typically just torso
    gameobj[] _body_parts; // all elements of the body-part "tree"
    tick      _speed;
    this(int hp, int hp_max, int size, tick speed, gameobj[] body_parts) {
        super("body");
        _hp = hp;
        _hp_max = hp_max;
        _size = size;
        _speed = speed;
        _root_body_parts = body_parts.dup();
        _body_parts = body_parts.dup();
        message mess = new message("GetAllChildren");
        foreach (rbp; _root_body_parts)
            rbp.handle_message(mess);
        foreach (ch; mess["Children"].fa)
            _body_parts ~= ch.g;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            //m["DisplayName"] = "";
            //foreach (bp; _body_parts)
            //    m = bp.handle_message(m);
            break;
        case "GetSize":
            m["Size"] = _size;
            break;
        case "GetHP":
            m["HP"] = _hp;
            break;
        case "GetHPMax":
            m["HPMax"] = _hp_max;
            break;
        case "GetBodyParts":
            foreach (bp; _body_parts) {
                field f = {g : bp};
                m["BodyParts"].fa ~= f;
            }
            break;
        case "GetSpeed":
            m["Speed"] = _speed;
            break;
        case "TakeDamage":
            _hp -= m["Damage"].i;
            if (_hp <= 0) {
                message mess = new message("SufferDeath");
                m._sender.handle_message(mess);
            }
            break;
        case "SufferDeath":
            break;
        case "GainLevel":
            int n = roller("d8").roll(global_world.play_rng);
            _hp += n;
            _hp_max += n;
            break;
        case "Donning":
            string location = m["Donned"].g.get("Location").s;
            foreach (bp; _body_parts) {
                if (bp.get("Type").s != location) continue;
                if (bp.get("WornActual").g !is null) continue;
                if ((m = bp.handle_message(m))["DonnedAt"].g !is null)
                    break;
            }
            break;
        case "Doffing":
            foreach (bp; _body_parts)
                if ((m = bp.handle_message(m))["DoffedAt"].g !is null)
                    break;
            break;
        case "Wielding":
            string type = "hand";
            gameobj to_wield = m["Wielded"].g;
            int required = to_wield.get("Size").i;
            gameobj[] potential_parts;
            int[] potential_parts_sizes;
            int available = 0;
            foreach (bp; _body_parts) {
                if (bp.get("Type").s == type) {
                    potential_parts ~= bp;
                    int size = bp.get("Size").i;
                    potential_parts_sizes ~= size;
                    if (bp.get("WieldedActual").g is null)
                        available += size;
                }
            }
            if (available < required) {
                global_console.append(format("You are unable to wield the %s.", to_wield.get("ShortDisplayName").s));
                break;
            }
            int able = 0;
            for (int i=0; i<potential_parts.length && able<required; ++i) {
                gameobj bp = potential_parts[i];
                if (bp.get("WieldedActual").g !is null) continue;
                message mess = new message("Wielding");
                mess["Wielded"] = to_wield;
                if ((mess = bp.handle_message(mess))["WieldedAt"].g is null) continue; // TODO: handle this error case appropriately
                able += potential_parts_sizes[i];
                //global_console.append(format("You wield the %s in your %s.", to_wield.get("ShortDisplayName").s, bp.get("ShortDisplayName").s));
            }
            if (able < required) { // TODO handle this
            }
            break;
        case "Unwielding":
            foreach (bp; _body_parts)
                if ((m = bp.handle_message(m))["UnwieldedAt"].g !is null)
                    break;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { 
        gameobj[] body_parts = _body_parts[];
        foreach (ref bp; body_parts)
            bp = bp.clone();
        return new body_property(_hp, _hp_max, _size, _speed, body_parts);
    }
}
class body_part_property : property {
    string  _type;
    int     _size;
    gameobj _parent;
    gameobj[] _children;
    gameobj _worn;
    gameobj _wielded;
    gameobj _intrinsic_wielded;
    gameobj _intrinsic_worn;
    this(string type, int size, gameobj parent, gameobj[] children,
        gameobj intrinsic_worn = null, gameobj intrinsic_wielded = null, gameobj worn = null, gameobj wielded = null)
    {
        super("body_part");
        _type = type;
        _size = size;
        _parent = parent;
        _children = children.dup();
        _intrinsic_worn = intrinsic_worn;
        _intrinsic_wielded = intrinsic_wielded;
        _worn = worn;
        _wielded = wielded;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            string worn = null, wielded = null;
            if (_worn !is null)
                worn = format(" wearing %s", _worn.get("DisplayName").s);
            else if (_intrinsic_worn !is null)
                worn = format(" (wearing %s)", _intrinsic_worn.get("DisplayName").s);
            if (_wielded !is null)
                wielded = format(" wielding %s", _wielded.get("DisplayName").s);
            else if (_intrinsic_wielded !is null)
                wielded = format(" (wielding %s)", _intrinsic_wielded.get("DisplayName").s);
            m["DisplayName"] = format("%s (%s)%s%s", m["DisplayName"].s, _type,
                                      ((worn is null) ? "" : worn),
                                      ((wielded is null) ? "" : wielded));
            break;
        case "SetParent":
            _parent = m["Parent"].g;
            break;
        case "GetParent":
            m["Parent"] = _parent;
            break;
        case "GetChildren":
            foreach (ch; _children) {
                field f = {g : ch};
                m["Children"].fa ~= f;
            }
            break;
        case "GetAllChildren":
            foreach (ch; _children) {
                field f = {g : ch};
                m["Children"].fa ~= f;
                ch.handle_message(m);
            }
            break;
        case "GetType":
            m["Type"] = _type;
            break;
        case "GetSize":
            m["Size"] = _size;
            break;
        case "GetWorn":
            m["Worn"] = _worn ? _worn : _intrinsic_worn ? _intrinsic_worn : null;
            break;
        case "GetWornActual":
            m["WornActual"] = _worn;
            break;
        case "GetWielded":
            m["Wielded"] = _wielded ? _wielded : _intrinsic_wielded ? _intrinsic_wielded : null;
            break;
        case "GetWieldedActual":
            m["WieldedActual"] = _wielded;
            break;
        case "Donning":
            // TODO: check if actually wearable...
            //if (_worn !is null) break;
            global_console.append(
                format("You don the %s on your %s.", m["Donned"].g.get("DisplayName").s, m._sender.get("ShortDisplayName").s),
                Color.white);
            m = m["Donned"].g.handle_message(m);
            m["Doffed"] = _worn;
            _worn = m["Donned"].g;
            m["DonnedAt"] = m._sender;
            break;
        case "Doffing":
            if (_worn != m["Doffed"].g) break;
            global_console.append(
                format("You doff the %s from your %s.", m["Doffed"].g.get("DisplayName").s, m._sender.get("ShortDisplayName").s),
                Color.white);
            m = m["Doffed"].g.handle_message(m);
            _worn = null;
            m["DoffedAt"] = m._sender;
            break;
        case "Wielding":
            global_console.append(
                format("You wield the %s with your %s.", m["Wielded"].g.get("ShortDisplayName").s, m._sender.get("ShortDisplayName").s),
                Color.white);
            m = m["Wielded"].g.handle_message(m);
            // TODO: check if actually wieldable...
            m["Unwielded"] = _wielded;
            _wielded = m["Wielded"].g;
            m["WieldedAt"] = m._sender;
            break;
        case "Unwielding":
            if (_wielded != m["Unwielded"].g) break;
            global_console.append(
                format("You unwield the %s from your %s.", m["Unwielded"].g.get("DisplayName").s, m._sender.get("ShortDisplayName").s),
                Color.white);
            m = m["Unwielded"].g.handle_message(m);
            _wielded = null;
            m["UnwieldedAt"] = m._sender;
            break;
        default: break;
        }
        return m;
    }
    override property clone() {
        gameobj[] children;
        foreach (ch; _children)
            children ~= ch.clone();
        auto ret = new body_part_property(_type, _size, _parent, children,
            _intrinsic_worn?_intrinsic_worn.clone():null, _intrinsic_wielded?_intrinsic_wielded.clone():null,
            _worn?_worn.clone():null, _wielded?_wielded.clone():null);
        // TODO: fixup parents!
        return ret;
    }
}
class wearable_property : property {
    string _location;
    property _effect;
    this(string location, property effect = null) {
        super("wearable");
        _location = location;
        _effect = effect;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            if (_effect) {
                m["DisplayName"] = format("%s of ", m["DisplayName"].s);
                m = _effect.handle_message(m);
            }
            break;
        case "GetLocation":
            m["Location"] = _location;
            break;
        case "Donning":
            if (_effect) {
                _effect.handle_message(m);
                m["Entity"].g.add(_effect,10);
            }
            break;
        case "Doffing":
            if (_effect) {
                _effect.handle_message(m);
                m["Entity"].g.remove(_effect);
            }
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new wearable_property(_location, _effect ? _effect.clone() : null); }
}
class damage_effect_property : property {
    int _bonus;
    this(int bonus) {
        super("damage_effect");
        _bonus = bonus;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            m["DisplayName"] = m["DisplayName"].s ~ format("damage (%+d)", _bonus);
            break;
        case "ComputeMeleeDamage":
            m["MeleeDamage"] = m["MeleeDamage"].i + _bonus;
            break;
        case "ComputeMissileDamage":
            m["MissileDamage"] = m["MissileDamage"].i + _bonus;
            break;
        case "Donning":
            global_console.append("You feel you will do more damage.");
            break;
        case "Doffing":
            global_console.append("You feel you will do less damage.");
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new damage_effect_property(_bonus); }
}
class speedup_effect_property : property {
    int _bonus;
    action_type _type;
    this(int bonus, action_type type = action_type.nop) {
        super("speedup_effect");
        _bonus = min(99,bonus);
        _type = type;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            m["DisplayName"] = m["DisplayName"].s ~ format("speed (%s%+d%%)", (_type==action_type.nop?"":to!string(_type)), _bonus);
            break;
        case "GetSpeed":
            if (_type == action_type.nop || _type == m["ActionType"].i)
                m["Speed"] = m["Speed"].i*(100-_bonus)/100;
            break;
        case "Donning":
            global_console.append("You feel yourself moving faster.");
            break;
        case "Doffing":
            global_console.append("You feel yourself moving slower.");
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new speedup_effect_property(_bonus, _type); }
}
class armor_property : property {
    int _ac;
    this(int ac) {
        super("armor");
        _ac = ac;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            m["DisplayName"] = format("%s (%s)", m["DisplayName"].s, _ac);
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new armor_property(_ac); }
}
class weapon_property : property {
    roller _damage;
    this(roller damage) {
        super("weapon");
        _damage = damage;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetDisplayName":
            m["DisplayName"] = format("%s {%s}", m["DisplayName"].s, _damage);
            break;
        case "ComputeMeleeDamage":
            m["MeleeDamage"] = m["MeleeDamage"].i + _damage.roll(global_world.play_rng);
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new weapon_property(_damage); }
}
class ench_property : property {
    int _ench;
    this(int ench) {
        super("ench");
        _ench = ench;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetShortDisplayName":
            if (_ench != 0) m["ShortDisplayName"] = format("%+d %s", _ench, m["ShortDisplayName"].s);
            break;
        case "GetDisplayName":
            if (_ench != 0) m["DisplayName"] = format("%+d %s", _ench, m["DisplayName"].s);
            break;
        case "ComputeMeleeDamage":
            if (_ench != 0) m["MeleeDamage"].i += _ench;
            break;
        case "ComputeMissileDamage":
            if (_ench != 0) m["MissileDamage"].i += _ench;
            break;
        case "GainLevel":
            ++_ench;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new ench_property(_ench); }
}
class xp_property : property {
    int _xp;
    int _next;
    int _level;
    this() {
        super("xp");
        _xp = 0;
        _next = 10;
        _level = 0;
    }
    this(int xp, int next, int level) {
        super("xp");
        _xp = xp;
        _next = next;
        _level = level;
    }
    override message handle_message(message m) {
        switch (m.id) {
        //case "GetDisplayName":
        //    m["DisplayName"] = m["DisplayName"].s ~ format(" (XP:%d/%d L:%d)", _xp, _next, _level);
        //    break;
        case "AddXP":
            _xp += m["XP"].i;
            while (_xp >= _next) {
                message mess = new message("GainLevel");
                m._sender.handle_message(mess);
            }
            break;
        case "GainLevel":
            if (m._sender == global_world.player_go)
                global_console.append("You gain a level.", Color.blue|Bright);
            ++_level;
            _next *= 2;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new xp_property(_xp, _next, _level); }
}
// for objs that can hold multiple items
class inventory_property : property {
    int _capacity;
    gameobj[] _items;
    this(int capacity, gameobj[] items=null) {
        super("inventory");
        _capacity = capacity;
        _items = items;
    }
    override message handle_message(message m) {
        switch (m.id) {
        //case "GetShortDisplayName":
        //    break;
        //case "GetDisplayName":
        //    break;
        case "GetCapacity":
            m["Capacity"] = _capacity;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new inventory_property(_capacity, _items.dup()); }
}
// for dungeon locations...
class tile_property : property {
    this() {
        super("tile");
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "MovedOnto":
            break;
        case "MovedOff":
            break;
        case "MovedAdjacent":
            break;
        case "MovedAway":
            break;
        case "Activated":
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new tile_property(); }
}
class mana_property : property {
    int _mana;
    int _mana_max;
    this(int mana=0, int mana_max=0) {
        super("mana");
        _mana = mana;
        _mana_max = mana_max;
    }
    override message handle_message(message m) {
        switch (m.id) {
        case "GetMana":
            m["Mana"] = _mana;
            break;
        case "GetManaMax":
            m["ManaMax"] = _mana_max;
            break;
        case "SetMana":
            _mana = m["Mana"].i;
            break;
        case "SetManaMax":
            _mana_max = m["ManaMax"].i;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new mana_property(_mana, _mana_max); }
}



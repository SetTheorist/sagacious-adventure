module item;

import std.algorithm;
import std.conv;
import std.string;

import main : global_console, global_world;
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

    private property[] _properties;

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

    ref message handle_message(ref message m) {
        m._sender = this;
        foreach (p; _properties)
            if ((m = p.handle_message(m)) is null)
                break;
        return m;
    }
}
class message {
    private string _id;
    gameobj _sender;
    private field[string] _fields;
    this(string id) { _id = id; }

    @property string id() const { return _id; }

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
}
class property {
    private string _id;
    int _priority;
    this(string id) { _id = id; _priority = 0; }
    ref message handle_message(ref message m) { return m; }
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
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "GetSymbol":
            m["Symbol"] = _symbol;
            break;
        case "GetShortDisplayName":
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
    override ref message handle_message(ref message m) {
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
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "GetSize":
            m["Size"].i = _size;
            break;
        case "Wielding":
            break;
        case "Unwielding":
            break;
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
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "GetDisplayName":
            if (_known)
                m["DisplayName"] = m["DisplayName"].s ~ " {cursed}";
            break;
        case "Donning":
        case "Wielding":
            message mess = new message("GetShortDisplayName");
            m._sender.handle_message(mess);
            global_console.append(format("The %s appears to be cursed.", mess["ShortDisplayName"]), Color.yellow);
            _known = true;
            break;
        case "Doffing":
        case "Unwielding":
            message mess = new message("GetShortDisplayName");
            m._sender.handle_message(mess);
            global_console.append(format("You cannot remove the cursed %s.", mess["ShortDisplayName"].s), Color.yellow);
            _known = true;
            m = null;
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
    gameobj[] _body_parts;
    tick      _speed;
    this(int hp, int hp_max, tick speed, gameobj[] body_parts) {
        super("body");
        _hp = hp;
        _hp_max = hp_max;
        _speed = speed;
        _body_parts = body_parts;
    }
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "GetHP":
            m["HP"] = _hp;
            break;
        case "GetHPMax":
            m["HPMax"] = _hp_max;
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
        default: break;
        }
        return m;
    }
    override property clone() { 
        gameobj[] body_parts = _body_parts[];
        foreach (ref bp; body_parts)
            bp = bp.clone();
        return new body_property(_hp, _hp_max, _speed, body_parts);
    }
};
class body_part_property : property {
    string _type;
    gameobj _worn;
    gameobj _wielded;
    this(string type, gameobj worn = null, gameobj wielded = null) {
        super("body_part");
        _type = type;
        _worn = worn;
        _wielded = wielded;
    }
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "Donning":
            break;
        case "Doffing":
            break;
        case "Wielding":
            break;
        case "Unwielding":
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new body_part_property(_type, _worn, _wielded); }
}
class wearable_property : property {
    string _location;
    property _effect;
    this(string location, property effect = null) {
        super("wearable");
        _location = location;
        _effect = effect;
    }
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "Donning":
            if (_effect) {
                _effect.handle_message(m);
                m._sender.add(_effect,10);
            }
            break;
        case "Doffing":
            if (_effect) {
                _effect.handle_message(m);
                m._sender.remove(_effect);
            }
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new wearable_property(_location, _effect); }
}
class damage_effect_property : property {
    int _bonus;
    this(int bonus) {
        super("damage_effect");
        _bonus = bonus;
    }
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "ComputeMeleeDamage":
            m["MeleeDamage"] = m["MeleeDamage"].i + _bonus;
            break;
        case "ComputeMissileDamage":
            m["MissileDamage"] = m["MissileDamage"].i + _bonus;
            break;
        default: break;
        }
        return m;
    }
    override property clone() { return new damage_effect_property(_bonus); }
}
class weapon_property : property {
    roller _damage;
    this(roller damage) {
        super("weapon");
        _damage = damage;
    }
    override ref message handle_message(ref message m) {
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
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "GetShortDisplayName":
        case "GetDisplayName":
            if (_ench != 0) m["DisplayName"] = format("%+d %s", _ench, m["DisplayName"].s);
            break;
        case "ComputeMeleeDamage":
            if (_ench != 0) m["MeleeDamage"] = m["MeleeDamage"].i + _ench;
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
    override ref message handle_message(ref message m) {
        switch (m.id) {
        case "GetDisplayName":
            m["DisplayName"] = m["DisplayName"].s ~ format(" (XP:%d/%d L:%d)", _xp, _next, _level);
            break;
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

/*
// ECS system (v2)
struct item {
    ulong id;
    static ulong _next = 1L;
    static item next() {
        return item(_next++);
    }
    static item clone(item e) {
        item it = next();
        return it;
    }
}

abstract class icomponent {
private:
    string _name;
public:
    static icomponent[] components;
    this(string name) { _name = name; components ~= this; }

    void add(const item e);
    void clone(const item e, const item f);
    void remove(const item e);
    bool has(const item e) const;
    bool set_string(const item e, string s);
    string get_string(const item e) const;
    string get_raw_string(const item e) const;
    int opApply(int delegate(const ref item) dg) const;
    bool remove_processor(string key);
}

class component(T) : icomponent {
public:
    alias processor = bool delegate(item e, const component!T comp, ref T value);
private:
    struct pp { string key; int priority; processor proc; }
    T[item] _values;
    pp[] _processors;
public:
    this(string name) {
        super(name);
    }
    bool set(const item e, const T val) {
        _values[e] = val;
        return true;
    }
    override bool set_string(const item e, string val_string) {
        _values[e] = to!T(val_string);
        return true;
    }
    override string get_string(const item e) const {
        return to!string(get(e));
    }
    override string get_raw_string(const item e) const {
        return to!string(_values[e]);
    }
    override void add(const item e) {
        T t;
        _values[e] = t;
    }
    override void clone(const item e, const item f) {
        _values[e] = _values[f];
    }
    override void remove(const item e) {
        _values.remove(e);
    }
    override bool has(const item e) const {
        return (e in _values) != null;
    }
    override int opApply(int delegate(const ref item) dg) const {
        int result = 0;
        foreach (e; _values.keys)
            if ((result = dg(e))!=0)
                break;
        return result;
    }
    T get_raw(const item e) const {
        return _values[e];
    }
    T get(const item e) const {
        T v = _values[e];
        foreach (p; _processors)
            if (p.proc(e, this, v))
                break;
        return v;
    }
    bool add_processor(string key, int priority, processor proc) {
        _processors ~= pp(key, priority, proc);
        sort!((a,b) => a.priority>b.priority)(_processors);
        return true;
    }
    override bool remove_processor(string key) {
        for (int i=0; i<_processors.length; ++i) {
            if (_processors[i].key == key) {
                _processors[i..$-1] = _processors[i+1..$];
                --_processors.length;
                return true;
            }
        }
        return false;
    }
}
*/

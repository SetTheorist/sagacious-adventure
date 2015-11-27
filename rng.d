module rng;

import std.conv;
import std.algorithm;
import std.random;
import std.regex;
import std.string;

class rng {
    Random gen;
public:
    this(uint seed) {
        gen.seed(seed);
    }
    real uniform(real h = 1.0, real l = 0.0) {
        return std.random.uniform(l, h, gen);
    }
    int uniform(int h = 1, int l = 0) {
        return std.random.uniform(l, h+1);
    }
};

//roller to(T : roller) (string s) {
//    return roller(s);
//}

interface roller {
    int     roll(rng r);
    real    ave();
    real    min() const;
    real    max() const;

    // cheesy recursive regex-based parser
    // (doesn't handle sum_roller() yet)
    static roller opCall(string s) {
        static auto mre = ctRegex!r"^(max|min)\((\d+),(\d+),(.*)\)$";
        static auto dre = ctRegex!r"^(\d*)d(\d+)$";
        static auto bre = ctRegex!r"^(.*)([-+]\d+)$";
        if (auto m = matchFirst(s, mre)) {
            int mi = to!int(m[2]);
            int ni = to!int(m[3]);
            roller r = roller(m[4]);
            if (m[1]=="max") {
                return new max_roller(mi, ni, r);
            } else if (m[1]=="min") {
                return new min_roller(mi, ni, r);
            } else {
                throw new Throwable(format("Unrecognized '%s' when parsing '%s' as a roller", m[1], s));
            }
        } else if (auto m = matchFirst(s, dre)) {
            return new die_roller(m[1]=="" ? 1 : to!int(m[1]), to!int(m[2]));
        } else if (auto m = matchFirst(s, bre)) {
            return new plus_roller(to!int(m[2]), roller(m[1]));
        } else {
            throw new Throwable(format("Unable to parse '%s' as a roller", s));
        }
    }
private:
    final real estimate_ave(int n=1000) {
        rng r = new rng(13);
        real sum = 0.0;
        for (int i=0; i<n; ++i)
            sum += roll(r);
        return sum / n;
    }
public:
    static roller d3, d4, d6, d8, d10, d12, d20, d30, d100;
    static this() {
        d3 = new die_roller(1,3);
        d4 = new die_roller(1,4);
        d6 = new die_roller(1,6);
        d8 = new die_roller(1,8);
        d10 = new die_roller(1,10);
        d12 = new die_roller(1,12);
        d20 = new die_roller(1,20);
        d30 = new die_roller(1,30);
        d100 = new die_roller(1,100);
    }
};

class die_roller : roller {
    const int     n;
    const int     s;
public:
    this(int n_, int s_) { n = n_; s = s_; }
    int roll(rng r) { int sum = 0; for (int i=0; i<n; ++i) sum += r.uniform(s,1); return sum; }
    real ave() { return n*(s+1)*0.5; }
    real min() const { return cast(real)(n); }
    real max() const { return cast(real)(n*s); }
    override string toString() const { return format("%dd%d", n, s); }
};

class plus_roller : roller {
    const int     b;
    roller  d;
public:
    this(int b_, roller d_) { b=b_; d=d_; }
    int roll(rng r) { return b+d.roll(r); }
    real ave() { return b+d.ave(); }
    real min() const { return b+d.min(); }
    real max() const { return b+d.max(); }
    override string toString() const { return format("%s%+d", d, b); }
};

class add_roller : roller {
    roller[] ds;
public:
    this(roller[] ds_) { ds = ds_; }
    int roll(rng r) { int ret=0; foreach (d;ds) ret+=d.roll(r); return ret; }
    real ave() { real ret=0.0; foreach (d;ds) ret+=d.ave(); return ret; }
    real min() const { real ret=0.0; foreach (d;ds) ret+=d.min(); return ret; }
    real max() const { real ret=0.0; foreach (d;ds) ret+=d.max(); return ret; }
    override string toString() const { string ret=null; foreach (d;ds) { if(ret is null) ret=text(d); else ret=ret~"+"~text(d); } return ret; }
};

class sum_roller : roller {
    const int   n;
    roller      d;
public:
    this(int n_, roller d_) { n=n_; d=d_; }
    int roll(rng r) {
        int sum = 0;
        for (int i=0; i<n; ++i)
            sum += d.roll(r);
        return sum;
    }
    real ave() { return n*d.ave(); }
    real min() const { return n*d.min(); }
    real max() const { return n*d.max(); }
    override string toString() const { return format("%s%s", n, d); }
};

class max_roller : roller {
    const int     m;
    const int     n;
    roller    d;
    int[]   buff;
    real cache_ave;
    bool have_ave;
public:
    this(int m_, int n_, roller d_) { m=m_; n=n_; d=d_; buff = new int[n]; } // sum max m out of n rolls
    int roll(rng r) { // not thread-safe, but less gc usage...
        for (int i=0; i<n; ++i)
            buff[i] = d.roll(r);
        sort!"a > b"(buff);
        int sum = 0;
        for (int i=0; i<m; ++i)
            sum += buff[i];
        return sum;
    }
    real ave() { if (!have_ave) {have_ave=true; cache_ave = estimate_ave(); } return cache_ave; }
    real min() const { return m*d.min(); }
    real max() const { return m*d.max(); }
    override string toString() const { return format("max(%s,%s%s)", m, n, d); }
};

class min_roller : roller {
    int     m;
    int     n;
    roller    d;
    int[]   buff;
    real cache_ave;
    bool have_ave;
public:
    this(int m_, int n_, roller d_) { m=m_; n=n_; d=d_; buff = new int[n]; } // sum min m out of n rolls
    int roll(rng r) { // not thread-safe, but less gc usage...
        for (int i=0; i<n; ++i)
            buff[i] = d.roll(r);
        sort!"a < b"(buff);
        int sum = 0;
        for (int i=0; i<m; ++i)
            sum += buff[i];
        return sum;
    }
    real ave() { if (!have_ave) {have_ave=true; cache_ave = estimate_ave(); } return cache_ave; }
    real min() const { return m*d.min(); }
    real max() const { return m*d.max(); }
    override string toString() const { return format("min(%s,%s%s)", m, n, d); }
};

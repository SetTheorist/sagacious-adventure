module util;

import core.thread;
import std.stdio;
import std.string;

struct tick {
    long value;
    string toString() const {
        return format("%03d`%02d:%02d:%02d'%02d,%02d,%02d,%02d",
            cast(int)((value/60/60/60/60/60/60/60)),
            cast(int)((value/60/60/60/60/60/60) % 60),
            cast(int)((value/60/60/60/60/60) % 60),
            cast(int)((value/60/60/60/60) % 60),
            cast(int)((value/60/60/60) % 60),
            cast(int)((value/60/60) % 60),
            cast(int)((value/60) % 60),
            cast(int)((value) % 60)
            );
    }
    tick opUnary(string s)() if (s=="++") { ++value; return this; }
    tick opUnary(string s)() if (s=="--") { --value; return this; }

    tick opUnary(string s)() if (s=="+")  { return tick(+value); }
    tick opUnary(string s)() if (s=="-")  { return tick(-value); }

    ref tick opOpAssign(string s)(const tick t) if (s=="+") { value+=t.value; return this; }
    ref tick opOpAssign(string s)(const tick t) if (s=="-") { value-=t.value; return this; }

    ref tick opOpAssign(string s)(const int t) if (s=="+") { value+=t; return this; }
    ref tick opOpAssign(string s)(const int t) if (s=="-") { value-=t; return this; }
    ref tick opOpAssign(string s)(const int t) if (s=="*") { value*=t; return this; }
    ref tick opOpAssign(string s)(const int t) if (s=="/") { value/=t; return this; }

    int opCmp(const tick t) const { return value<t.value ? -1 : value>t.value ? +1 : 0; }
    tick opBinary(string s)(const tick t) if (s=="+") { return tick(value+t.value); }
    tick opBinary(string s)(const tick t) if (s=="-") { return tick(value-t.value); }
    tick opBinary(string s)(const int t) if (s=="+") { return tick(value+t); }
    tick opBinary(string s)(const int t) if (s=="-") { return tick(value-t); }
    tick opBinary(string s)(const int t) if (s=="*") { return tick(value*t); }
    tick opBinary(string s)(const int t) if (s=="/") { return tick(value/t); }
    static ulong tps() pure nothrow @nogc { return 60*60*60*60UL; }
};

/// Returns: Most precise clock ticks, in microseconds.
tick getTicks() nothrow @nogc
{
    import core.time;
    return tick(convClockFreq(MonoTime.currTime.ticks, MonoTime.ticksPerSecond, tick.tps()));
}

void sleep(tick sleepy_time)
{
    real ns = sleepy_time.value * 1000000.0 / tick.tps();
    if (ns <= 0.0) return;
    Thread.sleep(dur!("usecs")(cast(ulong)ns));
}

version(Windows) {
    extern(C) int kbhit();
    extern(C) int getch();
}
version(Posix) {
    extern(C) int read_char();
    extern(C) int input_available();
}

bool keyReady() {
    version(Windows) {
        return kbhit()!=0;
    }
    version(Posix) {
        return input_available()!=0;
    }
    return true;
}

int getKey() {
    version(Windows) {
        return getch();
    }
    version(Posix) {
        return read_char();
    }
}


module rational_lib;
// Written in the D programming language.

/**
This module contains the $(LREF Rational) type, which is used to represent
rational numbers, along with related mathematical operations.

Authors:    Arlen Aghakians
Copyright:  Copyright (c) 2012, Arlen Aghakians
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:     $(PHOBOSSRC std/_rational.d)
*/
import std.traits    : Unqual, isIntegral, isSigned, CommonType, isFloatingPoint;
import std.string    : format;
import std.conv      : to;
static import math = std.math;


private template isSignedIntegral(T)
{
    enum isSignedIntegral = isIntegral!T && isSigned!T;
}

/**
Helper function that returns a rational number with the specified
numerator and denominator.

This function returns a $(B Rational!long) if neither $(B num) nor
$(B den) are signed integrals; otherwise, the return type is deduced
using $(B std.traits.CommonType!(N, D)).

Examples:
---
auto r1 = rational(2,4);
assert(r1.num == 1);
assert(r1.den == 2);
assert(r1.value == 0.5)

auto r2 = r1 * rational(4,3);
auto s = r2.toString();
assert(s == "(2/3)");

r2 /= 3;
assert(r2 == rational(2,9));
---
*/
auto rational(N)(N num) @safe pure if (is(N : long))
{
    static if (isSignedIntegral!N)
    {
        return Rational!N(num, 1);
    }
    else
    {
        return Rational!long(num, 1);
    }
}

/// ditto
auto rational(N, D)(N num, D den) @safe pure
if (is(N : long) && is(D : long))
{
    static if (isSignedIntegral!N || isSignedIntegral!D)
    {
        return Rational!(CommonType!(N, D))(num, den);
    }
    else
    {
        return Rational!long(num, den);
    }
}

unittest
{
    auto a = rational(1);
    static assert(is(typeof(a) == Rational!int));
    assert(a.num == 1);
    assert(a.den == 1);

    auto b = rational(2L);
    static assert(is(typeof(b) == Rational!long));
    assert(b.num == 2L);
    assert(b.den == 1L);

    auto c = rational(2, -4);
    static assert(is(typeof(c) == Rational!int));
    assert(c.num == -1);
    assert(c.den == 2);

    auto d = rational(-2, 6L);
    static assert(is(typeof(d) == Rational!long));
    assert(d.num == -1L);
    assert(d.den == 3L);

    auto e = rational('a', 'c');
    static assert(is(typeof(e) == Rational!long));
    assert(e.num == 97L);
    assert(e.den == 99L);
}

/**
A rational number parameterised by a type $(B T), which must be
a signed integral.  The rational number is reduced to its simplest form.
Rational is more efficient if both the numerator and the denominator are
immutable because it is simplified only once in the constructor.
*/
struct Rational(T) if (isSignedIntegral!T)
{
    static if (is(T == immutable) || is(T == const))
    {
        private enum bool mutableT = false;
    }
    else
    {
        private enum bool mutableT = true;
    }

    static if (mutableT)
    {
        private T numerator;
        private T denominator = 1;
        private bool dirty;
    }
    else
    {
        private T numerator, denominator;
        @disable this();
    }

    /// Converts the rational number to a string representation.
    void toString(scope void delegate(const(char)[]) sink,
                  string fmt = "%s") const
                  {
                      sink(format(fmt, format("(%s/%s)", this.num, this.den)));
                  }

    /// ditto
    void toString(scope void delegate(const(char)[]) sink, string fmt = "%s")
    {
        /* non-const versions of num() and den() are called, which update if
        dirty. */
        sink(format(fmt, format("(%s/%s)", this.num, this.den)));
    }

    /// Returns the numerator of the rational number.
    @property T num() @safe const pure nothrow
    {
        return this.numerator;
    }

    /// Returns the denominator of the rational number.
    @property T den() @safe const pure nothrow
    {
        return this.denominator;
    }

    /// Returns the integer part of the rational number
    @property T trunc() @safe const pure nothrow
    {
        return this.numerator/this.denominator;
    }

    static if (mutableT)
    {
        /**
        Returns the numerator of the rational number.  The rational number is
        simplified if it is not already in simplified form.  This method is
        available only if the numerator and the denominator are both mutable.
        */
        @property T num() @safe pure nothrow
        {
            if (dirty)
            {
                this = Rational(this.numerator, this.denominator);
            }
            return this.numerator;
        }

        /**
        Returns the denominator of the rational number.  The rational number
        is simplified if it is not already in simplified form.  This method is
        available only if the numerator and the denominator are both mutable.
        */
        @property T den() @safe pure nothrow
        {
            if (dirty)
            {
                this = Rational(this.numerator, this.denominator);
            }
            return this.denominator;
        }

        /// Sets the numerator to $(B n).
        @property void num(T n) @safe pure nothrow
        {
            if (!dirty)
            {
                dirty = true;
            }
            this.numerator = n;
        }

        /// Sets the denominator to $(B d).
        @property void den(T d) @safe pure nothrow
        {
            if (d == 0)
            {
                d = d / 0;
            }

            if (!dirty)
            {
                dirty = true;
            }
            this.denominator = d;
        }
    }

    ///
    this(T num, T den = 1) @safe pure nothrow
    {
        if (den == 0)
        {
            auto t = num / 0;
        }

        static if (is(T == const) || is(T == immutable))
        {
            alias Unqual!T G;
        }
        else
        {
            alias T G;
        }

        G a = math.abs(num);
        G b = math.abs(den);
        while (b)
        {
            auto t = b;
            b = a % b;
            a = t;
        }
        T d = a * (den < 0 ? -1 : 1);
        this.numerator = num / d;
        this.denominator = den / d;
    }


    /// Converts the rational number to a floating-point representation.
    @property F value(F = double)() @safe const pure nothrow
        if (isFloatingPoint!F)
        {
            return to!F(this.num) / to!F(this.den);
        }

    // rational == rational
    ///
    bool opEquals(G)(Rational!G other) @safe const pure nothrow
    {
        return this.num == other.num &&
            this.den == other.den;
    }

    // rational == integral
    ///
    bool opEquals(G)(G i) @safe const pure nothrow
        if (isSignedIntegral!G)
        {
            return this.num == i && this.den == 1;
        }

    // rational cmp rational and rational cmp integral
    ///
    int opCmp(T)(T other) @safe const pure nothrow
        if (isSignedIntegral!T || isRational!T)
        {
            auto diff = (this - other).num;
            if (diff < 0) return -1;
            if (diff > 0) return  1;
            return 0;
        }

    // -rational
    ///
    Rational opUnary(string op)() @safe const pure nothrow if (op == "-")
    {
        return Rational(-this.num, this.den);
    }

    // rational + rational, rational - rational
    ///
    Rational!(CommonType!(T,G)) opBinary(string op, G)(Rational!G other)
        @safe const pure nothrow if (op == "+" || op == "-")
        {
            alias typeof(return) R;
            return R(mixin("this.num * other.den" ~ op ~ "other.num * this.den"),
                     this.den * other.den);
        }

    // rational + integral, rational - integral
    ///
    Rational!(CommonType!(T,G)) opBinary(string op, G)(G i)
        @safe const pure nothrow if ((op == "+" || op == "-") && isSignedIntegral!G)
        {
            alias typeof(return) R;
            return R(mixin("this.num" ~ op ~ "i * this.den"), this.den);
        }

    // integral + rational, integral * rational
    ///
    Rational!(CommonType!(T,G)) opBinaryRight(string op, G)(G i)
        @safe const pure nothrow if ((op == "+" || op == "*") && isSignedIntegral!G)
        {
            return opBinary!(op, CommonType!(T,G))(i);
        }

    // integral - rational
    ///
    Rational!(CommonType!(T,G)) opBinaryRight(string op, G)(G i)
        @safe const pure nothrow if ((op == "-") && isSignedIntegral!G)
        {
            alias typeof(return) R;
            return R(i * this.den - this.num, this.den);
        }

    // rational * rational
    ///
    Rational!(CommonType!(T,G)) opBinary(string op, G)(Rational!G other)
        @safe const pure nothrow if (op == "*")
        {
            alias typeof(return) R;
            return R(this.num * other.num, this.den * other.den);
        }

    // rational * integral
    ///
    Rational!(CommonType!(T,G)) opBinary(string op, G)(G i)
        @safe const pure nothrow if (op == "*" && isSignedIntegral!G)
        {
            alias typeof(return) R;
            return R(this.num * i, this.den);
        }

    // rational / rational
    ///
    Rational!(CommonType!(T,G)) opBinary(string op, G)(Rational!G other)
        @safe const pure nothrow if (op == "/")
        {
            alias typeof(return) R;
            return R(this.num * other.den, this.den * other.num);
        }

    // rational / integral
    ///
    Rational!(CommonType!(T,G)) opBinary(string op, G)(G i)
        @safe const pure nothrow if (op == "/" && isSignedIntegral!G)
        {
            alias typeof(return) R;
            return R(this.num, this.den * i);
        }

    // integral / rational
    ///
    Rational!(CommonType!(T,G)) opBinaryRight(string op, G)(G i)
        @safe const pure nothrow if (op == "/" && isSignedIntegral!G)
        {
            alias typeof(return) R;
            return R(i * this.den, this.num);
        }

    ///
    ref Rational opOpAssign(string op, G)(Rational!G other) @safe pure nothrow
    {
        this = this.opBinary!(op, G)(other);
        return this;
    }

    ///
    ref Rational opOpAssign(string op, G)(G i) @safe pure nothrow
        if (isSignedIntegral!G)
        {
            this = this.opBinary!(op, G)(i);
            return this;
        }
}

//void main() { }

unittest
{
    auto r1 = rational(2, 3);
    auto r2 = rational(-1, 4);
    auto r3 = rational(0);
    auto r4 = rational(4);

    // Check equality
    assert(r1 != r2);
    assert(r2 == r2);
    assert(r3.num == 0);
    assert(r3.den == 1);
    assert(r4 == 4);
    assert(4 == r4);

    // Check comparison
    assert(r1 > r2);
    assert(r1 >= r2);
    assert(!(r1 <= r2));
    assert(r2 < r1);
    assert(r2 <= r1);
    assert(!(r2 >= r1));
    assert(r1 < 1);
    assert(r1 > 0);
    assert(1 > r1);
    assert(0 < r1);
    assert(r2 < 0);
    assert(r2 > -1);
    assert(0 > r2);
    assert(-1 < r2);
}

unittest
{
    auto r1 = rational(2, 3);
    auto r2 = rational(-1, 4);
    auto r3 = rational(0);

    // Check rational-rational operations.
    auto rpr = r1 + r2;
    assert(rpr.num == 5);
    assert(rpr.den == 12);

    auto rmr = r1 - r2;
    assert(rmr.num == 11);
    assert(rmr.den == 12);

    auto rtr = r1 * r2;
    assert(rtr.num == -1);
    assert(rtr.den == 6);

    auto rdr = r1 / r2;
    assert(rdr.num == -8);
    assert(rdr.den == 3);

    // Check rational-integral operations.
    auto a = 3;

    auto rpi = r1 + a;
    assert(rpi.num == 11);
    assert(rpi.den == 3);

    auto rmi = r1 - a;
    assert(rmi.num == -7);
    assert(rmi.den == 3);

    auto rti = r1 * a;
    assert(rti.num == 2);
    assert(rti.den == 1);

    auto rdi = r1 / 2;
    assert(rdi.num == 1);
    assert(rdi.den == 3);

    // Check integral-rational operations.
    auto ipr = a + r1;
    assert(ipr.num == 11);
    assert(ipr.den == 3);

    auto imr = a - r1;
    assert(imr.num == 7);
    assert(imr.den == 3);

    auto itr = a * r1;
    assert(itr.num == 2);
    assert(itr.den == 1);

    auto idr = 2 / r1;
    assert(idr.num == 3);
    assert(idr.den == 1);

    // Check operations between different rational types.
    alias immutable long T1;
    alias const long T2;
    alias long T3;


    immutable Rational!(T1) a1 = Rational!(T1)(1,2);
    immutable Rational!(T2) a2 = Rational!(T2)(1,3);
    immutable Rational!(T3) a3 = Rational!(T3)(1,4);
    Rational!(T1) a4 = Rational!(T1)(2,3);
    Rational!(T2) a5 = Rational!(T2)(2,4);
    Rational!(T3) a6 = Rational!(T3)(2,5);

    auto rl = Rational!long(1,2);
    auto ri = Rational!int(1,2);
    auto r1rl = r1 + rl;
    auto r1ri = r1 + ri;
    static assert(is(typeof(r1rl) == Rational!long));
    static assert(is(typeof(r1ri) == Rational!int));
    assert(r1rl.num == r1ri.num);
    assert(r1rl.den == r1ri.den);
}

unittest
{
    auto r1 = rational(0);
    auto r2 = rational(1,2);

    // Check assignments
    r1.num = 2;
    assert(r1.num == 2);
    assert(r1.den == 1);

    r1.den = 4;
    assert(r1.num == 1);
    assert(r1.den == 2);

    r1 += 1;
    assert(r1.num == 3);
    assert(r1.den == 2);

    r1 -= 2;
    assert(r1.num == -1);
    assert(r1.den == 2);

    r1 *= 2;
    assert(r1.num == -1);
    assert(r1.den == 1);

    r1 /= 4;
    assert(r1.num == -1);
    assert(r1.den == 4);
}

unittest
{
    // Convert to string.
    auto r1 = rational(3,4);
    auto r2 = rational(2,4);
    immutable r3 = rational(4,12);

    auto s1 = to!string(r1);
    assert(s1 == "(3/4)");

    auto s2 = to!string(r2);
    assert(s2 == "(1/2)");

    auto s3 = to!string(r3);
    assert(s3 == "(1/3)");
}

/**
Check to see if $(B T) is a Rational.
*/
template isRational(T)
{
    static if(is(T R == Rational!G, G))
    {
        enum bool isRational = true;
    }
    else
    {
        enum bool isRational = false;
    }
}

unittest
{
    static assert(isRational!(Rational!long));
    static assert(!isRational!long);
}

/**
Calculates the absolute value.

Examples:
---
auto a = rational(-2,4);
assert(abs(a) == rational(1,2));
---
*/
Rational!G abs(G)(Rational!G r) @safe pure
{
    return Rational!G(math.abs(r.num), r.den);
}

unittest
{
    auto a = rational(-2,4);
    assert(abs(a) == rational(1,2));

    auto b = rational(2,4);
    assert(abs(b) == rational(2,4));
}

private immutable auto half = rational(1,2);
private immutable auto one  = rational(1);

/**
Returns the truncated value (towards positive infinity).

Examples:
---
assert(ceil(rational(7,5)) == 2);
assert(ceil(rational(-5,3)) == -1);
---
*/
G ceil(G)(Rational!G r) @safe pure nothrow
{
    if (r.den == 1)
    {
        return r.num;
    }

    auto t = r.num > 0 ? r + one : r;
    return t.num / t.den;
}

unittest
{
    assert(ceil(rational(0)) == 0);
    assert(ceil(rational(7,5)) == 2);
    assert(ceil(rational(3,2)) == 2);
    assert(ceil(rational(5,3)) == 2);
    assert(ceil(rational(2)) == 2);
    assert(ceil(rational(-7,5)) == -1);
    assert(ceil(rational(-3,2)) == -1);
    assert(ceil(rational(-5,3)) == -1);
    assert(ceil(rational(-2)) == -2);
}

/**
Returns the truncated value (towards negative infinity).

Examples:
---
assert(floor(rational(7,5)) == 1);
assert(floor(rational(-5,3)) == -2);
---
*/
G floor(G)(Rational!G r) @safe pure nothrow
{
    if(r.den == 1)
    {
        return r.num;
    }

    auto t = r.num > 0 ? r : r - one;
    return t.num / t.den;
}

unittest
{
    assert(floor(rational(0)) == 0);
    assert(floor(rational(7,5)) == 1);
    assert(floor(rational(3,2)) == 1);
    assert(floor(rational(5,3)) == 1);
    assert(floor(rational(2)) == 2);
    assert(floor(rational(-7,5)) == -2);
    assert(floor(rational(-3,2)) == -2);
    assert(floor(rational(-5,3)) == -2);
    assert(floor(rational(-2)) == -2);
}

/**
Returns the truncated value (towards the nearest integer;
(1/2) => 1; (-1/2) => -1).

Examples:
---
assert(round(rational(7,5)) == 1);
assert(round(rational(-7,5)) == -1);
---
*/
G round(G)(Rational!G r) @safe pure nothrow
{
    if(r.den == 1)
    {
        return r.num;
    }

    auto t = r.num > 0 ? r + half : r - half;
    return t.num / t.den;
}

unittest
{
    assert(round(rational(1,2)) == 1);
    assert(round(rational(-1,2)) == -1);
    assert(round(rational(0)) == 0);
    assert(round(rational(7,5)) == 1);
    assert(round(rational(3,2)) == 2);
    assert(round(rational(5,3)) == 2);
    assert(round(rational(2)) == 2);
    assert(round(rational(-7,5)) == -1);
    assert(round(rational(-3,2)) == -2);
    assert(round(rational(-5,3)) == -2);
    assert(round(rational(-2)) == -2);
}

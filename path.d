module path;

import std.math;
import std.stdio;

import map;
import priority_queue;

// result = minimal cost to reach point from start
void dijkstra(Pos)(Pos start,
                   real delegate(const Pos f, const Pos t) step_cost,
                   Pos[] delegate(const Pos) edges,
                   ref real[Pos] result,
                   real bound)
{
    auto q = new PriorityQueue!(Pos,real)();
    q.push(start, 0.0);
    result[start] = 0.0;
    while (q.size()) {
        Pos z = q.pop();
        real r_z = result[z];
        foreach (nz; edges(z)) {
            real or_nz = result.get(nz, real.infinity);
            real r_nz = r_z + step_cost(z,nz);
            if ((r_nz < or_nz) && (r_nz < bound)) {
                result[nz] = r_nz;
                q.push(nz, r_nz); // TODO: should check if nz already in q and just decrease cost then
            }
        }
    }
}

Pos[] astar(Pos)(Pos start, Pos goal,
            real delegate(const Pos f, const Pos t) step_cost,
            Pos[] delegate(const Pos) edges,
            Pos[] delegate(const Pos) back_edges,
            real delegate(const Pos f, const Pos t) estimate,
            ref real[Pos] result)
{
    auto q = new PriorityQueue!(Pos,real)();
    q.push(start, 0.0);
    result[start] = 0.0;
    while (q.size()) {
        Pos z = q.pop();
        //writef("{%s}",z); stdout.flush();
        real r_z = result[z];
        if (z == goal) break;
        foreach (nz; edges(z)) {
            real or_nz = result.get(nz, real.infinity);
            real r_nz = r_z + step_cost(z, nz);
            real est_nz = r_nz + estimate(nz, goal);
            if (r_nz < or_nz) {
                result[nz] = r_nz;
                q.push(nz, est_nz); // TODO: should check if nz in q already &c.
            }
        }
    }
    Pos[] path = [goal];
    Pos x = goal;
    while (x != start) {
        //writef("<%s>",x); stdout.flush();
        real min_res = real.infinity;
        Pos px;
        foreach (pz; back_edges(x)) {
            if (result.get(pz,real.infinity) < min_res) {
                px = pz;
                min_res = result[pz];
            }
        }
        if (min_res == real.infinity) break; // got stuck!
        x = px;
        path ~= x;
    }
    return path.reverse;
}

xy[] bresenham(xy start, xy goal) pure nothrow
{
    xy[] path;
    int x1 = start.x;
    int y1 = start.y;
    immutable int x2 = goal.x;
    immutable int y2 = goal.y;
    immutable int dx = x2 - x1;
    immutable int ix = (dx > 0) - (dx < 0);
    immutable size_t dx2 = abs(dx) * 2;
    int dy = y2 - y1;
    immutable int iy = (dy > 0) - (dy < 0);
    immutable size_t dy2 = abs(dy) * 2;

    path ~= xy(x1,y1);

    if (dx2 >= dy2) {
        int error = dy2 - (dx2 / 2);
        while (x1 != x2) {
            if (error >= 0 && (error || (ix > 0))) {
                error -= dx2;
                y1 += iy;
            }

            error += dy2;
            x1 += ix;
            path ~= xy(x1,y1);
        }
    } else {
        int error = dx2 - (dy2 / 2);
        while (y1 != y2) {
            if (error >= 0 && (error || (iy > 0))) {
                error -= dy2;
                x1 += ix;
            }

            error += dx2;
            y1 += iy;
            path ~= xy(x1,y1);
        }
    }

    return path;
}

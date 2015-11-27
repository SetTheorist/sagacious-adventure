module map;

import std.algorithm;
import std.math;
import std.stdio;

import rng;

////////////////////////////////////////////////////////////////////////////////////////////////////

struct xy {
    int x, y;

    xy opUnary(string s)() const if (s=="+") { return xy(+x,+y); }
    xy opUnary(string s)() const if (s=="-") { return xy(-x,-y); }

    xy opBinary(string s)(const xy t) const if (s=="+") { return xy(x+t.x,y+t.y); }
    xy opBinary(string s)(const xy t) const if (s=="-") { return xy(x-t.x,y-t.y); }

    ref xy opOpAssign(string s)(const xy t) if (s=="+") { x+=t.x; y+=t.y; return this; }
    ref xy opOpAssign(string s)(const xy t) if (s=="-") { x-=t.x; y-=t.y; return this; }

    real dist(xy t) const { return sqrt(cast(real)(x-t.x)*(x-t.x)+cast(real)(y-t.y)*(y-t.y)); }
    uint dist2(xy t) const { return (x-t.x)*(x-t.x)+(y-t.y)*(y-t.y); }

    static xy n, s, e, w, ne, se, sw, nw;
    static xy dirs[];
    static this() {
        n  = xy( 0,+1);
        s  = -n;
        e  = xy(+1, 0);
        w  = -e;
        ne = n + e;
        se = s + e;
        sw = s + w;
        nw = n + w;
        dirs = [n, ne, e, se, s, sw, w, nw];
    }
};
struct xyl {
    int x, y, l;

    this(int ix, int iy, int il) {
        x = ix;
        y = iy;
        l = il;
    }
    this(xy z) {
        x = z.x;
        y = z.y;
        l = 0;
    }

    xyl opUnary(string s)() if (s=="+") { return xyl(+x,+y,+l); }
    xyl opUnary(string s)() if (s=="-") { return xyl(-x,-y,-l); }

    xyl opBinary(string s)(const xyl t) if (s=="+") { return xyl(x+t.x,y+t.y,l+t.l); }
    xyl opBinary(string s)(const xyl t) if (s=="-") { return xyl(x-t.x,y-t.y,l-t.l); }

    ref xyl opOpAssign(string s)(const xy t) if (s=="+") { x+=t.x; y+=t.y; return this; }
    ref xyl opOpAssign(string s)(const xy t) if (s=="-") { x-=t.x; y-=t.y; return this; }
    ref xyl opOpAssign(string s)(const xyl t) if (s=="+") { x+=t.x; y+=t.y; l+=t.l; return this; }
    ref xyl opOpAssign(string s)(const xyl t) if (s=="-") { x-=t.x; y-=t.y; l-=t.l; return this; }

    real dist(xyl t) const { return sqrt(cast(real)(x-t.x)*(x-t.x)+cast(real)(y-t.y)*(y-t.y)+cast(real)(l-t.l)*(l-t.l)); }
    uint dist2(xyl t) const { return (x-t.x)*(x-t.x)+(y-t.y)*(y-t.y)+(l-t.l)*(l-t.l); }

    static xyl n, e, s, w, ne, se, nw, sw, d, u;
    static xyl dirs[];
    static this() {
        n  = xyl( 0,+1, 0);
        e  = xyl(+1, 0, 0);
        s  = -n;
        w  = -e;
        ne = n + e;
        se = s + e;
        sw = s + w;
        nw = n + w;
        d  = xyl( 0, 0,+1);
        u  = -d;
        dirs = [n, ne, e, se, s, sw, w, nw, d, u];
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////

class level(cell) {
    cell[][] grid;
    int nx, ny;
public:
    this(int inx, int iny) {
        grid = new cell[][](inx, iny);
        nx = inx;
        ny = iny;
    }

    ref cell opIndex(xy z) { return grid[z.x][z.y]; }
    ref cell opIndex(int x, int y) { return grid[x][y]; }

    bool inside(xy z) { return (z.x>=0 && z.y>=0 && z.x<nx && z.y<ny); }
    bool inside(int x, int y) { return (x>=0 && y>=0 && x<nx && y<ny); }

    xy[] neighbors(xy z, bool delegate(cell) pred) {
        xy[] ret;
        foreach (d; xy.dirs) {
            xy dz = z + d;
            if (inside(dz) && pred(grid[dz.x][dz.y]))
                ret ~= dz;
        }
        return ret;
    }

    void copy(fcell)(const level!fcell fmap, cell delegate(fcell) translator) {
        grid = new cell[][](nx, ny);
        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                grid[i][j] = translator(fmap.grid[i][j]);
            }
        }
    }

    void init(rng r, cell filler) {
        fill_rect(0, 0, nx, ny, filler);
    }

    void show() const {
        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                writef(" %s", grid[i][j]);
            }
            writeln();
        }
    }

    void fill_rect(int x, int y, int xl, int yl, cell filler) {
        for (int i=max(0,x); i<min(nx,x+xl); ++i)
            for (int j=max(0,y); j<min(ny,y+yl); ++j)
                grid[i][j] = filler;
    }
};

level!bool make_level_cellular_automata(rng r, int nx, int ny, real frac, int ns=10) {
    bool[][] grid = new bool[][](nx,ny);
    bool[][] old_grid = new bool[][](nx,ny);

    // initialize
    for (int i=0; i<nx; ++i)
        for (int j=0; j<ny; ++j)
            grid[i][j] = (i==0 || j==0 || i==nx-1 || j==ny-1 || (r.uniform(1.0) < frac));

    // iterate ca rule
    for (int s=0; s<ns; ++s) {
        old_grid[][] = grid[][];
        for (int i=1; i<nx-1; ++i) {
            for (int j=1; j<ny-1; ++j) {
                int count =
                    (old_grid[i+1][j-1]?1:0)+(old_grid[i+1][j  ]?1:0)+(old_grid[i+1][j+1]?1:0)
                   +(old_grid[i  ][j-1]?1:0)+(old_grid[i  ][j  ]?1:0)+(old_grid[i  ][j+1]?1:0)
                   +(old_grid[i-1][j-1]?1:0)+(old_grid[i-1][j  ]?1:0)+(old_grid[i-1][j+1]?1:0);
                grid[i][j] = (count>=5);
            }
        }
    }

    level!bool lev = new level!bool(nx, ny);
    for (int i=0; i<nx; ++i)
        for (int j=0; j<ny; ++j)
            lev.grid[i][j] = grid[i][j];
    return lev;
}

level!T make_level_grid_rooms(T)(rng r, int nx, int ny, int nrx, int nry, T floor, T wall, T door) {
    level!T lev = new level!T(nx, ny);
    lev.fill_rect(0, 0, nx, ny, wall);
    int lx = (nx-1) / nrx - 1;
    int ly = (ny-1) / nry - 1;
    for (int i=0; i<nrx; ++i) {
        for (int j=0; j<nry; ++j) {
            int sx = 1+(1+lx)*i;
            int sy = 1+(1+ly)*j;
            lev.fill_rect(sx, sy, lx, ly, floor);
            if (i>0) lev.grid[sx-1][sy + r.uniform(ly-1)] = door;
            if (j>0) lev.grid[sx + r.uniform(lx-1)][sy-1] = door;
        }
    }
    return lev;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

enum cell_type {
    floor, wall, door_open, door_closed, stairs_up, stairs_down
};

class dungeon_level {
    level!cell_type cells;
public:
    this(rng r, int nr, int nx, int ny) {
        cells = make_level_grid_rooms(r, nx, ny, nr, nr, cell_type.floor, cell_type.wall, cell_type.floor); //cell_type.door_closed);
    }
    ref cell_type opIndex(xy z) { return cells.grid[z.x][z.y]; }
    ref cell_type opIndex(int x, int y) { return cells.grid[x][y]; }
};

class dungeon {
    dungeon_level[] levels;
    int nx, ny, nl;
public:
    this(rng r, int inl, int nr, int inx, int iny) {
        nl = inl;
        nx = inx;
        ny = iny;
        levels = new dungeon_level[](nl);
        for (int i=0; i<nl; ++i)
            levels[i] = new dungeon_level(r, nr, nx, ny);

        for (int i=0; i<nl-1; ++i) {
            int x, y;
            find_floor(r, i, x, y);
            levels[i  ][x,y] = cell_type.stairs_down;
            levels[i+1][x,y] = cell_type.stairs_up;
        }
    }
    void find_floor(rng r, int l, out int x, out int y) {
        do {
            x = r.uniform(nx-1);
            y = r.uniform(ny-1);
        } while (levels[l][x,y] != cell_type.floor);
    }
    ref cell_type opIndex(xyl z) { return levels[z.l][z.x,z.y]; }
    ref cell_type opIndex(int x, int y, int l) { return levels[l][x,y]; }
};

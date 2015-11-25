module ui;

import std.algorithm;

import terminal;

class Window {
private:
    int x, y;
    int nx, ny;
    char ch[][];
    int fg[][];
    int bg[][];
public:
    int z;
    this(int ix, int iy, int iz, int inx, int iny) {
        x = ix;
        y = iy;
        z = iz;
        nx = inx;
        ny = iny;
        ch = new char[][](nx, ny);
        fg = new int[][](nx, ny);
        bg = new int[][](nx, ny);
    }
    void set(int ix, int iy, char ich, int ifg, int ibg) {
        if (ix>=0 && ix<nx && iy>=0 && iy<ny) {
            ch[ix][iy] = ich;
            fg[ix][iy] = ifg;
            bg[ix][iy] = ibg;
        }
    }
    void set(int ix, int iy, string s, int ifg, int ibg) {
        for (int i=0; i<s.length; ++i)
            set(ix+i, iy, s[i], ifg, ibg);
    }
}

class ConsoleWindow : Window {
    int end;
    this(int ix, int iy, int iz, int inx, int iny) {
        super(ix, iy, iz, inx, iny);
        end = 0;
    }
    void append(string s, int ifg = Color.white, int ibg = Color.black) {
        if (end + s.length > nx*ny)
            scroll(end + s.length - nx*ny);
        foreach (c; s) {
            int tx = (end % nx);
            int ty = ny-1-(end / nx);
            ++end;
            ch[tx][ty] = c;
            fg[tx][ty] = ifg;
            bg[tx][ty] = ibg;
        }
    }
    void scroll(int n) {
        for (int i=0; i<end-n; ++i) {
            int tx = (i % nx);
            int ty = ny-1-(i / nx);
            int fx = ((i+n) % nx);
            int fy = ny-1-((i+n) / nx);
            ch[tx][ty] = ch[fx][fy];
            fg[tx][ty] = fg[fx][fy];
            bg[tx][ty] = bg[fx][fy];
        }
        end -= n;
    }
}

class WindowManager {
private:
    Window[] windows;
    int nx, ny;
    char ch[][];
    int fg[][];
    int bg[][];
    char old_ch[][];
    int old_fg[][];
    int old_bg[][];
    bool dirty[][];
public:
    this(int inx, int iny) {
        nx = inx;
        ny = iny;
        ch = new char[][](nx, ny);
        fg = new int[][](nx, ny);
        bg = new int[][](nx, ny);
        old_ch = new char[][](nx, ny);
        old_fg = new int[][](nx, ny);
        old_bg = new int[][](nx, ny);
        dirty = new bool[][](nx, ny);
    }
    void add(Window w) {
        windows ~= w;
        resort();
    }
    void resort() {
        sort!((a,b) => a.z<b.z)(windows);
    }
    void remove(Window w) {
        for (int i=0; i<windows.length; ++i) {
            if (windows[i] == w) {
                windows[i..$-1] = windows[i+1..$];
                --windows.length;
            }
        }
    }
    void refresh(ref Terminal t) {
        foreach (w; windows) {
            for (int j=0; j<w.ny; ++j) {
                for (int i=0; i<w.nx; ++i) {
                    ch[i+w.x][j+w.y] = w.ch[i][j];
                    fg[i+w.x][j+w.y] = w.fg[i][j];
                    bg[i+w.x][j+w.y] = w.bg[i][j];
                }
            }
        }

        for (int i=0; i<nx; ++i)
            for (int j=0; j<ny; ++j)
                dirty[i][j] = (ch[i][j]!=old_ch[i][j]) || (fg[i][j]!=old_fg[i][j]) || (bg[i][j]!=old_bg[i][j]);

        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                if (dirty[i][j]) {
                    t.moveTo(i, ny-1-j);
                    t.color(fg[i][j], bg[i][j]);
                    t.write(ch[i][j]);
                }
            }
        }
        t.flush();

        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                old_ch[i][j] = ch[i][j];
                old_fg[i][j] = fg[i][j];
                old_bg[i][j] = bg[i][j];
            }
        }
    }
}


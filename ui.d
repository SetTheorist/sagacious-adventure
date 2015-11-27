module ui;

import std.algorithm;

import main : use_sdl;

static if (use_sdl) {
    import derelict.sdl2.sdl;
    //import derelict.sdl2.image;
    //import derelict.sdl2.mixer;
    //import derelict.sdl2.ttf;
    //import derelict.sdl2.net;
    enum Color {
        black, red, blue, yellow, green, white
    };
    immutable int Bright = 0x08;
} else {
    import terminal;
}

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
    int xend;
    this(int ix, int iy, int iz, int inx, int iny) {
        super(ix, iy, iz, inx, iny);
        xend = 0;
    }
    void append(string s, int ifg = Color.white, int ibg = Color.black) {
        if (xend + cast(int)s.length > nx*ny)
            scroll(xend + cast(int)s.length - nx*ny);
        foreach (c; s) {
            int tx = (xend % nx);
            int ty = ny-1-(xend / nx);
            ++xend;
            ch[tx][ty] = c;
            fg[tx][ty] = ifg;
            bg[tx][ty] = ibg;
        }
    }
    void scroll(int n) {
        for (int i=0; i<xend-n; ++i) {
            int tx = (i % nx);
            int ty = ny-1-(i / nx);
            int fx = ((i+n) % nx);
            int fy = ny-1-((i+n) / nx);
            ch[tx][ty] = ch[fx][fy];
            fg[tx][ty] = fg[fx][fy];
            bg[tx][ty] = bg[fx][fy];
        }
        xend -= n;
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
    static if (use_sdl) {
        void refresh(SDL_Window* window, SDL_Renderer* renderer, SDL_Texture* texture) {
            // layer sub-window data
            foreach (w; windows) {
                for (int j=0; j<w.ny; ++j) {
                    for (int i=0; i<w.nx; ++i) {
                        ch[i+w.x][j+w.y] = w.ch[i][j];
                        fg[i+w.x][j+w.y] = w.fg[i][j];
                        bg[i+w.x][j+w.y] = w.bg[i][j];
                    }
                }
            }
            // update
            SDL_SetRenderDrawColor(renderer, 0x8B, 0x7D, 0x7B, 0xFF);
            SDL_RenderClear(renderer);
            for (int i=0; i<nx; ++i) {
                for (int j=0; j<ny; ++j) {
                    SDL_Rect from_position = SDL_Rect((cast(uint)ch[i][ny-1-j]%16)*16, (cast(uint)ch[i][ny-1-j]/16)*16, 16, 16);
                    SDL_Rect to_position = SDL_Rect(i*16, j*16, 16, 16);
                    /* Blit the char onto the screen */
                    SDL_RenderCopy(renderer, texture, &from_position, &to_position);
                }
            }
            // show it
            SDL_RenderPresent(renderer);
        }
    } else {
        void refresh(ref Terminal t) {
            // layer sub-window data
            foreach (w; windows) {
                for (int j=0; j<w.ny; ++j) {
                    for (int i=0; i<w.nx; ++i) {
                        ch[i+w.x][j+w.y] = w.ch[i][j];
                        fg[i+w.x][j+w.y] = w.fg[i][j];
                        bg[i+w.x][j+w.y] = w.bg[i][j];
                    }
                }
            }
            // mark (changed) cells
            for (int i=0; i<nx; ++i)
                for (int j=0; j<ny; ++j)
                    dirty[i][j] = (ch[i][j]!=old_ch[i][j]) || (fg[i][j]!=old_fg[i][j]) || (bg[i][j]!=old_bg[i][j]);
            // update marked cells
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
            // update saved status
            for (int i=0; i<nx; ++i) {
                for (int j=0; j<ny; ++j) {
                    old_ch[i][j] = ch[i][j];
                    old_fg[i][j] = fg[i][j];
                    old_bg[i][j] = bg[i][j];
                }
            }
        }
    }
}


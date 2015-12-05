module ui;

import std.algorithm;

import derelict.sdl2.sdl;
//import derelict.sdl2.image;
//import derelict.sdl2.mixer;
//import derelict.sdl2.ttf;
//import derelict.sdl2.net;
enum Color {
    black=0x000000, red=0x7F0000, blue=0x00007F, yellow=0x7F7F00, green=0x007F00, white=0x7F7F7F
}
immutable int Bright = 0x808080;

class Window {
private:
    int _x, _y;
    int _nx, _ny;
    char ch[][];
    int fg[][];
    int bg[][];
public:
    int z;
    this(int ix, int iy, int iz, int inx, int iny) {
        _x = ix;
        _y = iy;
        z = iz;
        _nx = inx;
        _ny = iny;
        ch = new char[][](_nx, _ny);
        fg = new int[][](_nx, _ny);
        bg = new int[][](_nx, _ny);
    }
    void set(int ix, int iy, char ich, int ifg, int ibg) {
        if (ix>=0 && ix<_nx && iy>=0 && iy<_ny) {
            ch[ix][iy] = ich;
            fg[ix][iy] = ifg;
            bg[ix][iy] = ibg;
        }
    }
    void set(int ix, int iy, string s, int ifg, int ibg) {
        for (int i=0; i<s.length; ++i)
            set(ix+i, iy, s[i], ifg, ibg);
    }
    @property {
        int nx() const pure nothrow @nogc { return _nx; }
        int ny() const pure nothrow @nogc { return _ny; }
        int x() const pure nothrow @nogc { return _x; }
        int y() const pure nothrow @nogc { return _y; }
    }
}

class ConsoleWindow : Window {
    int xend;
    this(int ix, int iy, int iz, int inx, int iny) {
        super(ix, iy, iz, inx, iny);
        xend = 0;
    }
    void append(string s, int ifg = Color.white, int ibg = Color.black) {
        if (xend + cast(int)s.length > _nx*_ny)
            scroll(xend + cast(int)s.length - _nx*_ny);
        foreach (c; s) {
            int tx = (xend % _nx);
            int ty = _ny-1-(xend / _nx);
            ++xend;
            ch[tx][ty] = c;
            fg[tx][ty] = ifg;
            bg[tx][ty] = ibg;
        }
    }
    void scroll(int n) {
        for (int i=0; i<xend-n; ++i) {
            int tx = (i % _nx);
            int ty = _ny-1-(i / _nx);
            int fx = ((i+n) % _nx);
            int fy = _ny-1-((i+n) / _nx);
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
        //SDL_SetRenderDrawColor(renderer, 0x8B, 0x7D, 0x7B, 0xFF);
        SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
        SDL_RenderClear(renderer);
        uint t_format;
        int t_access, t_w, t_h;
        SDL_QueryTexture(texture, &t_format, &t_access, &t_w, &t_h);
        int chw = t_w/16;
        int chh = t_h/16;
        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                SDL_Rect from_position = SDL_Rect((cast(uint)ch[i][ny-1-j]%16)*chw, (cast(uint)ch[i][ny-1-j]/16)*chh, chw, chh);
                SDL_Rect to_position = SDL_Rect(i*chw, j*chh, chw, chh);
                SDL_SetRenderDrawColor(renderer,
                    (bg[i][ny-1-j]&0xFF0000)>>16,
                    (bg[i][ny-1-j]&0x00FF00)>>8,
                    (bg[i][ny-1-j]&0x0000FF),
                    0xFF);
                SDL_RenderFillRect(renderer, &to_position);
            }
        }

        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                SDL_Rect from_position = SDL_Rect((cast(uint)ch[i][ny-1-j]%16)*chw, (cast(uint)ch[i][ny-1-j]/16)*chh, chw, chh);
                SDL_Rect to_position = SDL_Rect(i*chw, j*chh, chw, chh);
                SDL_SetTextureColorMod(texture,
                    (fg[i][ny-1-j]&0xFF0000)>>16,
                    (fg[i][ny-1-j]&0x00FF00)>>8,
                    (fg[i][ny-1-j]&0x0000FF));
                SDL_RenderCopy(renderer, texture, &from_position, &to_position);
            }
        }
        SDL_SetTextureColorMod(texture, 0xFF, 0xFF, 0xFF);

/+
        // HACK TEST
        SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
        import rng : rng;
        import std.math : abs;
        static int kkk = 0;
        rng r = new rng((kkk++)/15);
        for (int i=0; i<nx; ++i) {
            for (int j=0; j<ny; ++j) {
                //real intensity = (((kkk/20+i)%13)/13.0 + ((kkk/20+j)%17)/17.0)*0.20;
                real intensity = r.uniform(1.00,0.90)*(1.0 - abs(nx/2 - i)/(nx/2.0))*(1.0 - abs(ny/2-j)/(ny/2.0))*0.50;
                SDL_Rect to_position = SDL_Rect(i*chw, j*chh, chw, chh);
                SDL_SetRenderDrawColor(renderer, 0x1F, 0x1F, 0xFF, 0xFF&(cast(uint)(intensity*0xFF)));
                SDL_RenderFillRect(renderer, &to_position);
            }
        }
+/

        // show it
        SDL_RenderPresent(renderer);
    }
}


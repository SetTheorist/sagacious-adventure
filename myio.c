#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>
#include <termios.h>
#include <unistd.h>

/* non-recursive, non-thread-safe... */
void* setup_ui_state()
{
    struct termios* old_ttystate = calloc(1, sizeof(*old_ttystate));;
    struct termios ttystate;
    // get current terminal state
    tcgetattr(STDIN_FILENO, old_ttystate);
    ttystate = *old_ttystate;
    // turn off canonical mode
    ttystate.c_lflag &= ~ICANON;
    // minimum of number input read
    ttystate.c_cc[VMIN] = 1;
    // turn off echo
    ttystate.c_lflag &= ~ECHO;
    // non-buffered output
    setvbuf(stdout, NULL, _IONBF, 0);
    tcsetattr(STDIN_FILENO, TCSANOW, &ttystate);
    return old_ttystate;
}
void restore_ui_state(void* old_state)
{
    tcsetattr(STDIN_FILENO, TCSANOW, (struct termios*)old_state);
    free(old_state);
}

int input_available()
{
    struct timeval tv;
    fd_set fds;
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    select(STDIN_FILENO+1, &fds, NULL, NULL, &tv);
    return FD_ISSET(0, &fds);
}

int read_char() {
    char buff[256];
    int nch = 0;
    while (input_available()) {
        nch = read(STDIN_FILENO, buff, sizeof(buff));
    }
    return nch ? buff[nch-1] : -1;
}


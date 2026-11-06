/* monolith-nothp: run a program with transparent huge pages disabled for it (and its children).
 * Same effect as the python3 one-liner in configs/.config/quickshell/scripts/start.sh, without python:
 * Quickshell measured ~164 MiB of anonymous memory at startup with THP "always" and ~71 MiB without.
 * A failing prctl (old kernel) is harmless: the program simply runs with the system THP setting. */
#include <stdio.h>
#include <sys/prctl.h>
#include <unistd.h>

#ifndef PR_SET_THP_DISABLE
#define PR_SET_THP_DISABLE 41
#endif

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: monolith-nothp <program> [arguments...]\n");
        return 2;
    }
    prctl(PR_SET_THP_DISABLE, 1, 0, 0, 0);
    execvp(argv[1], argv + 1);
    perror(argv[1]);
    return 127;
}

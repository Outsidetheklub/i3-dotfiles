/*
 * awake-toggle — keep the screen from blanking (or hand blanking back).
 *
 * Problem: on X11 there is no "inhibit" concept — the screen saver idle timer
 * and DPMS are server-wide. When you want to watch/read something without the
 * display going black at the 10-minute mark, you flip a switch; when you're
 * done you flip it back to normal AFK blanking.
 *
 * caffeine(-ng) is the usual answer, but it's a GTK/Python daemon (and an
 * extra package) whose whole job is to make these same X calls, so this setup
 * makes them directly instead — same "no daemon for a one-liner" rule the rest
 * of the desktop follows. See gamepad-idle-guard.c for the sibling that keeps
 * the screen awake during gamepad play:
 *
 *   target   -> save the current screen-saver + DPMS state, stop the X saver
 *               (timeout 0) and DPMS-disable the screen (waking it first if it
 *               has already gone dark).
 *   restore  -> put the saved values back and delete the state file.
 *
 * IMPORTANT: we stop DPMS by DISABLING it, not by zeroing its timeouts. The
 * gamepad guard treats "all DPMS timeouts are zero" as its own inhibit and
 * would restore its saved (600s) over the top of us — DPMSDisable leaves the
 * timeouts untouched, so the two never fight.
 *
 * State is a handful of integers under $XDG_RUNTIME_DIR, so a logout/reboot
 * (which wipes the runtime dir) can never leave blanking permanently off.
 *
 *   awake-toggle            toggle
 *   awake-toggle status     print current state, no change
 *
 * The bar indicator: i3status' `path_exists` can't expand "~" and the state
 * file lives in $XDG_RUNTIME_DIR, so we drop a symlink at
 * ~/.cache/awake-toggle/awake pointing AT the state file; i3status uses
 * `read_file` (which does expand "~") with format_bad="". The symlink is the
 * reason it also self-heals: once the session ends the runtime dir is wiped,
 * the link dangles, and the block hides itself instead of lying.
 *
 * Build (needs libX11/libXext headers, same as the gamepad guard):
 *   cc -O2 -o ~/.local/bin/awake-toggle src/awake-toggle.c -lX11 -lXext
 */

#include <X11/Xlib.h>
#include <X11/extensions/dpms.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>

#define STATE_NAME "awake-toggle.state"
#define NOTIFY_SECS 4

/* ── state file ─────────────────────────────────────────────────────────── */

static void state_path(char *buf, size_t n) {
    const char *dir = getenv("XDG_RUNTIME_DIR");
    if (!dir || !*dir) dir = "/tmp";
    snprintf(buf, n, "%s/" STATE_NAME, dir);
}

struct saved {
    int ss_timeout, ss_interval, ss_blank, ss_exposures;
    CARD16 d_st, d_su, d_off;
    int d_enabled;
};

static int state_read(const char *path, struct saved *s) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    int ok = fscanf(f, "%d %d %d %d %hu %hu %hu %d",
                    &s->ss_timeout, &s->ss_interval, &s->ss_blank,
                    &s->ss_exposures, &s->d_st, &s->d_su, &s->d_off,
                    &s->d_enabled) == 8;
    fclose(f);
    return ok;
}

static int state_write(const char *path, const struct saved *s) {
    FILE *f = fopen(path, "w");
    if (!f) return 0;
    fprintf(f, "%d %d %d %d %hu %hu %hu %d\n",
            s->ss_timeout, s->ss_interval, s->ss_blank, s->ss_exposures,
            s->d_st, s->d_su, s->d_off, s->d_enabled);
    fclose(f);
    return 1;
}

/* ── bar marker ─────────────────────────────────────────────────────────── */

/* Symlink the i3status bar watches: present+valid -> "AWAKE", dangling/absent
 * -> hidden. See the header note on why a symlink (self-healing on logout). */
static void marker_path(char *buf, size_t n) {
    const char *home = getenv("HOME");
    if (!home || !*home) { buf[0] = '\0'; return; }
    snprintf(buf, n, "%s/.cache/awake-toggle/awake", home);
}

static void marker_clear(void) {
    char m[512];
    marker_path(m, sizeof m);
    if (*m) unlink(m);
}

static void marker_set(const char *target) {
    char m[512];
    marker_path(m, sizeof m);
    if (!*m) return;
    char *slash = strrchr(m, '/');
    if (slash) {
        *slash = '\0';
        mkdir(m, 0755); /* one level under ~/.cache; EEXIST is fine */
        *slash = '/';
    }
    unlink(m); /* drop any stale link first, so symlink() can't fail with EEXIST */
    if (symlink(target, m) != 0)
        fprintf(stderr, "warning: could not create %s: %s\n", m, strerror(errno));
}

/* ── feedback ───────────────────────────────────────────────────────────── */

/* Toast via rofi -e, matching network-rofi.sh / bluetooth-rofi.sh (there is no
 * notification daemon on this box). AWAKE_NOTIFY=0 silences it. */
static void notify(const char *msg) {
    const char *on = getenv("AWAKE_NOTIFY");
    if (on && strcmp(on, "0") == 0) return;

    pid_t pid = fork();
    if (pid < 0) return;
    if (pid == 0) {
        char secs[8];
        snprintf(secs, sizeof secs, "%d", NOTIFY_SECS);
        setenv("AWAKE_NOTIFY", "0", 0); /* belt and braces: no recursion */
        execlp("timeout", "timeout", secs, "rofi", "-e", msg, (char *)NULL);
        _exit(127);
    }
    waitpid(pid, NULL, 0);
}

/* ── main ───────────────────────────────────────────────────────────────── */

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "status") == 0) {
        char path[512];
        struct saved s;
        state_path(path, sizeof path);
        if (state_read(path, &s))
            printf("blanking: off (screen stays awake)\n");
        else
            printf("blanking: normal\n");
        return 0;
    }

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "no display\n");
        return 1;
    }

    char path[512];
    state_path(path, sizeof path);
    struct saved s;
    int active = state_read(path, &s);

    if (active) {
        /* restore */
        XSetScreenSaver(dpy, s.ss_timeout, s.ss_interval,
                        s.ss_blank, s.ss_exposures);
        DPMSSetTimeouts(dpy, s.d_st, s.d_su, s.d_off);
        if (s.d_enabled) DPMSEnable(dpy); else DPMSDisable(dpy);
        XFlush(dpy);
        if (remove(path) != 0 && errno != ENOENT)
            fprintf(stderr, "warning: could not remove %s: %s\n",
                    path, strerror(errno));
        marker_clear();
        printf("blanking: normal (off after %ds)\n", s.d_off);
        notify("Screen blanking: NORMAL");
    } else {
        /* engage: save then zero */
        if (XGetScreenSaver(dpy, &s.ss_timeout, &s.ss_interval,
                            &s.ss_blank, &s.ss_exposures) == 0) {
            fprintf(stderr, "warning: could not read screen saver settings\n");
        }
        BOOL enabled = False; CARD16 level = 0;
        if (!DPMSInfo(dpy, &level, &enabled)) enabled = False;
        s.d_enabled = enabled ? 1 : 0;
        if (!DPMSGetTimeouts(dpy, &s.d_st, &s.d_su, &s.d_off)) {
            /* unknown: fall back to the X default of 600 and say so */
            s.d_st = s.d_su = s.d_off = 600;
            fprintf(stderr, "warning: could not read DPMS timeouts\n");
        }

        if (!state_write(path, &s)) {
            fprintf(stderr, "error: could not write %s: %s\n",
                    path, strerror(errno));
            XCloseDisplay(dpy);
            return 1;
        }
        marker_set(path);

        XSetScreenSaver(dpy, 0, s.ss_interval, s.ss_blank, s.ss_exposures);
        /* DPMSDisable, not timeouts=0 — see the header note: zeroing would be
         * clobbered by the gamepad guard. Wake first so a screen that has
         * already gone dark comes back immediately. */
        if (s.d_enabled) {
            DPMSForceLevel(dpy, DPMSModeOn); /* wake it if it already went dark */
            DPMSDisable(dpy);
        }
        XFlush(dpy);
        printf("blanking: off (screen stays awake)\n");
        notify("Screen blanking: OFF (stays awake)");
    }

    XCloseDisplay(dpy);
    return 0;
}

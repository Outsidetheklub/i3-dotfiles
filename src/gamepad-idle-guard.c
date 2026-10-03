/*
 * gamepad-idle-guard
 * Keep the display awake while a gamepad is in use, without losing normal
 * idle blanking for keyboard/mouse use.
 *
 * Problem: X11 only counts keyboard/mouse as activity. DPMS monitor
 * power-off timers (e.g. 600s) fire mid-game when playing with a
 * controller, because the kernel sees the gamepad but X does not.
 *
 * Solution: watch /dev/input/event* for gamepad devices (evdev, no root
 * needed if the user is in the `input` group). While gamepad events have
 * been seen recently:
 *   - DPMS timeouts are set to 0 (blanking disabled)
 *   - if the monitor is already off, force it back on (gamepad wakes it)
 * Once the gamepad has been quiet for a while AND the user is demonstrably
 * back on keyboard/mouse (X idle < 1 min), the original DPMS timeouts are
 * restored so normal AFK blanking resumes.
 *
 * Build:
 *   gcc -O2 -o gamepad-idle-guard gamepad-idle-guard.c -lX11 -lXss -lXext
 *
 * Run from i3 startup (inherits DISPLAY/XAUTHORITY). Singleton via flock.
 */
#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <X11/extensions/dpms.h>
#include <X11/extensions/scrnsaver.h>

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define INHIBIT_MS   120000UL  /* gamepad silence before blanking may return */
#define IDLE_GATE_MS  60000UL  /* require this much recent X activity to restore */
#define RESCAN_TICKS        3  /* rescan /dev/input every N ticks (1 s each) */
#define MAX_DEV             64

static Display *dpy;
static CARD16 save_st = 600, save_su = 600, save_off = 600;
static volatile sig_atomic_t running = 1;

struct dev {
    char path[64];
    int fd;
    int gamepad;
};
static struct dev devs[MAX_DEV];
static int ndev = 0;

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void logmsg(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stdout, fmt, ap);
    fputc('\n', stdout);
    fflush(stdout);
    va_end(ap);
}

static int test_bit(long bit, const unsigned char *a) {
    return (a[bit / 8] >> (bit % 8)) & 1;
}

static int ignore_xerr(Display *d, XErrorEvent *e) { (void)d; (void)e; return 0; }

static void on_signal(int sig) { (void)sig; running = 0; }

static int find_path(const char *path) {
    for (int i = 0; i < ndev; i++)
        if (!strcmp(devs[i].path, path)) return i;
    return -1;
}

static int classify_gamepad(int fd) {
    unsigned char keys[KEY_MAX / 8 + 1];
    memset(keys, 0, sizeof keys);
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof keys), keys) < 0) return 0;
    return test_bit(BTN_GAMEPAD, keys);
}

static void rescan(void) {
    DIR *d = opendir("/dev/input");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (strncmp(e->d_name, "event", 5) || !e->d_name[5]) continue;
        char path[64];
        snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
        if (find_path(path) >= 0) continue;
        if (ndev >= MAX_DEV) break;
        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        if (!classify_gamepad(fd)) { close(fd); continue; }
        char name[128] = {0};
        ioctl(fd, EVIOCGNAME(sizeof name - 1), name);
        strncpy(devs[ndev].path, path, sizeof devs[ndev].path - 1);
        devs[ndev].fd = fd;
        devs[ndev].gamepad = 1;
        logmsg("watching %s (%s)", path, name);
        ndev++;
    }
    closedir(d);
    for (int i = ndev - 1; i >= 0; i--) {
        if (access(devs[i].path, F_OK) != 0) {
            logmsg("lost %s", devs[i].path);
            close(devs[i].fd);
            devs[i] = devs[ndev - 1];
            ndev--;
        }
    }
}

static int dpms_level(void) {
    CARD16 level;
    BOOL on;
    if (!dpy || !DPMSInfo(dpy, &level, &on)) return -1;
    return (int)level;
}

static void dpms_set(CARD16 st, CARD16 su, CARD16 off) {
    if (!dpy) return;
    DPMSSetTimeouts(dpy, st, su, off);
    XFlush(dpy);
}

static void dpms_force_on(void) {
    if (!dpy) return;
    DPMSForceLevel(dpy, DPMSModeOn);
    XFlush(dpy);
}

static int dpms_all_zero(void) {
    CARD16 st, su, off;
    if (!DPMSGetTimeouts(dpy, &st, &su, &off)) return 0;
    return st == 0 && su == 0 && off == 0;
}

static unsigned long x_idle_ms(void) {
    if (!dpy) return 0;
    XScreenSaverInfo *info = XScreenSaverAllocInfo();
    if (!info) return 0;
    unsigned long idle = 0;
    if (XScreenSaverQueryInfo(dpy, DefaultRootWindow(dpy), info))
        idle = info->idle;
    XFree(info);
    return idle;
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    /* singleton */
    int lock_fd = open("/tmp/gamepad-idle-guard.lock", O_CREAT | O_RDWR, 0644);
    if (lock_fd >= 0 && flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
        fprintf(stderr, "another instance is running\n");
        return 0;
    }

    setvbuf(stdout, NULL, _IOLBF, 0);
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);
    signal(SIGHUP, SIG_IGN);
    XSetErrorHandler(ignore_xerr);

    dpy = XOpenDisplay(NULL);
    if (!dpy) {
        logmsg("no X display (DISPLAY=%s) - retrying in background", getenv("DISPLAY") ? getenv("DISPLAY") : "unset");
        for (int tries = 0; tries < 60 && running; tries++) {
            sleep(1);
            dpy = XOpenDisplay(NULL);
            if (dpy) break;
        }
        if (!dpy) { logmsg("giving up on X"); return 1; }
    }

    CARD16 st, su, off;
    if (DPMSGetTimeouts(dpy, &st, &su, &off) && !(st == 0 && su == 0 && off == 0)) {
        save_st = st; save_su = su; save_off = off;
    } else {
        /* all-zero (someone disabled blanking, e.g. a crashed instance left
         * timeouts at 0) — fall back to the X server defaults */
        save_st = 600; save_su = 600; save_off = 600;
    }
    logmsg("started pid=%d, saved dpms timeouts standby=%ds suspend=%ds off=%ds",
           getpid(), save_st, save_su, save_off);

    rescan();
    long long last_gamepad = 0;
    long long last_status = 0;
    int tick = 0;

    while (running) {
        if (++tick >= RESCAN_TICKS) {
            rescan();
            tick = 0;
        }

        /* wait for input events, 1 s tick */
        fd_set rfds;
        FD_ZERO(&rfds);
        int maxfd = -1;
        for (int i = 0; i < ndev; i++) {
            if (devs[i].fd < 0) continue;
            FD_SET(devs[i].fd, &rfds);
            if (devs[i].fd > maxfd) maxfd = devs[i].fd;
        }
        struct timeval tv = { .tv_sec = 1, .tv_usec = 0 };
        int sel = select(maxfd + 1, &rfds, NULL, NULL, &tv);
        if (sel > 0) {
            for (int i = 0; i < ndev; i++) {
                int fd = devs[i].fd;
                if (fd < 0 || !FD_ISSET(fd, &rfds)) continue;
                char buf[sizeof(struct input_event) * 32];
                ssize_t n;
                while ((n = read(fd, buf, sizeof buf)) > 0) {
                    int cnt = (int)(n / (ssize_t)sizeof(struct input_event));
                    struct input_event *e = (struct input_event *)buf;
                    for (int k = 0; k < cnt; k++, e++) {
                        if (e->type == EV_SYN || e->type == EV_MSC) continue;
                        last_gamepad = now_ms();
                        int level = dpms_level();
                        if (level > DPMSModeOn) {
                            logmsg("wake: gamepad input while dpms level=%d", level);
                            dpms_force_on();
                        }
                    }
                }
                if (n < 0 && errno != EAGAIN && errno != EINTR) {
                    close(fd);
                    devs[i].fd = -1;
                }
            }
        }

        /* state machine */
        long long now = now_ms();
        int recently = last_gamepad != 0 && (now - last_gamepad) < INHIBIT_MS;

        if (now - last_status >= 60000) {
            CARD16 t_st, t_su, t_off;
            unsigned long idle = x_idle_ms();
            if (!DPMSGetTimeouts(dpy, &t_st, &t_su, &t_off)) { t_st = t_su = t_off = 0xffff; }
            logmsg("status: recently=%d last_gp=%llds ago dpms=%d/%d/%d idle=%lums",
                   recently, last_gamepad ? (now - last_gamepad) / 1000 : -1,
                   t_st, t_su, t_off, idle);
            last_status = now;
        }

        if (recently) {
            if (!dpms_all_zero()) {
                dpms_set(0, 0, 0);
                logmsg("inhibit: gamepad active, blanking disabled");
            }
            int level = dpms_level();
            if (level > DPMSModeOn) {
                logmsg("wake: screen was off (level=%d) with gamepad in use", level);
                dpms_force_on();
            }
        } else {
            if (dpms_all_zero()) {
                unsigned long idle = x_idle_ms();
                if (idle < IDLE_GATE_MS) {
                    dpms_set(save_st, save_su, save_off);
                    logmsg("restore: back on keyboard/mouse, blanking re-enabled (%ds)", save_off);
                }
            }
        }
    }

    dpms_set(save_st, save_su, save_off);
    logmsg("exiting, dpms timeouts restored (%ds)", save_off);
    if (dpy) XCloseDisplay(dpy);
    return 0;
}

/*
 * zenbook-sendkey — Emite una tecla estándar vía uinput
 * Uso: zenbook-sendkey <código_linux>
 * Ej.: zenbook-sendkey 63   (KEY_F5)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>

static void die(const char *msg) {
    perror(msg);
    exit(1);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "uso: %s <código de tecla linux>\n", argv[0]);
        return 1;
    }
    int code = atoi(argv[1]);
    if (code < 1 || code > 248) {
        fprintf(stderr, "código fuera de rango: %d\n", code);
        return 1;
    }

    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) die("/dev/uinput");

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);
    for (int k = 1; k <= 248; k++)
        ioctl(fd, UI_SET_KEYBIT, k);

    struct uinput_setup us;
    memset(&us, 0, sizeof(us));
    strncpy(us.name, "zenbook-virtual-fkeys", UINPUT_MAX_NAME_SIZE - 1);
    us.id.bustype = BUS_USB;
    us.id.vendor  = 0x1234;
    us.id.product = 0x5678;
    us.id.version = 1;

    if (ioctl(fd, UI_DEV_SETUP, &us) < 0) die("UI_DEV_SETUP");
    if (ioctl(fd, UI_DEV_CREATE) < 0)    die("UI_DEV_CREATE");
    /* retardo seguro para que Mutter/libinput registre el dispositivo */
    usleep(500000);   /* dejar que X/Wayland registre el dispositivo */

    struct input_event ev;
    struct timeval tv;

    /* press */
    gettimeofday(&tv, NULL);
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY; ev.code = code; ev.value = 1;
    ssize_t w1 = write(fd, &ev, sizeof(ev)); if (w1 < 0) die("write press");

    gettimeofday(&tv, NULL);
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN; ev.code = SYN_REPORT; ev.value = 0;
    if (write(fd, &ev, sizeof(ev)) < 0) {}

    usleep(60000);    /* 60ms presionada */

    /* release */
    gettimeofday(&tv, NULL);
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY; ev.code = code; ev.value = 0;
    if (write(fd, &ev, sizeof(ev)) < 0) {}

    gettimeofday(&tv, NULL);
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN; ev.code = SYN_REPORT; ev.value = 0;
    if (write(fd, &ev, sizeof(ev)) < 0) {}

    ioctl(fd, UI_DEV_DESTROY);
    close(fd);
    return 0;
}

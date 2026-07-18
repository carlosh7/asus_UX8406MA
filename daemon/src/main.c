/*
 * Zenbook Duo Linux - Hardware Daemon
 * Monitors keyboard USB connection and auto-toggles displays
 * Optimized: direct sysfs reads, no popen/system calls
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <dirent.h>
#include <time.h>
#include <errno.h>
#include <stdarg.h>

#define CONF_PATH "/etc/zenbook-duo/zenbook-duo.conf"
#define KB_VENDOR "0b05"
#define KB_PRODUCT "1b2c"
#define USB_DEVICES_PATH "/sys/bus/usb/devices"

typedef struct {
    int auto_display;
    int auto_brightness;
    int auto_bluetooth;
    int battery_limit;
    char brightness_main[256];
    char brightness_bottom[256];
    int poll_interval;
} Config;

static volatile int running = 1;

void signal_handler(int sig) {
    (void)sig;
    running = 0;
}

/* Log to stderr (captured by systemd journal) */
void log_msg(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    time_t now = time(NULL);
    char timebuf[64];
    strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S", localtime(&now));
    fprintf(stderr, "[%s] ", timebuf);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
}

/* Check if keyboard is attached via USB by reading sysfs */
int keyboard_attached_usb() {
    DIR *dir = opendir(USB_DEVICES_PATH);
    if (!dir) return -1;
    
    struct dirent *entry;
    int found = 0;
    
    while ((entry = readdir(dir)) != NULL) {
        /* Skip . and .. and interfaces (contain ':') */
        if (entry->d_name[0] == '.' || strchr(entry->d_name, ':') != NULL)
            continue;
        
        /* Check if this is a USB device directory */
        char vendor_path[512];
        char product_path[512];
        snprintf(vendor_path, sizeof(vendor_path), "%s/%s/idVendor", USB_DEVICES_PATH, entry->d_name);
        snprintf(product_path, sizeof(product_path), "%s/%s/idProduct", USB_DEVICES_PATH, entry->d_name);
        
        FILE *fv = fopen(vendor_path, "r");
        if (!fv) continue;
        
        char vendor[16] = {0};
        fgets(vendor, sizeof(vendor), fv);
        fclose(fv);
        
        /* Remove newline */
        vendor[strcspn(vendor, "\n")] = 0;
        
        if (strcmp(vendor, KB_VENDOR) != 0) continue;
        
        FILE *fp = fopen(product_path, "r");
        if (!fp) continue;
        
        char product[16] = {0};
        fgets(product, sizeof(product), fp);
        fclose(fp);
        
        product[strcspn(product, "\n")] = 0;
        
        if (strcmp(product, KB_PRODUCT) == 0) {
            found = 1;
            break;
        }
    }
    
    closedir(dir);
    return found;
}

/* Write value to sysfs file */
int sysfs_write(const char *path, const char *value) {
    FILE *fp = fopen(path, "w");
    if (!fp) return -1;
    int ret = fprintf(fp, "%s", value);
    fclose(fp);
    return (ret > 0) ? 0 : -1;
}

/* Read value from sysfs file */
int sysfs_read(const char *path, char *buf, size_t len) {
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;
    if (fgets(buf, len, fp) == NULL) {
        fclose(fp);
        return -1;
    }
    fclose(fp);
    buf[strcspn(buf, "\n")] = 0;
    return 0;
}

/* Execute command (for display management - uses exec) */
void exec_cmd(const char *cmd, const char *arg1) {
    pid_t pid = fork();
    if (pid == 0) {
        /* Child process - set DISPLAY for X11 */
        setenv("DISPLAY", ":1", 1);
        setenv("XAUTHORITY", "/run/user/1000/Xauthority", 1);
        /* Child process */
        if (arg1) {
            execlp(cmd, cmd, arg1, (char *)NULL);
        } else {
            execlp(cmd, cmd, (char *)NULL);
        }
        _exit(127);
    } else if (pid > 0) {
        /* Parent: wait briefly, then continue */
        int status;
        waitpid(pid, &status, WNOHANG);
    }
}

void set_display_both() {
    exec_cmd("duo", "both");
    usleep(500000);  // Wait 500ms for display to switch
    exec_cmd("setup-touch-x11.sh", NULL);  // Apply touch mapping
}

void set_display_top() {
    exec_cmd("duo", "top");
    usleep(500000);  // Wait 500ms for display to switch
    exec_cmd("setup-touch-x11.sh", NULL);  // Apply touch mapping
}

void sync_brightness(const Config *cfg) {
    char main_val[32] = {0};
    if (sysfs_read(cfg->brightness_main, main_val, sizeof(main_val)) == 0) {
        sysfs_write(cfg->brightness_bottom, main_val);
    }
}

void toggle_bluetooth(int enable) {
    if (enable) {
        exec_cmd("rfkill", "unblock");
    } else {
        exec_cmd("rfkill", "block");
    }
}

void load_config(Config *cfg) {
    memset(cfg, 0, sizeof(Config));
    cfg->auto_display = 1;
    cfg->auto_brightness = 1;
    cfg->auto_bluetooth = 1;
    cfg->battery_limit = 80;
    cfg->poll_interval = 2;
    strcpy(cfg->brightness_main, "/sys/class/backlight/intel_backlight/brightness");
    strcpy(cfg->brightness_bottom, "/sys/class/backlight/card1-eDP-2-backlight/brightness");
    
    FILE *fp = fopen(CONF_PATH, "r");
    if (!fp) {
        log_msg("Config file not found, using defaults");
        return;
    }
    
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        char key[64], val[128];
        if (sscanf(line, "%63[^=]=%127s", key, val) == 2) {
            if (strcmp(key, "auto_display") == 0) cfg->auto_display = atoi(val);
            else if (strcmp(key, "auto_brightness") == 0) cfg->auto_brightness = atoi(val);
            else if (strcmp(key, "auto_bluetooth") == 0) cfg->auto_bluetooth = atoi(val);
            else if (strcmp(key, "battery_limit") == 0) cfg->battery_limit = atoi(val);
            else if (strcmp(key, "brightness_main") == 0) strncpy(cfg->brightness_main, val, sizeof(cfg->brightness_main)-1);
            else if (strcmp(key, "brightness_bottom") == 0) strncpy(cfg->brightness_bottom, val, sizeof(cfg->brightness_bottom)-1);
            else if (strcmp(key, "poll_interval") == 0) cfg->poll_interval = atoi(val);
        }
    }
    fclose(fp);
    
    log_msg("Config loaded: auto_display=%d, auto_brightness=%d, poll=%ds",
            cfg->auto_display, cfg->auto_brightness, cfg->poll_interval);
}

void print_usage(const char *prog) {
    printf("Usage: %s <command>\n", prog);
    printf("Commands:\n");
    printf("  daemon        - Run as daemon (background monitor)\n");
    printf("  status        - Show current keyboard/display status\n");
    printf("  display-both  - Enable both displays\n");
    printf("  display-top   - Enable only top display\n");
    printf("  brightness    - Sync brightness\n");
    printf("  battery N     - Set battery limit to N%%\n");
    printf("  help          - Show this help\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }
    
    Config cfg;
    load_config(&cfg);
    
    if (strcmp(argv[1], "daemon") == 0) {
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        
        log_msg("Zenbook Duo Daemon started");
        log_msg("Settings: auto_display=%d, auto_brightness=%d, auto_bluetooth=%d",
                cfg.auto_display, cfg.auto_brightness, cfg.auto_bluetooth);
        
        int last_kb_state = -1;
        
        while (running) {
            int kb_usb = keyboard_attached_usb();
            int kb_attached = (kb_usb > 0);
            
            if (last_kb_state != kb_attached) {
                last_kb_state = kb_attached;
                
                if (kb_attached) {
                    log_msg("Keyboard attached - switching to top display");
                    set_display_top();
                } else {
                    log_msg("Keyboard detached - switching to both displays");
                    set_display_both();
                }
                
                if (cfg.auto_brightness) {
                    sync_brightness(&cfg);
                }
            }
            
            sleep(cfg.poll_interval);
        }
        
        log_msg("Daemon stopped");
    }
    else if (strcmp(argv[1], "status") == 0) {
        int kb_usb = keyboard_attached_usb();
        printf("Keyboard USB: %s\n", kb_usb ? "Attached" : "Not found");
    }
    else if (strcmp(argv[1], "display-both") == 0) {
        set_display_both();
    }
    else if (strcmp(argv[1], "display-top") == 0) {
        set_display_top();
    }
    else if (strcmp(argv[1], "brightness") == 0) {
        sync_brightness(&cfg);
    }
    else if (strcmp(argv[1], "battery") == 0) {
        if (argc > 2) {
            char path[256];
            snprintf(path, sizeof(path), "/sys/class/power_supply/BAT0/charge_control_end_threshold");
            char val[16];
            snprintf(val, sizeof(val), "%d", atoi(argv[2]));
            if (sysfs_write(path, val) == 0) {
                log_msg("Battery limit set to %d%%", atoi(argv[2]));
            } else {
                log_msg("Failed to set battery limit");
            }
        } else {
            printf("Battery limit: %d%%\n", cfg.battery_limit);
        }
    }
    else if (strcmp(argv[1], "help") == 0) {
        print_usage(argv[0]);
    }
    else {
        fprintf(stderr, "Unknown command: %s\n", argv[1]);
        print_usage(argv[0]);
        return 1;
    }
    
    return 0;
}

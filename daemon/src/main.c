#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>

#define CONF_PATH "/etc/zenbook-duo/zenbook-duo.conf"
#define KB_VENDOR 0x0b05
#define KB_PRODUCT 0x1b2c

typedef struct {
    int auto_display;
    int auto_brightness;
    int auto_bluetooth;
    int battery_limit;
    char brightness_main[256];
    char brightness_bottom[256];
} Config;

static volatile int running = 1;

void signal_handler(int sig) {
    running = 0;
}

int keyboard_attached_usb() {
    DIR *dir = opendir("/dev/bus/usb");
    if (!dir) return -1;
    
    char line[256];
    FILE *fp = popen("lsusb 2>/dev/null", "r");
    if (!fp) {
        closedir(dir);
        return -1;
    }
    
    int found = 0;
    while (fgets(line, sizeof(line), fp)) {
        if (strstr(line, "0b05") && strstr(line, "1b2c")) {
            found = 1;
            break;
        }
    }
    pclose(fp);
    closedir(dir);
    return found;
}

int keyboard_attached_bt() {
    FILE *fp = popen("bluetoothctl devices 2>/dev/null | grep -i 'keyboard' || echo ''", "r");
    if (!fp) return 0;
    
    char line[256];
    int has_bt_kb = 0;
    if (fgets(line, sizeof(line), fp)) {
        if (strlen(line) > 5) has_bt_kb = 1;
    }
    pclose(fp);
    return has_bt_kb;
}

void set_display_both() {
    system("duo both 2>/dev/null");
}

void set_display_top() {
    system("duo top 2>/dev/null");
}

void sync_brightness() {
    system("duo sync-backlight 2>/dev/null");
}

void toggle_bluetooth(int enable) {
    if (enable) {
        system("rfkill unblock bluetooth 2>/dev/null");
    } else {
        system("rfkill block bluetooth 2>/dev/null");
    }
}

void set_battery_limit(int limit) {
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "echo %d | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null 2>&1", limit);
    system(cmd);
}

void load_config(Config *cfg) {
    memset(cfg, 0, sizeof(Config));
    cfg->auto_display = 1;
    cfg->auto_brightness = 1;
    cfg->auto_bluetooth = 1;
    cfg->battery_limit = 80;
    strcpy(cfg->brightness_main, "/sys/class/backlight/intel_backlight/brightness");
    strcpy(cfg->brightness_bottom, "/sys/class/backlight/card1-eDP-2-backlight/brightness");
    
    FILE *fp = fopen(CONF_PATH, "r");
    if (!fp) return;
    
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        char key[64], val[128];
        if (sscanf(line, "%63[^=]=%127s", key, val) == 2) {
            if (strcmp(key, "auto_display") == 0) cfg->auto_display = atoi(val);
            else if (strcmp(key, "auto_brightness") == 0) cfg->auto_brightness = atoi(val);
            else if (strcmp(key, "auto_bluetooth") == 0) cfg->auto_bluetooth = atoi(val);
            else if (strcmp(key, "battery_limit") == 0) cfg->battery_limit = atoi(val);
        }
    }
    fclose(fp);
}

void print_usage(const char *prog) {
    printf("Usage: %s <command>\n", prog);
    printf("Commands:\n");
    printf("  daemon        - Run as daemon (background monitor)\n");
    printf("  status        - Show current keyboard/display status\n");
    printf("  display-both - Enable both displays\n");
    printf("  display-top  - Enable only top display\n");
    printf("  brightness   - Sync brightness\n");
    printf("  battery N    - Set battery limit to N%%\n");
    printf("  help         - Show this help\n");
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
        
        printf("Zenbook Duo Daemon started...\n");
        printf("auto_display=%d, auto_brightness=%d, auto_bluetooth=%d\n",
               cfg.auto_display, cfg.auto_brightness, cfg.auto_bluetooth);
        
        int last_kb_state = -1;
        
        while (running) {
            int kb_usb = keyboard_attached_usb();
            // We ignore Bluetooth for display switching because the keyboard 
            // stays connected via BT when detached from the screen.
            int kb_attached = (kb_usb > 0);
            
            if (last_kb_state != kb_attached) {
                last_kb_state = kb_attached;
                
                if (kb_attached) {
                    printf("[%ld] Keyboard attached - enabling top display only\n", (long)time(NULL));
                    set_display_top();
                } else {
                    printf("[%ld] Keyboard detached - enabling both displays\n", (long)time(NULL));
                    set_display_both();
                }
                
                if (cfg.auto_brightness) {
                    sync_brightness();
                }
            }
            
            sleep(2);
        }
        
        printf("Daemon stopped.\n");
    }
    else if (strcmp(argv[1], "status") == 0) {
        int kb_usb = keyboard_attached_usb();
        int kb_bt = keyboard_attached_bt();
        printf("Keyboard USB: %s\n", kb_usb ? "Attached" : "Not found");
        printf("Keyboard BT: %s\n", kb_bt ? "Paired" : "Not found");
    }
    else if (strcmp(argv[1], "display-both") == 0) {
        set_display_both();
    }
    else if (strcmp(argv[1], "display-top") == 0) {
        set_display_top();
    }
    else if (strcmp(argv[1], "brightness") == 0) {
        sync_brightness();
    }
    else if (strcmp(argv[1], "battery") == 0) {
        if (argc > 2) {
            set_battery_limit(atoi(argv[2]));
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
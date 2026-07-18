#!/bin/bash
# Setup GNOME hotkeys for F1-F12 (multimedia keys)
# Works in both USB and Bluetooth modes

echo "Configuring GNOME media keys..."

# Clear old Super mappings first
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-down "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-up "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys mic-mute "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys help "['']"

# Set new F* mappings (no Super needed)
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['F1']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['F2']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['F3']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-down "['F5']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-up "['F6']"
gsettings set org.gnome.settings-daemon.plugins.media-keys mic-mute "['F9']"

# Custom keybindings
echo "Configuring custom keybindings..."

BIND_PATH="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
BASE_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

# Helper to set custom binding
set_custom_binding() {
    local id="$1"
    local name="$2"
    local command="$3"
    local binding="$4"
    
    local path="$BASE_PATH/$id/"
    gsettings set "$BIND_PATH:$path" name "$name"
    gsettings set "$BIND_PATH:$path" command "$command"
    gsettings set "$BIND_PATH:$path" binding "$binding"
}

# List of custom bindings (F* without Super)
set_custom_binding "custom0" "Teclado-Luz" "/usr/local/bin/kb-light-cycle.sh" "F4"
set_custom_binding "custom1" "Duo-Toggle" "/usr/local/bin/duo toggle" "F7"
set_custom_binding "custom2" "Bluetooth-Toggle" "/usr/local/bin/toggle-bluetooth.sh" "F10"

# Register the custom bindings
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$BASE_PATH/custom0/', '$BASE_PATH/custom1/', '$BASE_PATH/custom2/']"

echo "Done! Test your F1-F12 keys now."
echo ""
echo "Multimedia keys:"
echo "  F1: Volume Mute"
echo "  F2: Volume Down"
echo "  F3: Volume Up"
echo "  F4: Keyboard Backlight"
echo "  F5: Brightness Down"
echo "  F6: Brightness Up"
echo "  F7: Toggle Display"
echo "  F9: Mic Mute"
echo "  F10: Toggle Bluetooth"

#!/bin/bash
# Setup GNOME hotkeys for Alt + F1-F12

echo "Configuring GNOME media keys..."

# Clear old Alt mappings first
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-down "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-up "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys mic-mute "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys help "['']"


# Set new Super mappings
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['<Super>F1']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['<Super>F2']"
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['<Super>F3']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-down "['<Super>F5']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screen-brightness-up "['<Super>F6']"
gsettings set org.gnome.settings-daemon.plugins.media-keys mic-mute "['<Super>F9']"

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

# List of custom bindings
set_custom_binding "custom0" "Teclado-Luz" "/usr/local/bin/kb-light-cycle.sh" "<Super>F4"
set_custom_binding "custom1" "Duo-Toggle" "/usr/local/bin/duo toggle" "<Super>F7"
set_custom_binding "custom2" "Bluetooth-Toggle" "/usr/local/bin/toggle-bluetooth.sh" "<Super>F10"


# Register the custom bindings
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$BASE_PATH/custom0/', '$BASE_PATH/custom1/', '$BASE_PATH/custom2/']"

# Set Fn-Lock to 1 (F1-F12 primary) via USB if keyboard attached
echo "Setting keyboard hardware to Function Mode (F1-F12 primary)..."
sudo /usr/local/bin/fn-lock.py 1 2>/dev/null || echo "Note: Could not set Fn-Lock (is keyboard attached via USB?)"

echo "Done! Test your Super + F1-F12 keys now."

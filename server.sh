#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  dialog --msgbox "Please run as root." 6 40
  exit 1
fi

# Get local IP address (prefer wlan0 or eth0)
LOCAL_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
if [ -z "$LOCAL_IP" ]; then
  dialog --msgbox "Could not determine local IP address." 6 50
  exit 1
fi

# Load required kernel modules
modprobe usbip_core
modprobe usbip_host

# Find Steam Controller USB device
STEAM_BUSID=$(usbip list -l | grep -B 1 "28de:" | grep "busid" | awk '{print $3}')

if [ -z "$STEAM_BUSID" ]; then
  dialog --msgbox "Steam Controller not found." 6 40
  exit 1
fi

dialog --infobox "Steam Controller found successfully." 5 40
sleep 1

# Bind the Steam Controller to usbip
dialog --infobox "Binding Steam Controller..." 5 40
usbip bind -b "$STEAM_BUSID"

# Start usbip daemon if not already running
if ! pgrep usbipd > /dev/null; then
  dialog --infobox "Starting usbipd..." 5 40
  usbipd -D
fi

# Show connection information
dialog --msgbox "Server ready!

Steam Deck IP: $LOCAL_IP

On your client machine, run:
  sudo usbip list -r $LOCAL_IP
Then connect with:
  sudo usbip attach -r $LOCAL_IP -b $STEAM_BUSID" 15 70

# Brightness control setup
BRIGHTNESS_PATH="/sys/class/backlight/amdgpu_bl0/brightness"
MAX_BRIGHTNESS=$(cat /sys/class/backlight/amdgpu_bl0/max_brightness 2>/dev/null)
DEFAULT_BRIGHTNESS=$(cat "$BRIGHTNESS_PATH" 2>/dev/null)
MIN_BRIGHTNESS=0

# Immediately clear screen and set minimal brightness
clear
setterm --cursor off
if [ -w "$BRIGHTNESS_PATH" ]; then
  echo "$MIN_BRIGHTNESS" | tee "$BRIGHTNESS_PATH" >/dev/null
fi
# Cleanup function
cleanup() {
  dialog --title "Exit Confirmation" --yesno "Are you sure you want to exit?" 7 40
  if [ $? -ne 0 ]; then
    dialog --msgbox "Continuing..." 5 30
    return
  fi

  dialog --infobox "Unbinding USB device..." 5 40
  usbip unbind -b "$STEAM_BUSID" 2>/dev/null
  sleep 1

  dialog --infobox "Stopping usbipd..." 5 40
  killall usbipd 2>/dev/null
  sleep 1

  # Restore brightness
  if [ -n "$DEFAULT_BRIGHTNESS" ] && [ -w "$BRIGHTNESS_PATH" ]; then
    echo "$DEFAULT_BRIGHTNESS" | tee "$BRIGHTNESS_PATH" >/dev/null
  fi

  clear
  setterm --cursor on
trap cleanup SIGINT SIGTERM SIGHUP
  
  exit 0
}

# Trap signals for cleanup
trap cleanup SIGINT SIGTERM SIGHUP EXIT

# Exit confirmation dialog
# (Moved to cleanup function)

# Main loop: wait for a stop signal from client
while true; do
  if [ -f /tmp/stop_usbip_server ]; then
    dialog --infobox "Stop signal received from client." 5 50
    rm -f /tmp/stop_usbip_server
    cleanup
  fi
  sleep 1
done
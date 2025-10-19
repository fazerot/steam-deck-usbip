#!/bin/bash

#auto-update path so sudo access to dialogrc works
DIALOGRC="$HOME/steam-deck-usbip/dialogrc"

DIALOG_HEIGHT=20
DIALOG_WIDTH=100

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  DIALOGRC=$DIALOGRC dialog --msgbox "Please run as root." $DIALOG_HEIGHT $DIALOG_WIDTH
  exit 1
fi

# Get local IP address (prefer wlan0 or eth0)
LOCAL_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
if [ -z "$LOCAL_IP" ]; then
  DIALOGRC=$DIALOGRC dialog --msgbox "Could not determine local IP address." $DIALOG_HEIGHT $DIALOG_WIDTH
  exit 1
fi

# Load required kernel modules
modprobe usbip_core
modprobe usbip_host

# Find Steam Controller USB device
STEAM_BUSID=$(usbip list -l | grep -B 1 "28de:" | grep "busid" | awk '{print $3}')

if [ -z "$STEAM_BUSID" ]; then
  DIALOGRC=$DIALOGRC dialog --msgbox "Steam Controller not found." $DIALOG_HEIGHT $DIALOG_WIDTH
  exit 1
fi

DIALOGRC=$DIALOGRC dialog --infobox "Steam Controller found successfully." $DIALOG_HEIGHT $DIALOG_WIDTH
sleep 1

# Bind the Steam Controller to usbip
DIALOGRC=$DIALOGRC dialog --infobox "Binding Steam Controller..." $DIALOG_HEIGHT $DIALOG_WIDTH
usbip bind -b "$STEAM_BUSID"

# Start usbip daemon if not already running
if ! pgrep usbipd > /dev/null; then
  DIALOGRC=$DIALOGRC dialog --infobox "Starting usbipd..." $DIALOG_HEIGHT $DIALOG_WIDTH
  usbipd -D
fi

# Show connection information
DIALOGRC=$DIALOGRC dialog --msgbox "Server ready!

Steam Deck IP: $LOCAL_IP

On your client machine, run:
  sudo usbip list -r $LOCAL_IP
Then connect with:
  sudo usbip attach -r $LOCAL_IP -b $STEAM_BUSID" $DIALOG_HEIGHT $DIALOG_WIDTH

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
  DIALOGRC=$DIALOGRC dialog --infobox "Unbinding USB device..." $DIALOG_HEIGHT $DIALOG_WIDTH
  usbip unbind -b "$STEAM_BUSID" 2>/dev/null
  sleep 1

  DIALOGRC=$DIALOGRC dialog --infobox "Stopping usbipd..." $DIALOG_HEIGHT $DIALOG_WIDTH
  killall usbipd 2>/dev/null
  sleep 1

  # Restore brightness
  if [ -n "$DEFAULT_BRIGHTNESS" ] && [ -w "$BRIGHTNESS_PATH" ]; then
    echo "$DEFAULT_BRIGHTNESS" | tee "$BRIGHTNESS_PATH" >/dev/null
  fi

  clear
  setterm --cursor on
  DIALOGRC=$DIALOGRC dialog --msgbox "Server stopped. Exiting." $DIALOG_HEIGHT $DIALOG_WIDTH
  
  exit 0
}

# Trap signals for cleanup
trap cleanup SIGINT SIGTERM SIGHUP EXIT

# Exit confirmation dialog
while true; do
  DIALOGRC=$DIALOGRC dialog --title "Exit Confirmation" --yesno "Are you sure you want to exit?" $DIALOG_HEIGHT $DIALOG_WIDTH
  rc=$?
  if [ "$rc" -eq 0 ]; then
    cleanup
  else
    # Show "Continuing..." for 10 seconds then return to confirmation
    DIALOGRC=$DIALOGRC dialog --timeout 10 --msgbox "Continuing..." $DIALOG_HEIGHT $DIALOG_WIDTH
  fi
done

# Main loop: wait for a stop signal from client
while true; do
  if [ -f /tmp/stop_usbip_server ]; then
    DIALOGRC=$DIALOGRC dialog --infobox "Stop signal received from client." $DIALOG_HEIGHT $DIALOG_WIDTH
    rm -f /tmp/stop_usbip_server
    cleanup
  fi
  sleep 1
done
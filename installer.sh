#!/bin/bash

echo ""
echo "Steam Deck USBIP Installation Script"
echo "==================================="
echo ""
echo "It is recommended to begin installation on the Steam Deck by running this script in Desktop Mode *first*."
read -p "Is this the Steam Deck (server) or client device? (s/c): " device_type
if [ "$device_type" = "s" ]; then
    
    echo ""
    echo "Setting up Steam Deck (server)..."
    echo "==================================="
    echo ""

    # Optional password setup
    echo ""
    read -p "Do you want to set up a password for the deck user? (y/N): " setup_password
    echo "==================================="
    echo ""
        if [ "$setup_password" = "y" ]; then
            echo "Setting up deck user password..."
            echo "==================================="
            echo ""
            sudo passwd deck
        fi

    # Check if developer mode is enabled
    echo ""
    echo "Checking if the developer mode is enabled..."
    echo "==================================="
    echo ""
        DEV_MODE_STATUS=$(sudo steamos-devmode status 2>/dev/null | grep -i enabled)
            if [ "$DEV_MODE_STATUS" = "enabled" ]; then
                echo "Developer mode is already enabled. Skipping..."
            else
                echo "Enabling Steam Deck developer mode..."
                sudo steamos-devmode enable
            fi

    # Install required packages
     echo ""
     echo "Installing required packages..."
     echo "==================================="
     echo ""
     sudo pacman -S --noconfirm usbip git dialog

    # Automate: clone repos to $HOME, register SteamTinkerLaunch and add server.sh as a Non‑Steam game
    # Ensure server script is executable
        chmod +x "$HOME/steam-deck-usbip/server.sh"

    # Install SteamTinkerLaunch
    echo "Installing SteamTinkerLaunch..."
     git clone https://github.com/sonic2kk/steamtinkerlaunch.git
        cd "$HOME/steamtinkerlaunch"
        chmod +x steamtinkerlaunch
        ./steamtinkerlaunch compat add

    # Symlink SteamTinkerLaunch
        ln -sf "$HOME/steamtinkerlaunch/steamtinkerlaunch" "$HOME/.local/bin/steamtinkerlaunch"
        export PATH="$HOME/.local/bin:$PATH"

    # Register SteamTinkerLaunch as a compatibility tool (no-op if already added)
        "$HOME/.local/bin/steamtinkerlaunch" compat add || true

    echo ""
    echo "Adding server.sh as a Non‑Steam game shortcut..."
    echo "==================================="
    echo ""
        steamtinkerlaunch addnonsteamgame --appname="USBIP Server" --exepath="/usr/bin/konsole" --startdir="/usr/bin/" --launchoptions="--hold -e sudo ~/steam-deck-usbip/server.sh"

    echo ""
    echo "Select 'USBIP Server' from your Non‑Steam games to start the USBIP server!"
    echo "Client setup complete! Starting client script..."
    echo "==================================="
    echo ""

    echo  "Waiting 10 seconds before launching Steam Gaming Mode..."
        sleep 8

    echo "Launching Steam Gaming Mode..."
        sleep 2
        qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout

elif [ "$device_type" = "c" ]; then 
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm usbip git 
    elif command -v apt &> /dev/null; then
        sudo apt install -y linux-tools-generic usbip git  
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y usbip-utils git 
    else
        echo "Unsupported distribution. Please install usbip and git manually."
        exit 1
    fi
        fi
        
    
    echo ""
    echo "Client setup complete! Starting client script..."
    echo "==================================="
    echo ""
        chmod +x "$HOME/steam-deck-usbip/client.sh"
        cd "$HOME/steam-deck-usbip/"
    
    echo ""
    echo "Please make sure your PC and Steam Deck are on the same network."
    echo "Because then I can launch the client script for you now."
    echo "==================================="
    echo ""
    read -p "Do you want to proceed? (y/N): " proceed_client
        if [ "$proceed_client" = "y" ]; then
          echo "IP address available to your client:"
          # show available IPv4 addresses (numbered for clarity)
          ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | nl -w2 -s') '
          # pick the first detected IPv4 address (plain, without numbering) to derive the network prefix
          CLIENT_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
          if [ -z "$CLIENT_IP" ]; then
              echo "No IPv4 address found. Please ensure your client is connected to a network."
              exit 1
          fi
          NETWORK_PREFIX=$(echo "$CLIENT_IP" | cut -d. -f1-3)

          while true; do
            read -p "Enter the Steam Deck's identifier (last 3 numbers of the IP Address):" LAST_OCTET
            if [[ "$LAST_OCTET" =~ ^[0-9]{1,3}$ ]] && [ "$LAST_OCTET" -ge 0 ] && [ "$LAST_OCTET" -le 255 ]; then
                SD_IP="$NETWORK_PREFIX.$LAST_OCTET"
                break
            else
                echo "Invalid input. Please enter a number between 0 and 255."
            fi
    done

         echo "You selected IP: $SD_IP"
         sudo ./client.sh "$SD_IP"
         
        else
            echo "You can run the client script later by executing '$HOME/steam-deck-usbip/client.sh'"
            exit 0
        fi
    

else
    echo "Invalid device type selected. Please run script again and choose 's' or 'c'."
    exit 1
fi


#!/bin/bash

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}VNC Server Setup for Lubuntu${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run this script as a normal user (not root).${NC}"
    echo "The script will ask for sudo password when needed."
    exit 1
fi

# Ask for VNC server type
echo ""
echo "Select VNC server to install:"
echo "1) TigerVNC Standalone (create new virtual session)"
echo "2) TigerVNC Scraping (share existing display :0 - for kiosk/maintenance)"
echo "3) x11vnc (share existing display :0)"
read -p "Enter your choice (default: 1): " vnc_choice
vnc_choice=${vnc_choice:-1}

# Ask for display number and resolution only for standalone TigerVNC
if [ "$vnc_choice" = "1" ]; then
    read -p "Enter VNC display number (default: 1): " display_num
    display_num=${display_num:-1}
    
    read -p "Enter screen resolution (default: 1920x1080): " resolution
    resolution=${resolution:-1920x1080}
fi

# Install VNC server
echo -e "${YELLOW}Installing VNC server...${NC}"
if [ "$vnc_choice" = "1" ]; then
    sudo apt-get update
    sudo apt-get install -y tigervnc-standalone-server tigervnc-common
    VNC_SERVER="tigervnc"
elif [ "$vnc_choice" = "2" ]; then
    sudo apt-get update
    sudo apt-get install -y tigervnc-scraping-server tigervnc-common
    VNC_SERVER="tigervnc-scraping"
elif [ "$vnc_choice" = "3" ]; then
    sudo apt-get update
    sudo apt-get install -y x11vnc
    VNC_SERVER="x11vnc"
else
    echo -e "${RED}Invalid choice. Exiting.${NC}"
    exit 1
fi

if [ "$VNC_SERVER" = "tigervnc" ]; then
    # Setup TigerVNC
    echo -e "${YELLOW}Setting up TigerVNC...${NC}"
    
    # Create VNC directory if it doesn't exist
    mkdir -p ~/.vnc
    
    # Set VNC password
    echo -e "${YELLOW}Please set a VNC password (6-8 characters recommended):${NC}"
    vncpasswd
    
    # Create xstartup file
    echo -e "${YELLOW}Creating xstartup configuration...${NC}"
    cat > ~/.vnc/xstartup << 'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start LXQt with a new D-Bus session
export XDG_SESSION_DESKTOP=LXQt
export XDG_CURRENT_DESKTOP=LXQt
export XDG_SESSION_TYPE=x11

if command -v startlxqt >/dev/null 2>&1; then
    exec dbus-launch --exit-with-session startlxqt
else
    # Fallback to basic X session
    exec xterm
fi
EOF
    chmod +x ~/.vnc/xstartup
    
    # Create systemd service file
    SERVICE_FILE="$HOME/.config/systemd/user/vncserver@.service"
    mkdir -p "$HOME/.config/systemd/user"
    
    echo -e "${YELLOW}Creating systemd service file...${NC}"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=TigerVNC server for display %i
After=syslog.target network.target

[Service]
Type=forking
ExecStartPre=-/usr/bin/vncserver -kill :%i
ExecStart=/usr/bin/vncserver :%i -geometry ${resolution} -localhost no
ExecStop=/usr/bin/vncserver -kill :%i
PIDFile=${HOME}/.vnc/%H:%i.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    
    # Enable and start the service
    echo -e "${YELLOW}Enabling and starting VNC service...${NC}"
    systemctl --user daemon-reload
    systemctl --user enable vncserver@${display_num}.service
    systemctl --user start vncserver@${display_num}.service
    
    VNC_PORT=$((5900 + display_num))
    
    echo -e "${GREEN}TigerVNC setup completed!${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo "Display: :${display_num}"
    echo "Port: ${VNC_PORT}"
    echo "Resolution: ${resolution}"
    echo ""
    echo "Connect using: <hostname>:${display_num} or <hostname>:${VNC_PORT}"
    echo ""
    echo "Service management commands:"
    echo "  Start:   systemctl --user start vncserver@${display_num}.service"
    echo "  Stop:    systemctl --user stop vncserver@${display_num}.service"
    echo "  Restart: systemctl --user restart vncserver@${display_num}.service"
    echo "  Status:  systemctl --user status vncserver@${display_num}.service"
    echo ""
    echo "To enable service at boot (requires loginctl enable-linger):"
    echo "  sudo loginctl enable-linger $USER"
    
elif [ "$VNC_SERVER" = "tigervnc-scraping" ]; then
    # Setup TigerVNC Scraping Server (x0vncserver)
    echo -e "${YELLOW}Setting up TigerVNC Scraping Server...${NC}"
    
    # Create VNC directory if it doesn't exist
    mkdir -p ~/.vnc
    
    # Set VNC password (reuse existing if available)
    if [ ! -f ~/.vnc/passwd ]; then
        echo -e "${YELLOW}Please set a VNC password (6-8 characters recommended):${NC}"
        vncpasswd
    else
        echo -e "${YELLOW}Using existing VNC password at ~/.vnc/passwd${NC}"
        echo -e "To change password, run: vncpasswd"
    fi
    
    # Create systemd service file
    SERVICE_FILE="$HOME/.config/systemd/user/x0vncserver.service"
    mkdir -p "$HOME/.config/systemd/user"
    
    echo -e "${YELLOW}Creating systemd service file...${NC}"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=TigerVNC Scraping Server (x0vncserver)
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/x0vncserver -display :0 -rfbport 5900 -PasswordFile=${HOME}/.vnc/passwd -AlwaysShared=1 -localhost=0 -fg
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    
    # Enable and start the service
    echo -e "${YELLOW}Enabling and starting x0vncserver service...${NC}"
    systemctl --user daemon-reload
    systemctl --user enable x0vncserver.service
    systemctl --user start x0vncserver.service
    
    # Enable linger to keep service running after logout (for kiosk/maintenance)
    echo -e "${YELLOW}Enabling linger to keep VNC running after logout...${NC}"
    sudo loginctl enable-linger $USER
    
    echo -e "${GREEN}TigerVNC Scraping Server setup completed!${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo "Display: :0 (shares existing desktop)"
    echo "Port: 5900"
    echo ""
    echo "Connect using: <hostname>:0 or <hostname>:5900"
    echo ""
    echo "Service management commands:"
    echo "  Start:   systemctl --user start x0vncserver.service"
    echo "  Stop:    systemctl --user stop x0vncserver.service"
    echo "  Restart: systemctl --user restart x0vncserver.service"
    echo "  Status:  systemctl --user status x0vncserver.service"
    echo ""
    echo "Note: Linger has been enabled - VNC will start on boot without login."
    
elif [ "$VNC_SERVER" = "x11vnc" ]; then
    # Setup x11vnc
    echo -e "${YELLOW}Setting up x11vnc...${NC}"
    
    # Create x11vnc password
    echo -e "${YELLOW}Creating x11vnc password file...${NC}"
    mkdir -p ~/.x11vnc
    x11vnc -storepasswd ~/.x11vnc/passwd
    
    # Create systemd service file
    SERVICE_FILE="$HOME/.config/systemd/user/x11vnc.service"
    mkdir -p "$HOME/.config/systemd/user"
    
    echo -e "${YELLOW}Creating systemd service file...${NC}"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=x11vnc VNC Server
After=display-manager.service

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -rfbauth ${HOME}/.x11vnc/passwd -rfbport 5900 -forever -loop -noxdamage -repeat -shared
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    
    # Enable and start the service
    echo -e "${YELLOW}Enabling and starting x11vnc service...${NC}"
    systemctl --user daemon-reload
    systemctl --user enable x11vnc.service
    systemctl --user start x11vnc.service
    
    # Enable linger to keep service running after logout
    echo -e "${YELLOW}Enabling linger to keep VNC running after logout...${NC}"
    sudo loginctl enable-linger $USER
    
    echo -e "${GREEN}x11vnc setup completed!${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo "Port: 5900"
    echo ""
    echo "Connect using: <hostname>:0 or <hostname>:5900"
    echo ""
    echo "Service management commands:"
    echo "  Start:   systemctl --user start x11vnc.service"
    echo "  Stop:    systemctl --user stop x11vnc.service"
    echo "  Restart: systemctl --user restart x11vnc.service"
    echo "  Status:  systemctl --user status x11vnc.service"
    echo ""
    echo "Note: Linger has been enabled - VNC will start on boot without login."
fi

echo ""
echo -e "${YELLOW}Note: You may need to configure your firewall to allow VNC connections.${NC}"
echo "For example, to allow VNC in ufw:"
if [ "$VNC_SERVER" = "tigervnc" ]; then
    echo "  sudo ufw allow ${VNC_PORT}/tcp"
else
    echo "  sudo ufw allow 5900/tcp"
fi

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Setup Summary:${NC}"
if [ "$VNC_SERVER" = "tigervnc" ]; then
    echo "Type: TigerVNC Standalone (new virtual session)"
    echo "Display: :${display_num} (Port: ${VNC_PORT})"
elif [ "$VNC_SERVER" = "tigervnc-scraping" ]; then
    echo "Type: TigerVNC Scraping (shares existing :0)"
    echo "Port: 5900 (Display :0)"
    echo "Note: Shows the same content as physical display"
elif [ "$VNC_SERVER" = "x11vnc" ]; then
    echo "Type: x11vnc (shares existing :0)"
    echo "Port: 5900 (Display :0)"
    echo "Note: Shows the same content as physical display"
fi

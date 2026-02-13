#!/bin/bash
echo "Uninstalling Guptik and wiping ALL data..."

# 1. Stop containers and delete local volumes (the -v flag is key)
if [ -d "$HOME/Guptik/docker" ]; then
    cd "$HOME/Guptik/docker"
    docker-compose down -v --remove-orphans
fi

# 2. Delete the physical drive data and the app folder
rm -rf "/media/pruthvisimha/Drive/DB/guptik_local"
rm -rf "$HOME/Guptik"

# 3. Wipe Flutter local storage (SharedPreferences/DB)
rm -rf "$HOME/.config/guptik_desktop"

echo "Success. System is clean."
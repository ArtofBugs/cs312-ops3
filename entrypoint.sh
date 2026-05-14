#!/bin/bash
set -e

# Accept EULA
echo "eula=true" > eula.txt

# Handle MOTD if server.properties exists (it will be created by the jar on first run)
# Add custom motd value based on the MOTD environment variable.
# If server.properties file doesn't exist yet, create it and the first run will accept any existing values in the file.
# If the file already exists, replace the motd value with the value of the variable using sed.
if [ ! -f server.properties ]; then
    echo "motd=${MOTD:-Default MOTD}" > server.properties
else
    sed -i "/^motd=/c\motd=${MOTD:-Default MOTD}" server.properties
fi

# This ensures that even if 'mc_data' was mounted as root,
# the 'minecraft' user can now write to it.
chown -R minecraft:minecraft /opt/minecraft

# Run the server! Use gosu to do it as the minecraft user
exec gosu minecraft java -Xms4G -Xmx4G -jar paper.jar nogui

# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, as specified in the PaperMC docs
# and also gosu for the entrypoint script
RUN apt-get update && apt-get install -y \
    ca-certificates \
    apt-transport-https \
    gnupg \
    wget \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Java, as specified in the PaperMC docs: https://docs.papermc.io/misc/java-install/#verifying-installation
RUN wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list && \
    apt-get update && \
    apt-get install -y java-25-amazon-corretto-jdk libxi6 libxtst6 libxrender1

# Create the `minecraft` user; set bash as the default shell for the user
RUN useradd -m -s /bin/bash minecraft

# Create a working directory for the Minecraft files
RUN mkdir -p /opt/minecraft && chown -R minecraft:minecraft /opt/minecraft
WORKDIR /opt/minecraft

# Copy the entrypoint script to the image
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Download the PaperMC jar file to the working directory
RUN curl -o /opt/minecraft/paper.jar \
    https://fill-data.papermc.io/v1/objects/25eb85bd8415195ce4bc188e1939e0c7cef77fb51d26d4e766407ee922561097/paper-1.21.11-130.jar \
     && chown minecraft:minecraft /opt/minecraft/paper.jar

# Expose the Minecraft port
EXPOSE 25565

# Run entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
```

Create a `entrypoint.sh` file with the below contents:

```sh
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

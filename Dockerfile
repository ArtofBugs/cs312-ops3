# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, as specified in the PaperMC docs
RUN apt-get update && apt-get install -y \
    ca-certificates \
    apt-transport-https \
    gnupg \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Java, as specified in the PaperMC docs: https://docs.papermc.io/misc/java-install/#verifying-installation
RUN wget -O- https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list && \
    apt-get update && \
    apt-get install -y java-25-amazon-corretto-jdk

# Create the `minecraft` user; set bash as the default shell for the user
RUN useradd -m -s /bin/bash minecraft

# Create a working directory for the Minecraft files
RUN mkdir -p /opt/minecraft && chown -R minecraft:minecraft /opt/minecraft
WORKDIR /opt/minecraft

# Download the PaperMC jar file to the working directory
RUN curl -o /opt/minecraft/paper.jar \
   https://fill-data.papermc.io/v1/objects/25eb85bd8415195ce4bc188e1939e0c7cef77fb51d26d4e766407ee922561097/paper-1.21.11-130.jar \
    && chown minecraft:minecraft /opt/minecraft/paper.jar

# Switch to the `minecraft` user. All future commands will be run as `minecraft` rather than as root
USER minecraft

# Run the Paper jar once to generate the needed files; this is expected to fail
RUN java -Xms4G -Xmx4G -jar paper.jar --nogui

# Accept argument for the motd to allow configuring message at runtime
# The default value is my ONID, lowercase
# This line is down here instead of at the top of the file next to ENV so that cache for the previous steps isn’t broken by the value of this argument changing
ARG motd=wengor

# Edit the eula file to accept the EULA agreement, remove (in place) any existing line starting with 0 or more tabs followed by `motd` from the server properties file, and add a new motd line using the value of the `motd` argument from the above step
RUN echo "eula=true" > eula.txt && \
    sed "/^\t*motd/d" server.properties -i && \
    echo "motd=$motd" >> server.properties

# Expose the Minecraft port
EXPOSE 25565

# Startup command to start the Minecraft server
CMD ["java", "-Xms2G", "-Xmx4G", "-jar", "paper.jar", "nogui"]


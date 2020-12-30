#!/bin/bash
#
# Stolen from David Hutchinson's Blog:
# https://www.devwithimagination.com/2020/02/02/running-homebridge-on-docker-without-host-network-mode/
#
# This script allows for running a Homebridge docker container without the need for macvlan networking.
# Instead, we can simply expose one port through Traefik.
# However, we must know the port, and publish an mDNS record via an avahi service.
# 
# Script intended to be run if a container is ever deleted and rebuilt.
#
set -euo pipefail
IFS=$'\n\t'

# Find the running homebridge container
CONTAINER=$(sudo docker ps | grep homebridge | cut -d " " -f1)


if [ -z "$CONTAINER" ]; then
  echo "No running homebridge container found"
  exit 1
fi

# Get configuration values out of the container configuration file
NAME=$(sudo docker exec "$CONTAINER" /bin/grep "\"name\":" /homebridge/config.json | head -n 1 | cut -d '"' -f4)
MAC=$(sudo docker exec "$CONTAINER" /bin/grep "\"username\":" /homebridge/config.json | cut -d '"' -f4)
PORT=$(sudo docker exec "$CONTAINER"  /bin/grep "\"port\":" /homebridge/config.json | head -n 1 | sed 's/[^0-9]*//g')
SETUPID=$(sudo docker exec "$CONTAINER"  /bin/grep "$NAME" /homebridge/persist/AccessoryInfo.$(echo $MAC | sed 's/://g').json | python3 -c "import sys, json; print(json.load(sys.stdin)['setupID'])")

# Write the service configurtion file to the current directory
cat <<EOF>"homebridge.service"
<service-group>
  <name>$NAME</name>
  <service>
    <type>_hap._tcp</type>
    <port>$PORT</port>

    <!-- friendly name -->
    <txt-record>md=$NAME</txt-record>

    <!-- HAP version -->
    <txt-record>pv=1.0</txt-record>
    <!-- MAC -->
    <txt-record>id=$MAC</txt-record>
    <!-- Current configuration number -->
    <txt-record>c#=2</txt-record>

    <!-- accessory category
         2=bridge -->
    <txt-record>ci=2</txt-record>

    <!-- accessory state
          This must have a value of 1 -->
    <txt-record>s#=1</txt-record>
    <!-- Pairing Feature Flags
         nothing to configure -->
    <txt-record>ff=0</txt-record>
    <!-- Status flags
         0=not paired, 1=paired -->
    <txt-record>sf=1</txt-record>
    <!-- setup hash (used for pairing).
         Required to support enhanced
         setup payload information (but
         not defined in the spec)        -->
    <txt-record>sh=$(echo -n ${SETUPID}${MAC} | openssl dgst -binary -sha512 | head -c 4 | base64)</txt-record>
  </service>
</service-group>
EOF

# Move it in to place
sudo mv -i homebridge.service /etc/avahi/services/

# Helper Message
echo "Please ensure you have exposed port $PORT"

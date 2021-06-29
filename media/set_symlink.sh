#!/usr/bin/env bash
#
set -e

source .env
ln -sf $DOCKER_LOCATION services
echo "Symlink to ${DOCKER_LOCATION} created."


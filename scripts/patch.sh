#!/bin/sh
#
# Patcher script to apply patches and sync sources
#

set -eu

# Get directory where this script is located and cd to root
cd $(dirname $0)/..

echo ">>> Building patcher image..."
docker build -t patcher -f Dockerfile.patcher .

echo ">>> Applying patches and syncing sources..."

# Default targets if none provided
TARGETS=${*:-"clean apply-patches sync"}

docker run --rm \
    -v "$(pwd):/workspace" \
    patcher \
    make -f Makefile.sync $TARGETS

echo ">>> Done."

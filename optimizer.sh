#!/bin/bash
set -e

# Fetch proxy secret and configuration
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf

# Generate a random secret if none is provided
if [ -z "$SECRET" ]; then
  SECRET=$(head -c 16 /dev/urandom | xxd -ps)
  echo "Generated secret: $SECRET"
fi

# Validate required variables
if [ -z "$PORT" ]; then
  echo "Error: PORT environment variable is required."
  exit 1
fi

if [ -z "$PROXY_TAG" ]; then
  echo "Error: PROXY_TAG environment variable is required."
  exit 1
fi

# Set default number of workers if not provided
WORKERS=${WORKERS:-1}

# Set a high value for window clamp
WINDOW_CLAMP=65535

# Start MTProxy with optimized settings
exec ./objs/bin/mtproto-proxy \
  -u nobody \
  -p "$PORT" \
  -H "$PORT" \
  -M "$WORKERS" \
  --ipv6 \
  --ping-interval=1 \
  --allow-skip-dh \
  --window-clamp="$WINDOW_CLAMP" \
  --aes-pwd proxy-secret proxy-multi.conf \
  -S "$SECRET" \
  -P "$PROXY_TAG"

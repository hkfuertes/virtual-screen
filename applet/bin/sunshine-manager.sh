#!/bin/bash

INDEX=$(./x11-manager.sh index)

if [ -z "$INDEX" ]; then
  echo "Error: Could not determine HDMI output index."
  exit 1
fi

# Actualizar sunshine.conf
SUNSHINE_CONF="$HOME/.config/Sunshine/sunshine.conf"
grep -q "^output_name" "$SUNSHINE_CONF" && \
    sed -i "s/^output_name *= *.*/output_name = $INDEX/" "$SUNSHINE_CONF" || \
    echo "output_name = $INDEX" >> "$SUNSHINE_CONF"

# Reiniciar Sunshine
systemctl --user restart sunshine
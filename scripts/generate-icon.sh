#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Resources"
ICON_SOURCE="$RESOURCES_DIR/icon-1024.png"
ICONSET_DIR="/tmp/AppIconQuick.iconset"
OUTPUT_DIR="$PROJECT_DIR/Sources/Resources"
OUTPUT="$OUTPUT_DIR/AppIcon.icns"

mkdir -p "$RESOURCES_DIR" "$OUTPUT_DIR"

# Generate source PNG if it doesn't exist
if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "Generating source icon..."
    python3 -c "
import struct, zlib, math

def create_png(width, height, pixels):
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter byte
        for x in range(width):
            raw += bytes(pixels(x, y))
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw, 9)) +
            chunk(b'IEND', b''))

size = 1024
cx, cy = size / 2, size / 2
r = size * 0.42

# Lightning bolt polygon (centred, white) — defined as a series of points
# Classic 'jagged Z' shape for speed/electricity
bolt = [
    (-0.10, -0.42),  # top-right of head
    ( 0.18, -0.42),  # top tip
    (-0.02, -0.05),  # inner notch right
    ( 0.16, -0.05),  # right shoulder
    (-0.18,  0.42),  # bottom tip
    (-0.18,  0.42),
    ( 0.02,  0.05),  # inner notch left
    (-0.16,  0.05),  # left shoulder
]
# Re-order so it forms a proper closed polygon
bolt = [
    ( 0.10, -0.42),
    (-0.20,  0.04),
    ( 0.02,  0.04),
    (-0.10,  0.42),
    ( 0.22, -0.06),
    ( 0.00, -0.06),
]

def point_in_poly(px, py, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi):
            inside = not inside
        j = i
    return inside

def pixel(x, y):
    dx, dy = x - cx, y - cy
    dist = math.sqrt(dx*dx + dy*dy)
    if dist <= r:
        # Deep purple → violet radial gradient
        t = dist / r
        rb = int( 96 + ( 60 -  96) * t)   # 96 → 60
        g  = int( 32 + ( 18 -  32) * t)   # 32 → 18
        b  = int(168 + (110 - 168) * t)   # 168 → 110
        # Subtle top highlight
        highlight = max(0, min(1, 1 - (dy + r * 0.4) / (r * 0.8)))
        rb = min(255, int(rb + 30 * highlight))
        g  = min(255, int(g  + 18 * highlight))
        b  = min(255, int(b  + 28 * highlight))
        # Anti-aliased disc edge
        edge = max(0, min(1, (r - dist) * 2))
        a = int(255 * edge)

        # Lightning bolt overlay (white) in normalised coords
        nx = dx / r * 0.42
        ny = dy / r * 0.42
        if point_in_poly(nx, ny, bolt):
            return (255, 245, 210, a)  # warm white bolt for contrast
        return (rb, g, b, a)
    return (0, 0, 0, 0)

with open('$ICON_SOURCE', 'wb') as f:
    f.write(create_png(size, size, pixel))
print('Generated icon-1024.png')
"
fi

# Generate iconset
echo "Creating iconset..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

for size in 16 32 128 256 512; do
    sips -z $size $size "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" > /dev/null 2>&1
    retina=$((size * 2))
    sips -z $retina $retina "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" > /dev/null 2>&1
done
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

# Generate .icns
echo "Generating .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"
rm -rf "$ICONSET_DIR"

echo "Generated: $OUTPUT"

import random
import struct
import zlib

BASE = '/Users/gauravpandey/Desktop/ORG/cognitrack-mobile/assets/images'

# (filename, background_RGB, dot_colour_RGB)
ASSETS = [
    ('lungs_box',    (15, 20, 28),  (80, 140, 200)),   # blue-ish lung
    ('lungs_478',    (15, 20, 28),  (80, 140, 200)),   # blue-ish lung
    ('eye_2020',     (10, 10, 18),  (180, 80,  80)),   # red-ish eye
    ('river_stream', (8,  20, 28),  (60, 160, 220)),   # teal water
    ('zen_forest',   (8,  22, 12),  (60, 180,  80)),   # green forest
    ('avatar',       (30, 30, 35),  (160, 160, 160)),  # neutral grey
]

def u32(n):
    return struct.pack('>I', n)

def make_chunk(tag, data):
    c = tag + data
    return u32(len(data)) + c + u32(zlib.crc32(c) & 0xFFFFFFFF)

def write_png(path, size, bg_rgb, dot_rgb):
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = u32(size) + u32(size) + bytes([8, 2, 0, 0, 0])  # 8-bit RGB
    ihdr = make_chunk(b'IHDR', ihdr_data)

    br, bg, bb = bg_rgb
    dr, dg, db = dot_rgb

    rows = []
    for y in range(size):
        row = bytearray([0])  # filter byte None
        for x in range(size):
            # Subtle dot pattern every 32px
            on_grid = (x % 32 == 16 and y % 32 == 16)
            if on_grid:
                row += bytearray([dr, dg, db])
            else:
                # slight vignette noise around bg
                jitter = random.randint(-6, 6)
                row += bytearray([
                    max(0, min(255, br + jitter)),
                    max(0, min(255, bg + jitter)),
                    max(0, min(255, bb + jitter)),
                ])
        rows.append(bytes(row))

    compressed = zlib.compress(b''.join(rows), 6)
    idat = make_chunk(b'IDAT', compressed)
    iend = make_chunk(b'IEND', b'')

    with open(path, 'wb') as f:
        f.write(sig + ihdr + idat + iend)

for name, bg, dot in ASSETS:
    out = f'{BASE}/{name}.png'
    write_png(out, 512, bg, dot)
    print(f'  {name}.png')

print('Done - all placeholders written.')
print('Replace these with real exports from your Stitch design when ready.')

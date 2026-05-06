import random
import struct
import zlib

def u32(n):
    return struct.pack('>I', n)

def chunk(tag, data):
    c = tag + data
    return u32(len(data)) + c + u32(zlib.crc32(c) & 0xFFFFFFFF)

def make_noise_png(path, size=256):
    sig = b'\x89PNG\r\n\x1a\n'

    ihdr_data = u32(size) + u32(size) + bytes([8, 6, 0, 0, 0])
    ihdr = chunk(b'IHDR', ihdr_data)

    raw_rows = []
    for _ in range(size):
        row = bytearray([0])
        for _ in range(size):
            v = random.randint(180, 255)
            a = random.randint(0, 15)
            row += bytearray([v, v, v, a])
        raw_rows.append(bytes(row))

    compressed = zlib.compress(b''.join(raw_rows), 6)
    idat = chunk(b'IDAT', compressed)
    iend = chunk(b'IEND', b'')

    with open(path, 'wb') as f:
        f.write(sig + ihdr + idat + iend)
    print('noise_texture.png written successfully')

make_noise_png('/Users/gauravpandey/Desktop/ORG/cognitrack-mobile/assets/images/noise_texture.png')

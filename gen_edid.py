#!/usr/bin/env python3
"""
EDID Generator with all common resolutions (tablets included)
Non-interactive, HDR disabled
Supports multiple CEA extension blocks to fit all resolutions
"""

import struct

COMMON_RESOLUTIONS = {
    "1": ("720p", 1280, 720),
    "2": ("1080p", 1920, 1080),
    "3": ("1440p", 2560, 1440),
    "4": ("4K", 3840, 2160),
    "5": ("UWQHD", 3440, 1440),
    "6": ("Steam Deck (landscape)", 1280, 800),
    "7": ("Steam Deck (portrait)", 800, 1280),
    "8": ("WUXGA", 1920, 1200),
    "9": ("WQHD", 2560, 1600),
    "10": ("iPad Air 10.9 (100%)", 2360, 1640),
    "11": ("iPad Air 10.9 (75%)", int(2360*0.75), int(1640*0.75)),
    "12": ("iPad Air 10.9 (50%)", int(2360*0.5), int(1640*0.5)),
    "13": ("iPad Pro 12.9 (100%)", 2732, 2048),
    "14": ("iPad Pro 12.9 (75%)", int(2732*0.75), int(2048*0.75)),
    "15": ("iPad Pro 12.9 (50%)", int(2732*0.5), int(2048*0.5)),
    "16": ("iPad Mini 6 (100%)", 2266, 1488),
    "17": ("iPad Mini 6 (75%)", int(2266*0.75), int(1488*0.75)),
    "18": ("iPad Mini 6 (50%)", int(2266*0.5), int(1488*0.5)),
    "19": ("Surface Pro 7 (100%)", 2736, 1824),
    "20": ("Surface Pro 7 (75%)", int(2736*0.75), int(1824*0.75)),
    "21": ("Surface Pro 7 (50%)", int(2736*0.5), int(1824*0.5)),
    "22": ("Surface Go 3 (100%)", 1920, 1280),
    "23": ("Surface Go 3 (75%)", int(1920*0.75), int(1280*0.75)),
    "24": ("Surface Go 3 (50%)", int(1920*0.5), int(1280*0.5)),
    "25": ("Galaxy Tab S8 (100%)", 2560, 1600),
    "26": ("Galaxy Tab S8 (75%)", int(2560*0.75), int(1600*0.75)),
    "27": ("Galaxy Tab S8 (50%)", int(2560*0.5), int(1600*0.5)),
    "28": ("Galaxy Tab S7 (100%)", 2560, 1600),
    "29": ("Galaxy Tab S7 (75%)", int(2560*0.75), int(1600*0.75)),
    "30": ("Galaxy Tab S7 (50%)", int(2560*0.5), int(1600*0.5)),
}

COMMON_REFRESH_RATE = 60  # Hz

def calculate_checksum(data):
    return (256 - (sum(data) % 256)) % 256

def dtd_bytes(width, height, refresh_rate=60):
    """Generate 18-byte Detailed Timing Descriptor for a resolution"""
    h_active = width
    v_active = height
    h_blank = max(80, int(width * 0.08))
    h_total = h_active + h_blank
    v_blank = max(23, int(height * 0.025))
    pixel_clock_hz = h_total * (v_active + v_blank) * refresh_rate
    pixel_clock = int(pixel_clock_hz / 10000)
    pixel_clock = min(pixel_clock, 65535)
    v_size_mm = int((height / width) * 30)
    h_size_mm = int((width / height) * 30)

    h_sync_offset = int(h_blank * 0.2)
    h_sync_width = int(h_blank * 0.4)
    v_sync_offset = 2
    v_sync_width = 6

    edid = bytearray(18)
    edid[0:2] = struct.pack("<H", pixel_clock)
    edid[2] = h_active & 0xFF
    edid[3] = h_blank & 0xFF
    edid[4] = ((h_active >> 8) << 4) | (h_blank >> 8)
    edid[5] = v_active & 0xFF
    edid[6] = v_blank & 0xFF
    edid[7] = ((v_active >> 8) << 4) | (v_blank >> 8)
    edid[8] = h_sync_offset & 0xFF
    edid[9] = h_sync_width & 0xFF
    edid[10] = ((v_sync_offset & 0x0F) << 4) | (v_sync_width & 0x0F)
    edid[11] = (
        (((h_sync_offset >> 8) & 0x03) << 6)
        | (((h_sync_width >> 8) & 0x03) << 4)
        | (((v_sync_offset >> 4) & 0x03) << 2)
        | ((v_sync_width >> 4) & 0x03)
    )
    edid[12] = h_size_mm & 0xFF
    edid[13] = v_size_mm & 0xFF
    edid[14] = ((h_size_mm >> 8) << 4) | (v_size_mm >> 8)
    edid[15] = 0  # H border
    edid[16] = 0  # V border
    edid[17] = 0x18  # Non-interlaced, digital separate sync
    return edid

def create_base_block(preferred_res):
    edid = bytearray(128)
    edid[0:8] = [0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00]
    edid[8:10] = [0x56, 0x24]  # Manufacturer
    edid[10:12] = struct.pack("<H", 0x5344)
    edid[12:16] = struct.pack("<I", 0x12345678)
    edid[16] = 1
    edid[17] = 33
    edid[18:20] = [1,4]
    edid[20] = 0xA5
    edid[21] = 30
    edid[22] = 20
    edid[23] = 220
    edid[24] = 0x1E
    edid[25:35] = [0xEE,0x91,0xA3,0x54,0x4C,0x99,0x26,0x0F,0x50,0x54]
    edid[35:38] = [0,0,0]
    edid[38:54] = [1,1]*8
    edid[54:72] = dtd_bytes(*preferred_res[1:], COMMON_REFRESH_RATE)
    edid[126] = 0  # number of extensions to fill later
    edid[127] = calculate_checksum(edid[0:127])
    return edid

def create_extension_block(resolutions):
    block = bytearray(128)
    block[0] = 0x02  # CEA
    block[1] = 0x03  # revision
    block[2] = 4 + len(resolutions)*18  # dtd offset
    block[3] = 0x70  # basic flags
    offset = 4
    for res in resolutions:
        block[offset:offset+18] = dtd_bytes(*res[1:], COMMON_REFRESH_RATE)
        offset += 18
    # Pad remaining bytes
    while offset < 127:
        block[offset] = 0x00
        offset += 1
    block[127] = calculate_checksum(block[0:127])
    return block

def create_full_edid():
    keys = sorted(COMMON_RESOLUTIONS.keys())
    preferred = COMMON_RESOLUTIONS[keys[0]]
    base = create_base_block(preferred)
    extension_blocks = []

    # Split remaining resolutions into chunks of 7
    remaining_res = [COMMON_RESOLUTIONS[k] for k in keys[1:]]
    chunk_size = 7
    for i in range(0, len(remaining_res), chunk_size):
        chunk = remaining_res[i:i+chunk_size]
        extension_blocks.append(create_extension_block(chunk))

    # Update base block extension count
    base[126] = len(extension_blocks)

    return [base] + extension_blocks

def main():
    blocks = create_full_edid()
    name = "edid.bin"
    with open(name,"wb") as f:
        for b in blocks:
            f.write(b)
    print(f"Generated EDID with {len(blocks)} blocks (base + {len(blocks)-1} extensions)")
    print(f"Output file: {name}")
    print(f"Total size: {128*len(blocks)} bytes")

if __name__ == "__main__":
    main()

# tile_convertで変換したファイルを確認する

import argparse
from PIL import Image

# argparseの設定
# *****************************************************************************
parser = argparse.ArgumentParser(description='Check the converted tile image.')
parser.add_argument('input', help='Input tile image file')
args = parser.parse_args()

# 変換したタイルイメージを読み込む
with open(args.input, 'rb') as f:
    buf = f.read()

    # ヘッダの読み込み
    header = buf[:4]
    if header != b'TILE':
        print('Error: Invalid tile image file.')
        exit(1)
    print("file header: OK")

    # タイルデータのサイズを読み込む
    file_size_bytes = buf[4:8]
    file_size = int.from_bytes(file_size_bytes, byteorder='little')
    print("file size: ", file_size, "bytes")

    # 幅、高さ、パレット数を読み込む
    width = int.from_bytes(buf[8:10], byteorder='little')
    height = int.from_bytes(buf[10:12], byteorder='little')
    print(f"width: {width}, height: {height}")

    palette_offset = int.from_bytes(buf[12:16], byteorder='little')
    tile_offset = int.from_bytes(buf[16:20], byteorder='little')
    print(f"palette_offset: {palette_offset}, tile_offset: {tile_offset}")

    # パレット部の取得
    palette_num = (tile_offset - palette_offset) // 2
    palette_data = buf[palette_offset:tile_offset]

    # タイル部の取得
    tile_size = int.from_bytes(buf[tile_offset:tile_offset+4], byteorder='little')
    tile_data = buf[tile_offset+4:tile_offset+4+tile_size]
    print(f"tile_size: {tile_size} bytes, number of tiles: {len(tile_data) // 32}")

# キャンバスにタイル部を描画する
canvas = Image.new('RGB', (256, 256))

for i in range(0, len(tile_data), 32):  # 32バイトごとに1タイル(8x8ピクセル)
    tile_index = i // 32
    x = (tile_index % 32) * 8
    y = (tile_index // 32) * 8

    for j in range(8):  # 8行
        for k in range(8):  # 8列
            pixel_index = j * 8 + k
            if len(tile_data) <= i + pixel_index:
                continue
            if palette_num == 16:
                # 4bppの場合、2ピクセルで1バイト
                byte_index = i + (pixel_index // 2)
                if pixel_index % 2 == 0:
                    color_index = tile_data[byte_index] & 0x0F
                else:
                    color_index = (tile_data[byte_index] >> 4) & 0x0F
            else:
                # 8bppの場合、1ピクセルで1バイト
                color_index = tile_data[i + pixel_index]

            # パレットからRGB値を取得する
            palette_entry_offset = color_index * 2
            palette_entry = int.from_bytes(palette_data[palette_entry_offset:palette_entry_offset + 2], byteorder='little')
            r = ((palette_entry >> 0) & 0x1F) << 3
            g = ((palette_entry >> 5) & 0x1F) << 3
            b = ((palette_entry >> 10) & 0x1F) << 3

            if x + k < canvas.width and y + j < canvas.height:
                canvas.putpixel((x + k, y + j), (r, g, b))

# キャンバスを2倍で表示する
canvas = canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST)
canvas.show()

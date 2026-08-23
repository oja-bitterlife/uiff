# パレットpngからタイル表示用画像を出力する。

# ファイルフォーマット
# [Header]
#   - magic (4bytes): 例 "GBBG" (GBA BackGround の略など。ファイル破損や形式違いのチェック用)
#   - file_size (4bytes): ファイルサイズ (ヘッダを含む)
#   - width (2bytes): 画像の幅 (ピクセル単位)
#   - height (2bytes): 画像の高さ (ピクセル単位)
#   - palette_offset (4bytes): パレットデータのオフセット(ファイル先頭から)
#   - tile_offset (4bytes): タイルデータのオフセット(ファイル先頭から)
#   - header_padding: ヘッダのサイズを4バイト境界に合わせるためのパディング
# [Palette]
#   - palette_data (32bytes for 16色, または 512bytes for 256色)
# [Tiles]
#   - tile_data_size (4bytes)
#   - tile_data (可変)
#   - tile_padding(可変): dataのサイズを4バイト境界に合わせるためのパディング

import argparse
import os
from PIL import Image

# まずは引数の取得
argparser = argparse.ArgumentParser(description='Convert palette PNG to tile image.')
argparser.add_argument('input', help='Input palette PNG file')
argparser.add_argument('-o', '--output', help='Output tile image file')
argparser.add_argument('-k', '--key-index', type=int, help='Palette index to be used as transparent (default: left-top-color)')
args = argparser.parse_args()

# 画像を読み込み、パレットを取得する。パレットがなければエラー終了する。
img = Image.open(args.input)
if img.mode != 'P':
    print('Error: Input image must be a palette PNG.')
    exit(1)


# パレットの処理
# *****************************************************************************
# パレットのbit数
palette_num = 16 if len(img.getcolors()) <= 16 else 256
palette = img.getpalette()

# パレットを16bitのRGB555に変換して、リストに格納する。
def rgb_to_rgb555(r, g, b):
    return ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)
palette_rgb555 = [rgb_to_rgb555(palette[i], palette[i+1], palette[i+2]) for i in range(0, len(palette), 3)]
if len(palette_rgb555) > palette_num:
    raise Exception(f"Palette has more colors than expected: {len(palette_rgb555)} > {palette_num}")

# 透過パレットを0番にする
# --------------------------------------------------------------
# 透過パレットが指定されていない場合、左上の色を透過色として使用する
if args.key_index is None:
    key_index = img.getpixel((0, 0))
else:
    key_index = args.key_index

# key_indexが0でなければ入れ替える
if key_index != 0:
    # key_index番の色を0番にする
    palette_rgb555[0], palette_rgb555[key_index] = palette_rgb555[key_index], palette_rgb555[0]
    def swap_pal(index, key_index):
        if index == 0:
            return key_index
        elif index == key_index:
            return 0
        else:
            return index
    pixel_data = [swap_pal(p, key_index) for p in img.get_flattened_data()]
else:
    pixel_data = img.get_flattened_data()

# palette_rgb555[0] = 0  # 透過パレットを0にしておく

# タイルデータの作成
# *****************************************************************************
# 8x8のタイルに分割して、タイルごとにピクセルデータを格納する
tile_data = []
width, height = img.size
for ty in range(0, height, 8):
    for tx in range(0, width, 8):
        tile = []
        for y in range(8):
            for x in range(8):
                px = tx + x
                py = ty + y
                if px < width and py < height:
                    pal_index = pixel_data[py * width + px]
                    tile.append(pal_index)
                else:
                    tile.append(0)  # 余白は0で埋める
        tile_data.append(tile)

# 書き出し
# *****************************************************************************
# パレットデータのバイト列化（RGB555 各2バイト）
palette_buf = bytearray()

# 4bppなら16色(32バイト)、8bppなら256色(512バイト)を書き出し
for i in range(palette_num):
    color_val = palette_rgb555[i] if i < len(palette_rgb555) else 0  # 余白は0で埋める
    palette_buf.extend(color_val.to_bytes(2, byteorder='little'))

# タイルデータをバイナリに変換する処理
# -------------------------------------------------------------------
# 4bppの場合は2ピクセルで1バイト（16色＝4bit）、8bppの場合は1ピクセルで1バイト
tile_buf = bytearray()
for tile in tile_data:
    if palette_num == 16:
        # 4bppは2ピクセルを1バイトにまとめる (低位4bit, 高位4bit)
        for i in range(0, len(tile), 2):
            b = (tile[i+1] << 4) | (tile[i] & 0x0F)
            tile_buf.append(b)
    else:
        # 8bppはそのまま1ピクセル1バイト
        for p in tile:
            tile_buf.append(p)
tile_buf.extend(bytearray((4 - len(tile_buf) % 4) % 4))  # タイルデータを4バイト境界に揃える

# タイルデータの先頭にタイルバッファサイズを付加する
tile_buf = len(tile_buf).to_bytes(4, byteorder='little') + tile_buf


# ヘッダ情報の組み立て
# -------------------------------------------------------------------
header_buf = bytearray()
header_buf.extend(b'TILE')  # magic
header_buf.extend((0).to_bytes(4, byteorder='little'))  # file_size (後で更新)
header_buf.extend((width).to_bytes(2, byteorder='little'))  # width
header_buf.extend((height).to_bytes(2, byteorder='little'))  # height
palette_header_offset = len(header_buf)
header_buf.extend((0).to_bytes(4, byteorder='little'))  # palette_offset (後で更新)
tile_header_offset = len(header_buf)
header_buf.extend((0).to_bytes(4, byteorder='little'))  # tile_offset (後で更新)
header_buf.extend((0).to_bytes(((4 - len(header_buf) % 4) % 4), byteorder='little'))  # ヘッダを4バイト境界に揃える

total_file_size = len(header_buf) + len(palette_buf) + len(tile_buf)

# ヘッダの各オフセットを更新
header_buf[4:8] = total_file_size.to_bytes(4, byteorder='little')
header_buf[palette_header_offset:palette_header_offset+4] = len(header_buf).to_bytes(4, byteorder='little')  # palette_offset
header_buf[tile_header_offset:tile_header_offset+4] = (len(header_buf) + len(palette_buf)).to_bytes(4, byteorder='little')  # tile_offset

# ファイルに書き出し
with open(args.output, 'wb') as f:
    f.write(header_buf)
    f.write(palette_buf)
    f.write(tile_buf)

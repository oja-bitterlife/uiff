# 入力されたTextファイルの漢字部分を抽出し、PNG画像に変換するスクリプト

import argparse
from PIL import Image, ImageDraw, ImageFont

# argparseの設定
# *****************************************************************************
parser = argparse.ArgumentParser(description='Convert extracted Kanji characters from a text file into a PNG image.')
parser.add_argument('input', help='Input UTF-8 text file containing Kanji characters')
parser.add_argument('-o', '--output', required=True, type=str, help='Output PNG file path')
parser.add_argument('-f', '--font', required=True, type=str, help='Path to the TTF font file to be used for rendering Kanji characters')
parser.add_argument('-s', '--size', required=True, type=int, help='Font size for rendering Kanji characters (default: 48)')
parser.add_argument('-a', '--with_ascii', action='store_true', help='Include ASCII characters in the output image (default: False)')
args = parser.parse_args()

# fontの設定
# -------------------------------------------------------------------
font_path = args.font
font_size = args.size
if font_size > 16:
    raise ValueError("Font size must be 16 or less for proper rendering on GBA.")

font = ImageFont.truetype(font_path, font_size)

# 漢字リストを読み込む
# -------------------------------------------------------------------
with open(args.input, 'r', encoding='utf-8') as kfile:
    kanji_list = [char for char in "".join(kfile).strip()]
    if len(kanji_list) > 128:
        raise ValueError("Kanji list must contain 128 or fewer characters for proper rendering on GBA.")

# 入力ファイルを読み込む
# -------------------------------------------------------------------
with open(args.input, 'r', encoding='utf-8') as f:
    text = f.read()

# キャンバス作成
# *****************************************************************************
canvas_width = 256
canvas_height = ((len(kanji_list)+15) // 16) * 16
if args.with_ascii:
    canvas_height += 96  # ASCII行のために追加

# グレースケール
canvas = Image.new("L", (canvas_width, canvas_height), color=0)

count = 0
# ASCIIコードを書き出す
if args.with_ascii:
    for char in range(0x20, 0x7F):
        x = count % 16
        y = count // 16
        # 文字を描画
        draw = ImageDraw.Draw(canvas)
        draw.text((x * 16, y * 16), chr(char), font=font, fill=255)
        count += 1

# 続きで漢字を書き出す
for char in kanji_list:
    x = count % 16
    y = count // 16
    # 文字を描画
    draw = ImageDraw.Draw(canvas)
    draw.text((x * 16, y * 16), char, font=font, fill=255)
    count += 1

# 画像で書き出す
# *****************************************************************************
palette_img = canvas.quantize(colors=16)
palette_img.save(args.output)


# 入力されたTextファイルの漢字部分を抽出し、PNG画像に変換するスクリプト

import argparse
from PIL import Image, ImageDraw, ImageFont

# argparseの設定
parser = argparse.ArgumentParser(description='Convert extracted Kanji characters from a text file into a PNG image.')
parser.add_argument('input', help='Input UTF-8 text file containing Kanji characters')
parser.add_argument('output', help='Output PNG image file')
parser.add_argument('-f', '--font', help='Path to the TTF font file to be used for rendering Kanji characters')
parser.add_argument('-s', '--size', type=int, default=48, help='Font size for rendering Kanji characters (default: 48)')
args = parser.parse_args()

font_path = args.font
font_size = args.size
font = ImageFont.truetype(font_path, font_size)

# 入力ファイルを読み込む
with open(args.input, 'r', encoding='utf-8') as f:
    text = f.read()

# パレット画像を読み込んで、使われていない順にソートする
import argparse
from PIL import Image

# 引数の処理
# *****************************************************************************
parser = argparse.ArgumentParser(description="Sort palette image by unused colors")
parser.add_argument("image_path", help="Path to the palette image")
parser.add_argument("-o", "--output", required=True, help="Output path for the sorted palette image")  # 必須
parser.add_argument("-m", "--min-palette", type=int, help="Number of minimum colors in the palette")
parser.add_argument("-p", "--gba-palette", action="store_true", help="Use GBA555 format for palette sorting")
args = parser.parse_args()


# 画像の読み込み
# *****************************************************************************
img = Image.open(args.image_path)
# パレット画像でなければエラー
if img.mode != "P":
    img = img.convert("P")  # パレット画像に変換

# パレット操作
# *****************************************************************************
# RGBずつまとめたパレットを取得
palette_data = img.getpalette()
rgb_palettes = [list(palette_data[i:i+3]) for i in range(0, len(palette_data), 3)]

# GBA555の場合はrgb_palettesの下位3bitを埋める
if args.gba_palette:
    for i in range(len(rgb_palettes)):
        r, g, b = rgb_palettes[i]
        rgb_palettes[i] = [r|0x07, g|0x07, b|0x07]


# 参照パレット作成
# {(rgb):index}
# -------------------------------------------------------------------
# パレットの参照数を取得して、使われていない順にソートする
used_palette_count = img.getcolors()  # count, index
used_palette_count.sort(key=lambda x: x[0])

# 同じ色をまとめた参照テーブルを作成する
palette_ref_map = {tuple(rgb_palettes[pair[1]]):i for i, pair in enumerate(used_palette_count)}  # ※indexは抜け番がある

# ref_mapからソートされたパレットを作成する
sorted_palette = [None] * len(rgb_palettes)  # 抜け番にNoneが入るように
for color, index in palette_ref_map.items():
    sorted_palette[index] = color  # 抜け番を飛ばして色を設定していく
sorted_palette = [color for color in sorted_palette if color is not None]  # Noneを除去してきれいなリストに


# パレットの拡張
# -------------------------------------------------------------------
# パレットが指定数オーバーの場合はエラー
if args.min_palette is not None:
    if palette_ref_map is None or len(sorted_palette) > args.min_palette:
        raise ValueError(f"The palette has {len(sorted_palette)} colors, which exceeds the minimum of {args.min_palette}.")

# パレットの目標とする長さを決定する
min_palette_num = 16 if len(sorted_palette) <= 16 else 256
if args.min_palette is not None:  # 指定があればそれを優先
    min_palette_num = args.min_palette

# 白と黒をぬいた上で拡張準備
ext_palette = [color for color in sorted_palette if color != (0, 0, 0) and color != (255, 255, 255)]

# パレットを拡張する
if min_palette_num > len(ext_palette):
    remaining_colors = min_palette_num - len(ext_palette)
    ext_palette = remaining_colors * [(0, 0, 0)] + ext_palette

# 0と1が[0,0,0]であれば1に白を埋め込められる
if ext_palette[0] == (0, 0, 0) and ext_palette[1] == (0, 0, 0):
    ext_palette[1] = (255, 255, 255)  # 白を埋め込む


# 新しいパレットで、新しいピクセルデータを作る
# 逆パレットの頭からのindexを取得し、たくさん使ってるパレットを優先して使うようにする
# -------------------------------------------------------------------
# ピクセル操作用の逆パレットを作る
reverse_palette = list(reversed(ext_palette))

# 逆パレットを使って新しいパレット番号に置き換える
pixels = img.get_flattened_data()
new_pixels = []
for index in pixels:
    # 逆パレットのインデックスを取得
    new_index = reverse_palette.index(tuple(rgb_palettes[index]))
    new_pixels.append(min_palette_num-1 - new_index)  # 逆パレット番号から元に戻す


# 画像出力
# *****************************************************************************
# 新しい画像を作成する
new_img = Image.new("P", img.size)
new_img.putpalette([value for color in ext_palette for value in color])
new_img.putdata(new_pixels)

# 新しい画像を保存する
new_img.save(args.output)

import sys
import argparse

# 引数の処理
parser = argparse.ArgumentParser(description="Pad file to a specific offset")
parser.add_argument("file_path", help="Path to the file")
parser.add_argument("-off", "--offset", type=int, default=65536, help="Target offset for padding (default: 65536)")
parser.add_argument("-o", "--output", required=True, help="Output path for the padded file")  # 必須
args = parser.parse_args()

file_path = args.file_path
target_offset = args.offset
output_path = args.output

# 1. ファイルを読み込む
with open(file_path, "rb") as f:
    data = bytearray(f.read())

# 2. 指定オフセットまで足りない分を0埋め（パディング）する
if len(data) < target_offset:
    data.extend(b"\x00" * (target_offset - len(data)))

    # 3. 最終的なファイルを書き出す
    output_file = output_path
    with open(output_file, "wb") as f:
        f.write(data)

else:
    # 指定サイズを超えていたらエラー
    raise ValueError(f"Binary size ({len(data)}) exceeded offset ({target_offset})!")

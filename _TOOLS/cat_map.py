# 入力されたファイルを順番に結合し、出力ファイルを作成するスクリプト
# 4byte境界を調べながら結合する
# 配置mapファイルを出力できる

import argparse

# 引数のパーサーを作成
parser = argparse.ArgumentParser(description='Concatenate GBA file with tile title and uiff binary')
parser.add_argument('input_files', nargs='+', help='Input files to concatenate')
parser.add_argument('-o', '--output', required=True, help='Output file name')
parser.add_argument('-a', '--align', type=int, help='Alignment boundary')
parser.add_argument('-m', '--map', action='store_true', help='Generate map file')

buf = bytearray()
offset_map = []

# 入力ファイルを順番に読み込み、結合する
args = parser.parse_args()
for input_file in args.input_files:
    with open(input_file, 'rb') as f:
        data = bytearray(f.read())
        org_size = len(data)

        # 指定された境界に合わせてパディングする
        if args.align:
            padding = (args.align - (len(data) % args.align)) % args.align
            data.extend(b'\x00' * padding)

        # 4byte境界であることを確認する
        if len(data) % 4 != 0:
            raise ValueError(f"Current buffer size {len(data)} is not aligned to 4 bytes before adding {input_file}")

        # 状態の記録
        offset_map.append({
            'file': input_file,
            'in_size': (org_size, f"0x{org_size:08X}"),
            'offset': (len(buf), f"0x{len(buf):08X}"),
            'out_size': (len(data), f"0x{len(data):08X}")
        })

        buf.extend(data)

# 出力ファイルに書き込む
with open(parser.parse_args().output, 'wb') as f:
    f.write(buf)

# --mapがついていたらoffset mapを保存する
if args.map:
    import json
    with open(parser.parse_args().output + '.map', 'w') as f:
        out_buf = "["
        for entry in offset_map:
            out_buf += "{\n"
            out_buf += f"  \"file\": \"{entry['file']}\",\n"
            out_buf += f"  \"offset\": [{entry['offset'][0]}, \"{entry['offset'][1]}\"],\n"
            out_buf += f"  \"in_size\": [{entry['in_size'][0]}, \"{entry['in_size'][1]}\"],\n"
            out_buf += f"  \"out_size\": [{entry['out_size'][0]}, \"{entry['out_size'][1]}\"]\n"
            out_buf += "},"

        if out_buf[-1] == ",":
            out_buf = out_buf[:-1]  # Remove the last comma
        out_buf += "]\n"

        f.write(out_buf)

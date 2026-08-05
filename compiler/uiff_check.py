# uiffバイナリファイルを読んで、解析ツリーを表示する
import argparse

# argparseでファイル名を受け取る
parser = argparse.ArgumentParser(description='UIFFファイルを解析する')
parser.add_argument('filename', type=str, help='UIFFファイルのパス')
args = parser.parse_args()

def getUInt16(data, offset):
    return int.from_bytes(data[offset:offset+2], byteorder='little')

# uiffバイナリファイルを読む
with open(args.filename, "rb") as f:
    data = f.read()

# ヘッダのチェック
if data[:4] != b'UIFF':
    raise ValueError("Invalid UIFF file")

# サイズの表示
print("data-size:", getUInt16(data, 4))

def parse_chunk(data, offset):
    chunk_type = getUInt16(data, offset)
    chunk_size = getUInt16(data, offset + 2)
    chunk_data = data[offset + 4:offset + 4 + chunk_size]
    return chunk_type, chunk_size, chunk_data

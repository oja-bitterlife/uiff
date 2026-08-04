import json, argparse, os, sys
from iff import *

# コマンドライン処理
# *****************************************************************************
# 引数を取得して、JSONファイルを読み込む
# ---------------------------------------------------------
parser = argparse.ArgumentParser(description='Convert UIFF to JSON')
parser.add_argument('input_file', type=str, help='Input UIFF file')
parser.add_argument('-def', '--define', type=str, action='append', help='Define JSON file')
args = parser.parse_args()

# JSONファイルを読み込む
with open(args.input_file, 'r') as f:
    ui_data = json.load(f)

# 定義用jsonを-def <filename>で指定されたファイルから読み込む
# ---------------------------------------------------------
define_data = {}
args = parser.parse_args()

# 見つけた順でマージする
if args.define:
    for define_file in args.define:
        with open(define_file, 'r') as f:
            define_data.update(json.load(f))

# プリプロセス
# *****************************************************************************
# data中のIDを再帰しながら探してIDリストを作成する
ids = [None]
def collect_ids(obj):
    if isinstance(obj, dict):
        if 'ID' in obj:
            # IDが重複していないかチェック
            if obj['ID'] in ids:
                print(f"Error: Duplicate ID found: {obj['ID']}")
                sys.exit(1)
            ids.append(obj['ID'])
        for value in obj.values():
            collect_ids(value)
    elif isinstance(obj, list):
        for item in obj:
            collect_ids(item)
collect_ids(ui_data)

# デバッグ用
print("Collected IDs:", ids)


# コンバート開始
# *****************************************************************************

def write_chunk(chunk_type, chunk_data, data_size):
    buf = bytearray()

    # chunk type
    buf.append(chunk_type)
    # chunk size
    buf.extend(data_size.to_bytes(2, byteorder='little'))
    # chunk data
    if type(chunk_data) == bytes or type(chunk_data) == bytearray:
        buf.extend(chunk_data)
    else:
        buf.extend(chunk_data.to_bytes(data_size, byteorder='little'))

    return buf

def convert(obj):
    buf = bytearray()

    for key, value in obj.items():
        match key.upper():
            case "TYPE":
                type_id = define_data.get("Type").get(value)
                buf.extend(write_chunk(IFF_TYPE, int(type_id), 2))

            case "ID":
                ui_id = ids.index(value)
                buf.extend(write_chunk(IFF_ID, int(ui_id), 1))

            case "CHILDREN":
                child_buf = bytearray()
                for child in value:
                    child_buf.extend(convert(child))
                buf.extend(write_chunk(IFF_CHILDREN, child_buf, len(child_buf)))

            case "X" | "Y" | "W" | "H":
                chunk_type = {
                    "X": IFF_X,
                    "Y": IFF_Y,
                    "W": IFF_W,
                    "H": IFF_H
                }[key.upper()]
                buf.extend(write_chunk(chunk_type, int(value), 2))

            case "ALIGNCENTERX" | "ALIGNCENTERY":
                pass

            case "TEXT":
                bytes_data = value.encode('ascii', 'ignore')
                buf.extend(write_chunk(IFF_TEXT, bytes_data, len(bytes_data)))

            case "ROWSNUM":
                buf.extend(write_chunk(IFF_ROWS_NUM, int(value), 1))

            case "EVENTS":
                event_buf = bytearray()
                for val in value:
                    event_id = define_data.get("Event").get(val)
                    if event_id is None:
                        print(f"Error: Unknown event found: {val}")
                        sys.exit(1)
                    event_buf.extend(int(event_id).to_bytes(2, byteorder='little'))
                buf.extend(write_chunk(IFF_EVENTS, event_buf, len(event_buf)))

            case "CLOSEIDS":
                close_id_buf = bytearray()
                for val in value:
                    ui_id = ids.index(val)
                    if ui_id is None:
                        print(f"Error: Unknown ID found in CloseID: {val}")
                        sys.exit(1)
                    close_id_buf.extend(int(ui_id).to_bytes(1, byteorder='little'))
                buf.extend(write_chunk(IFF_CLOSE_IDS, close_id_buf, len(close_id_buf)))

            case "SCRIPT":
                pass

            # 知らないkeyが来た場合はエラーにする
            case _:
                print(f"Error: Unknown key found: {key}")
                sys.exit(1)

    return buf


# 出力データ作成
buf = bytearray()

# header
buf.extend(b'UIFF')  # magic

# データ部
# *****************************************************************************
# 配列ならループで
if isinstance(ui_data, list):
    for item in ui_data:
        buf.extend(convert(item))
else:
    # 配列でなければそのまま
    buf.extend(convert(ui_data))

# 最後にpaddingを追加する
padding_size = (4 - (len(buf) % 4)) % 4
buf.extend(b'\x00' * padding_size)

# お試し出力
print(" ".join(f"{byte:02X}" for byte in buf))

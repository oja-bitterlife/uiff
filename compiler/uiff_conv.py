import json, argparse, os, sys

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
print("Collected IDs:", ids)


# コンバート開始
# *****************************************************************************
buf = bytearray()

def convert(obj):
    for key, value in obj.items():
        match key.upper():
            case "TYPE":
                type_id = define_data.get("Type").get(value)
                buf.append(type_id)
                print(value, "->", type_id)

            case "CHILDREN":
                children = obj.get('value', [])
                for child in children:
                    convert(child)

            # 知らないkeyが来た場合はエラーにする
            case _:
                print(f"Error: Unknown key found: {key}")
                sys.exit(1)

# 配列ならループで
if isinstance(ui_data, list):
    for item in ui_data:
        convert(item)
else:
    # 配列でなければそのまま
    convert(ui_data)

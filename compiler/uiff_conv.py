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
    data = json.load(f)

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
collect_ids(data)
print("Collected IDs:", ids)


# コンバート開始
# *****************************************************************************


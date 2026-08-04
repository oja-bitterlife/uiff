import json, argparse, os, sys
from unittest import case
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


# コンバート関数
# *****************************************************************************
class DispatchTree:
    def __init__(self, json_data: dict|list):
        self.props = {}
        self.children = []

        # json_dataがdictかlistかで処理を分ける
        if isinstance(json_data, list):
            # listの場合はchilrendにDispatchTreeを突っ込む
            for item in json_data:
                self.children.append(DispatchTree(item))
        else:  # dict
            # 辞書のときはchildren以外をpropsに突っ込む
            for key, value in json_data.items():
                if key == "children":
                    # childrenの場合は再帰的にDispatchTreeを作成する
                    self.children = DispatchTree(value).children
                else:
                    self.props[key] = value

    # コンバート各処理
    def get_chunk_buf(self, chunk_type:int, data: bytes):
        data = bytearray()
        # chunk_typeを2byteで書き出す
        data.extend(int(chunk_type).to_bytes(2, byteorder='little'))
        # chunk_sizeを2byteで書き出す
        data.extend(len(data).to_bytes(2, byteorder='little'))
        # dataをそのまま書き出す
        data.extend(data)
        return data

    def get_chunk_int(self, chunk_type:int, data:int):
        return self.get_chunk_buf(chunk_type, data.to_bytes(2, byteorder='little'))

    # コンバート
    def get_chunk(self):
        data = bytearray()

        # typeのチェック
        data.extend(self.check_type())

        # selectのチェック
        data.extend(self.check_select())

        # 残りのpropsを順番に書き出す
        for key, value in self.props.items():
            match key:
                case "Text":
                    data.extend(self.get_chunk_buf(IFF_TEXT, value.encode('ascii', 'replace')))
                case "Script":
                    pass
                case "Events":
                    for event in value:
                        event_id = define_data.get("Event").get(event)
                        if event_id is None:
                            print(f"Error: Unknown event found: {event}")
                            sys.exit(1)
                        data.extend(self.get_chunk_int(IFF_EVENTS, event_id))
                case _:
                    raise ValueError(f"Unknown property '{key}' found in {self.chunk_type_str}. Ignoring.")

        # 子の処理
        children_buf = bytearray()
        for child in self.children:
            children_buf.extend(child.get_chunk())  # 再帰的に子を処理する
        data.extend(children_buf)

        return data

    # 個別処理
    # *************************************************************************
    def check_type(self):
        # デバッグ用に保存しながらTypeを取得
        self.chunk_type_str = self.props.get("Type")
        if self.chunk_type_str is None:
            print("Error: Type is missing in the root node.")
            sys.exit(1)

        self.chunk_type = define_data.get("Type").get(self.chunk_type_str)
        if self.chunk_type is None:
            print(f"Error: Unknown type found: {self.chunk_type_str}")
            sys.exit(1)

        # SubTypeの取得
        subtype = self.props.get("SubType")
        if subtype is None:
            subtype = 0  # SubTypeがない場合は0を使用する
        if not isinstance(subtype, int):
            # SubTypeがintでない場合はdefine_dataから取得する 
            subtype = define_data.get("SubType").get(subtype)
            if subtype is None:
                print(f"Error: Unknown subtype found: {self.props.get('SubType')}")
                sys.exit(1)
        self.props.pop("SubType", None)  # SubTypeをpropsから削除する

        # Areaの取得
        # 後で実装する
        self.props.pop("AlignCenterX", None)

        area_buf = bytearray()
        area_buf.extend(self.props.get("X", 0).to_bytes(2, byteorder='little'))
        area_buf.extend(self.props.get("Y", 0).to_bytes(2, byteorder='little'))
        area_buf.extend(self.props.get("W", 0xffff).to_bytes(2, byteorder='little'))
        area_buf.extend(self.props.get("H", 0xffff).to_bytes(2, byteorder='little'))
        self.props.pop("X", None)
        self.props.pop("Y", None)
        self.props.pop("W", None)
        self.props.pop("H", None)

        # data部を作成する
        data = bytearray()
        data.extend(self.chunk_type.to_bytes(2, byteorder='little'))
        data.extend(subtype.to_bytes(2, byteorder='little'))
        data.extend(area_buf)

        # chunkの作成
        out = bytearray()
        out.extend(self.get_chunk_buf(IFF_TYPE, data))
        self.props.pop("Type", None)  # Typeをpropsから削除する

        return out

    def check_select(self):
        if self.chunk_type != define_data.get("Type").get("TYPE_SELECT"):
            return bytearray()  # Selectタイプ以外は無視する

        # SelRowsの取得
        rows_num = self.props.get("SelRows", 32767)  # SelRowsがない場合は32767を使用する
        self.props.pop("SelRows", None)  # SelRowsをpropsから削除する

        # SelItemsの取得
        sel_item_buf = bytearray()
        items = self.props.get("SelItems", [])
        for item in items:
            sel_item_buf.extend(self.get_chunk_buf(IFF_SEL_ITEM, item.encode('ascii', 'replace')))
        self.props.pop("SelItems", None)  # SelItemsをpropsから削除する

        # Select用dataの組み立て
        data = bytearray()
        data.extend(self.get_chunk_int(IFF_SELECT, rows_num))
        data.extend(sel_item_buf)

        select_buf = bytearray()
        select_buf.extend(self.get_chunk_buf(IFF_SELECT, data))
        self.props.pop("Select", None)  # Selectをpropsから削除する

        return select_buf



# jsonからDispatchTreeを作成する
root = DispatchTree(ui_data)

# 出力データ作成
# *****************************************************************************
# dispatch treeを再帰的に処理してdataを作成する
data = bytearray()
if root.props.get("Type") is None:
    # rootがListの場合はchildrenが処理対象
    for child in root.children:
        data.extend(child.get_chunk())
else:
    data.extend(root.get_chunk())

# header
out = bytearray()
total_size = len(data)
out.extend(b'UIFF')  # magic
out.extend(total_size.to_bytes(2, byteorder='little'))  # total size

# データを追加
out.extend(data)  # data

# paddingを追加
padding_size = (4 - (len(out) % 4)) % 4
out.extend(b'\x00' * padding_size)

# お試し出力
print(" ".join(f"{byte:02X}" for byte in out))

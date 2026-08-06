import json, argparse, os, sys
from unittest import case
from iff import *

# script用
sys.path.append(os.getcwd())  # カレントディレクトリをパスに追加
from pyvm.compiler.pyvm_bc import BytecodeCompiler

INT16_MAX = 0x7fff

# 便利関数
# *****************************************************************************
class Area():
    x: int
    y: int
    w: int
    h: int

    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h

    def get_area_buf(self):
        area_buf = bytearray()
        area_buf.extend((self.x & 0xffff).to_bytes(2, byteorder='little'))
        area_buf.extend((self.y & 0xffff).to_bytes(2, byteorder='little'))
        area_buf.extend((self.w & 0xffff).to_bytes(2, byteorder='little'))
        area_buf.extend((self.h & 0xffff).to_bytes(2, byteorder='little'))
        return area_buf

    # レイアウト用
    # ---------------------------------------------------------------
    def clip(self, parent_area):
        # 親の範囲に収まるようにclipする
        right = min(self.x + self.w, parent_area.x + parent_area.w)
        bottom = min(self.y + self.h, parent_area.y + parent_area.h)

        self.x = max(self.x, parent_area.x)
        self.y = max(self.y, parent_area.y)
        self.w = right - self.x
        self.h = bottom - self.y

    def align_x(self, parent_area, align="left"):
        # 親の範囲に収まるようにclipする
        if align == "center":
            self.x = parent_area.x + (parent_area.w - self.w) // 2
        elif align == "left":
            self.x = parent_area.x
        elif align == "right":
            self.x = parent_area.x + parent_area.w - self.w

    def align_y(self, parent_area, align="top"):
        # 親の範囲に収まるようにclipする
        if align == "center":
            self.y = parent_area.y + (parent_area.h - self.h) // 2
        elif align == "top":
            self.y = parent_area.y
        elif align == "bottom":
            self.y = parent_area.y + parent_area.h - self.h

# 大文字小文字を無視したdictアクセス
def ignore_pop(props: dict, key: str):
    key_upper = key.upper()
    target_key = None
    for k in list(props.keys()):
        if k.upper() == key_upper:
            target_key = k
            break
    if target_key is not None:
        props.pop(target_key, None)

def ignore_get(props: dict, key: str, default=None):
    key_upper = key.upper()
    for k in props.keys():
        if k.upper() == key_upper:
            return props[k]
    return default

# コンバート各処理
def util_get_chunk_buf(chunk_type:int, data: bytes):
    chunk = bytearray()
    # chunk_typeを2byteで書き出す
    chunk.extend(int(chunk_type).to_bytes(2, byteorder='little'))
    # chunk_sizeを2byteで書き出す
    chunk.extend(len(data).to_bytes(2, byteorder='little'))
    # dataをそのまま書き出す
    chunk.extend(data)
    return chunk

def util_get_chunk_int(chunk_type:int, data:int):
    return util_get_chunk_buf(chunk_type, data.to_bytes(2, byteorder='little'))


# コンバート
# *****************************************************************************
class DispatchBase():
    # 処理するType名を返す
    def get_process_type(self) -> str:
        raise NotImplementedError("get_process_type must be implemented in subclasses")

    # chunkを作成する
    def get_chunk(self, type_info: TypeDispatcher, props: dict, define_data: dict) -> bytes:
        raise NotImplementedError("get_chunk must be implemented in subclasses")

class TypeDispatcher():
    type_id: int
    subtype_id: int

    # デバッグ表示用
    type_str: str
    subtype_str: str

    area: Area

    def __init__(self, parent_area: Area, props: dict, define_data: dict):
        # Typeの取得
        self.type_str = ignore_get(props, "Type")  # デバッグ用
        if self.type_str is None:
            raise ValueError("Error: Type is not specified in props")
        self.type_id = define_data.get("Type").get(self.type_str)
        if self.type_id is None:
            raise ValueError(f"Error: Unknown type found: {self.type_str}")
        ignore_pop(props, "Type")  # Typeをpropsから削除する

        # SubTypeの取得
        self.subtype_str = ignore_get(props, "SubType")  # デバッグ用
        subtype_id = ignore_get(props, "SubType", 0)  # デフォルト値は0
        if not isinstance(subtype_id, int):
            # SubTypeがintでない場合(名前指定)はdefine_dataから取得する 
            subtype_id = define_data.get("SubType").get(subtype_id)
            if subtype_id is None:
                raise ValueError(f"Error: Unknown subtype_id found: {self.subtype_str}")
        self.subtype_id = subtype_id
        ignore_pop(props, "SubType")  # SubTypeをpropsから削除する

        # Areaの取得
        self.area = Area(ignore_get(props, "X", 0), ignore_get(props, "Y", 0), ignore_get(props, "W", INT16_MAX), ignore_get(props, "H", INT16_MAX))
        ignore_pop(props, "X")
        ignore_pop(props, "Y")
        ignore_pop(props, "W")
        ignore_pop(props, "H")

        # Areaの更新
        # Popupがさいつよ
        if ignore_get(props, "Popup", False):
            ignore_pop(props, "Popup")
        elif ignore_get(props, "Extend", False):
            # 自分の範囲がはみ出たら範囲を広げる
            self.area.x += parent_area.x
            self.area.y += parent_area.y
            right = max(self.area.x + self.area.w, parent_area.x + parent_area.w)
            bottom = max(self.area.y + self.area.h, parent_area.y + parent_area.h)
            self.area.w = right - self.area.x
            self.area.h = bottom - self.area.y
            ignore_pop(props, "Extend")
        else:
            # Align系の処理
            if ignore_get(props, "AlignCenterX", False):
                self.area.align_x(parent_area, "center")
                ignore_pop(props, "AlignCenterX")
            if ignore_get(props, "AlignLeft", False):
                self.area.align_x(parent_area, "left")
                ignore_pop(props, "AlignLeft")
            if ignore_get(props, "AlignRight", False):
                self.area.align_x(parent_area, "right")
                ignore_pop(props, "AlignRight")
            if ignore_get(props, "AlignCenterY", False):
                self.area.align_y(parent_area, "center")
                ignore_pop(props, "AlignCenterY")
            if ignore_get(props, "AlignTop", False):
                self.area.align_y(parent_area, "top")
                ignore_pop(props, "AlignTop")
            if ignore_get(props, "AlignBottom", False):
                self.area.align_y(parent_area, "bottom")
                ignore_pop(props, "AlignBottom")

            # 親の範囲に収まるようにclipする
            self.area.clip(parent_area)

    def get_chunk(self):
        type_chunk = bytearray()

        # data部を作成する
        data = bytearray()
        data.extend(self.type_id.to_bytes(2, byteorder='little'))
        data.extend(self.subtype_id.to_bytes(2, byteorder='little'))
        data.extend(self.area.get_area_buf())

        # chunkの作成
        type_chunk.extend(util_get_chunk_buf(IFF_TYPE, data))

        return type_chunk

class DispatchTree(DispatchBase):
    def __init__(self, json_data: dict|list, define_data: dict):
        self.define_data = define_data

        self.props = {}
        self.children = []

        self.type_dispatchers = {}
        self.prop_dispatchers = {}

        # json_dataがdictかlistかで処理を分ける
        if isinstance(json_data, list):
            # listの場合はchilrendにDispatchTreeを突っ込む
            for item in json_data:
                self.children.append(DispatchTree(item, define_data))
        else:  # dict
            # 辞書のときはchildren以外をpropsに突っ込む
            for key, value in json_data.items():
                if key.upper() == "CHILDREN":
                    # childrenの場合は再帰的にDispatchTreeを作成する
                    self.children = DispatchTree(value, define_data).children
                else:
                    self.props[key] = value

        print(self.props)

        # type_dispatchersの登録
        self.add_type_dispatcher(SelectDispatcher)  # TYPE_SELECT用のディスパッチャを登録する

        # prop_dispatchersの登録
        self.add_prop_dispatcher(TextDispatcher)  # Text用のディスパッチャを登録する
        self.add_prop_dispatcher(ScriptDispatcher)  # Script用のディスパッチャを登録する
        self.add_prop_dispatcher(EventsDispatcher)  # Events用のディスパッチャを登録する
        self.add_prop_dispatcher(ColorDispatcher)  # Color用のディスパッチャを登録する

    # Dispatchersの追加
    # *************************************************************************
    def add_type_dispatcher(self, dispatcher_class:DispatchBase):
        self.type_dispatchers[dispatcher_class().get_process_type().upper()] = dispatcher_class

    def add_prop_dispatcher(self, dispatcher_class:DispatchBase):
        self.prop_dispatchers[dispatcher_class().get_process_type().upper()] = dispatcher_class

    # コンバート
    # *************************************************************************
    # ノードを再帰的に処理してchunkデータを作成する
    def get_chunk(self, parent_area: Area):
        data = bytearray()
        node_area = parent_area  # ノードの範囲を初期化する

        # list定義の場合childrenしかないのでpropsが空になる
        if len(self.props) > 0:
            # ノードのtype情報を取得して以降の処理内容を決定する
            type_info = TypeDispatcher(parent_area, self.props, self.define_data)
            data.extend(type_info.get_chunk())  # type情報もchunkとして出力
            node_area = type_info.area  # 範囲を更新する

            # Type対象Dispatchersの処理
            # 特別なTypeでしか使わないpropsを処理する(ユーザー定義Type用)
            if type_info.type_str in self.type_dispatchers:
                user_type = type_info.type_str.upper()
                data.extend(self.type_dispatchers[user_type]().get_chunk(type_info, self.props, self.define_data))

            # 残りのpropsを順番に書き出す
            for key, value in self.props.items():
                key_upper = key.upper()
                if key_upper not in self.prop_dispatchers:
                    raise ValueError(f"Unknown property '{key}' found in {type_info.type_str}:{type_info.subtype_str}. Ignoring.")
                data.extend(self.prop_dispatchers[key_upper]().get_chunk(type_info, self.props, self.define_data))

        # 子の処理
        # -----------------------------------------------------------
        if len(self.children) > 0:
            children_buf = bytearray()
            for child in self.children:
                children_buf.extend(child.get_chunk(node_area))  # 再帰的に子を処理する
            # 2byte境界のはず
            if len(children_buf) % 2 != 0:
                raise ValueError(f"Children data size is not aligned to 2 bytes: {len(children_buf)}")
            data.extend(util_get_chunk_buf(IFF_CHILD, children_buf))  # 子のchunkを追加する

        return data


    # 出力データ作成
    # *****************************************************************************
    def get_uidata(self):
        # dispatch treeを再帰的に処理してdataを作成する
        data = bytearray()
        data.extend(self.get_chunk(Area(0, 0, INT16_MAX, INT16_MAX)))  # 親の範囲は最大値で初期化する

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

        return out

    def print_uidata(self):
        out = self.get_uidata()
        print(" ".join(f"{byte:02X}" for byte in out))

# 個々のPropの処理
# *****************************************************************************
class TextDispatcher(DispatchBase):
    def get_process_type(self):
        return "Text"

    def get_chunk(self, type_info: TypeDispatcher, props: dict, define_data: dict):
        text = ignore_get(props, self.get_process_type(), "")
        # dataを2byte境界にして書き出す
        data = text.encode('ascii', 'replace')
        padding_size = (2 - (len(data) % 2)) % 2
        # 先頭2byteにlenを付加してchunkを作成する
        return util_get_chunk_buf(IFF_TEXT, len(data).to_bytes(2, byteorder='little') + data + b'\x00' * padding_size)

class ScriptDispatcher(DispatchBase):
    def get_process_type(self):
        return "Script"

    def get_chunk(self, type_info: TypeDispatcher, props: dict, define_data: dict):
        script = ignore_get(props, self.get_process_type(), None)
        if script is None:
            raise ValueError(f"Error: Script is not specified in props for {type_info.type_str}:{type_info.subtype_str}")
        # scriptをコンパイルしてbytecodeに変換する
        bc = BytecodeCompiler(script, paths=[os.getcwd()])  # カレントディレクトリをパスに追加
        return util_get_chunk_buf(IFF_SCRIPT, bc.get_bytecode())

class EventsDispatcher(DispatchBase):
    def get_process_type(self):
        return "Events"

    def get_chunk(self, type_info: TypeDispatcher, props: dict, define_data: dict):
        events_buf = bytearray()
        events = ignore_get(props, self.get_process_type(), [])
        for event in events:
            event_id = define_data.get("Event").get(event)
            if event_id is None:
                raise ValueError(f"Error: Unknown event found: {event}")
            events_buf.extend(event_id.to_bytes(2, byteorder='little'))
        return util_get_chunk_buf(IFF_EVENTS, events_buf)

class ColorDispatcher(DispatchBase):
    def get_process_type(self):
        return "Colors"

    def get_chunk(self, type_info: TypeDispatcher, props: dict, define_data: dict):
        color_buf = bytearray()
        value = ignore_get(props, self.get_process_type(), [])
        for color in value:
            if not isinstance(color, int):
                raise ValueError(f"Error: Color value must be an integer, got {color}")
            color_buf.extend(color.to_bytes(4, byteorder='little'))
        return util_get_chunk_buf(IFF_COLORS, color_buf)


# 特別なTypeの処理
# *****************************************************************************
# TYPE_SELECTの処理
class SelectDispatcher(DispatchBase):
    def get_process_type(self):
        return "TYPE_SELECT"

    def get_chunk(self, type_info: TypeDispatcher, props: dict, define_data: dict):
        # Select用dataの組み立て
        sel_data_buf = bytearray()

        # SelRowsの取得
        rows_num = ignore_get(props, "SelRows", INT16_MAX)  # SelRowsがない場合は最大値を使用する
        sel_data_buf.extend(rows_num.to_bytes(2, byteorder='little'))
        ignore_pop(props, "SelRows")  # SelRowsをpropsから削除する

        # SelItemsの取得
        items = ignore_get(props, "SelItems", [])
        for item in items:
            # dataを2byte境界にして書き出す
            data = item.encode('ascii', 'replace')
            padding_size = (2 - (len(data) % 2)) % 2
            # 先頭2byteにlenを付加してchunkを作成する
            sel_data_buf.extend(util_get_chunk_buf(IFF_TEXT, len(data).to_bytes(2, byteorder='little') + data + b'\x00' * padding_size))
        ignore_pop(props, "SelItems")  # SelItemsをpropsから削除する

        select_buf = bytearray()
        select_buf.extend(util_get_chunk_buf(IFF_SELECT, sel_data_buf))
        ignore_pop(props, "Select")  # Selectをpropsから削除する

        return select_buf


# コマンドライン処理
# *****************************************************************************
if __name__ == "__main__":
    # 引数を取得して、JSONファイルを読み込む
    # ---------------------------------------------------------
    parser = argparse.ArgumentParser(description='Convert UIFF to JSON')
    parser.add_argument('input_file', type=str, help='Input UIFF file')
    parser.add_argument('-def', '--define', type=str, action='append', help='Define JSON files [複数指定可]')
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

    # 結果出力
    root = DispatchTree(ui_data, define_data)
    root.print_uidata()


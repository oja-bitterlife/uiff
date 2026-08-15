import json, argparse, os, sys

import os, sys
sys.path.append(os.getcwd())  # カレントディレクトリをパスに追加

from compiler.uiff_conv_lib import DispatchTree, DispatcherBase

class MyDispatcher(DispatcherBase):
    kanji_list = []

    def get_dispatch_name(self):
        return "MyProp"
    def get_chunk(self, type_info, props, define_data):
        # MyPropの値(int)をChunkに変換する
        return self.create_chunk_buf(0x1000, props.get(self.get_dispatch_name()).to_bytes(2, byteorder='little'))

# コマンドライン処理
# *****************************************************************************
def check_duplicate_keys(pairs):
    d = {}
    for key, val in pairs:
        if key in d:
            raise ValueError(f"Duplicate key found: {key}")
        d[key] = val
    return d

if __name__ == "__main__":
    # 引数を取得して、JSONファイルを読み込む
    # ---------------------------------------------------------
    parser = argparse.ArgumentParser(description='Convert UIFF to JSON')
    parser.add_argument('input_file', type=str, help='Input UIFF file')
    parser.add_argument('-o', '--output_file', type=str, help='Output Binary file')
    parser.add_argument('-def', '--define', type=str, action='append', help='Define JSON files [複数指定可]')
    args = parser.parse_args()

    # JSONファイルを読み込む
    with open(args.input_file, 'r') as f:
        ui_data = json.load(f, object_pairs_hook=check_duplicate_keys)

    # 定義用jsonを-def <filename>で指定されたファイルから読み込む
    # ---------------------------------------------------------
    define_dict = {}
    args = parser.parse_args()

    # 見つけた順でマージする
    if args.define:
        for define_file in args.define:
            with open(define_file, 'r') as f:
                define_dict.update(json.load(f))

    # 結果出力
    root = DispatchTree(ui_data, define_dict)
    root.add_prop_dispatcher(MyDispatcher)
    if args.output_file:
        with open(args.output_file, 'wb') as f:
            f.write(root.get_uiff())
    else:
        root.print_uiff()

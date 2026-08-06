import json, argparse, os, sys

import os, sys
sys.path.append(os.getcwd())  # カレントディレクトリをパスに追加
from compiler.uiff_conv_lib import DispatchTree

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
    define_dict = {}
    args = parser.parse_args()

    # 見つけた順でマージする
    if args.define:
        for define_file in args.define:
            with open(define_file, 'r') as f:
                define_dict.update(json.load(f))

    # 結果出力
    root = DispatchTree(ui_data, define_dict)
    root.print_uiff()


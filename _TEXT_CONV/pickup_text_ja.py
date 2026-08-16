# utf8のテキストを読んで、使用している漢字を抜き出し、漢字と辞書インデックスを生成する
# 入力は何でもOK、ASCIIコードは無視し漢字のみぬき出す

# 出力形式: 文字のみを16文字で折り返して表示する

import argparse
import json

def pickup_text_ja(text):
    # 一文字ずつ漢字を抜き出す
    kanji_set = set()
    for char in text:
        if ord(char) < 0x100:  # ASCIIコードは無視
            continue
        else:
            kanji_set.add(char)

    # 漢字をリストに変換してソート
    return sorted(list(kanji_set))

if __name__ == "__main__":
    # argparseの設定
    parser = argparse.ArgumentParser(description='Extract Kanji characters from UTF-8 text and generate a dictionary index.')
    parser.add_argument('input', nargs='+', help='Input UTF-8 text files')
    parser.add_argument('-o', '--output', type=str, help='Output JSON file for Kanji characters')
    parser.add_argument('-w', '--wrap', type=int, default=16, help='Number of characters per line for output (default: 16)')
    args = parser.parse_args()

    # 入力ファイルを読み込む
    text = ""
    for input_file in args.input:
        with open(input_file, 'r', encoding='utf-8') as f:
            text += f.read()

    # 漢字を抜き出す
    pickup = pickup_text_ja(text)

    # 16文字で折り返して出力
    if args.output is None:
        # 出力ファイルが指定されていない場合は、標準出力に出力する
        for i in range(0, len(pickup), args.wrap):
            print("".join(pickup[i:i+args.wrap]))
    else:
        # TEXTファイルに出力する
        with open(args.output, 'w', encoding='utf-8') as f:
            for i in range(0, len(pickup), args.wrap):
                f.write("".join(pickup[i:i+args.wrap]) + "\n")

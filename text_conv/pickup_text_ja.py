# utf8のテキストを読んで、使用している漢字を抜き出し、漢字と辞書インデックスを生成する
# 入力は何でもOK、ASCIIコードは無視し漢字のみぬき出す

# 出力形式(JSON)
# ["漢字１文字", "漢字１文字", ...],

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
    parser.add_argument('input', help='Input UTF-8 text file')
    args = parser.parse_args()

    # 入力ファイルを読み込む
    with open(args.input, 'r', encoding='utf-8') as f:
        text = f.read()

    # 漢字を抜き出す
    pickup = pickup_text_ja(text)

    # JSON形式で出力
    print(json.dumps(pickup, ensure_ascii=False))


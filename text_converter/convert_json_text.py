# JSONを読み込みTEXTプロパティ部分をTEXTのインデックスリストに変換する

import argparse
import json
import pickup_text_ja

TARGET_PROPS = ['Text', 'SelItems']

# 再帰でdict中のTextプロパティを抜き出して連結したテキストで返す
def _rec_pickup_texts(json_dict):
    text = ""
    for k, v in json_dict.items():
        if isinstance(v, dict):
            text += _rec_pickup_texts(v)
        elif isinstance(v, list):
            # 処理対象がリストの場合がある
            if k.upper() in map(str.upper, TARGET_PROPS):
                for item in v:
                    if isinstance(item, str):
                        text += item
            # それ以外のリストは再帰で処理
            else:
                for item in v:
                    if isinstance(item, dict):
                        text += _rec_pickup_texts(item)
        elif k.upper() in map(str.upper, TARGET_PROPS):
            if isinstance(v, str):
                text += v
    return text

# 再帰でTextプロパティを置き換える
def _rec_replace_text(json_dict, kanji_list):
    def _convert_text_to_index(text):
        text_index = []
        for char in text:
            # ASCIIを処理
            if ord(char) < 0x80:
                text_index.append(char)
            else:
                if char not in kanji_list:
                    raise ValueError(f"Character '{char}' not found in kanji_list.")
                text_index.append(kanji_list.index(char) + 0x80)
        return text_index

    for k, v in json_dict.items():
        if isinstance(v, dict):
            _rec_replace_text(v, kanji_list)
        elif isinstance(v, list):
            # 処理対象がリストの場合がある
            if k.upper() in map(str.upper, TARGET_PROPS):
                for i in range(len(v)):
                    if isinstance(v[i], str):
                        v[i] = _convert_text_to_index(v[i])
            # それ以外のリストは再帰で処理
            else:
                for item in v:
                    if isinstance(item, dict):
                        _rec_replace_text(item, kanji_list)
        elif k.upper() in map(str.upper, TARGET_PROPS):
            if isinstance(v, str):
                json_dict[k] = _convert_text_to_index(v)


# 再帰でキーを置き換える
def convert_json_text(json_dict, kanji_list):
    # 処理対象文字列を抜き出す
    pickup_text = _rec_pickup_texts(json_dict)

    # TextプロパティをTEXTのインデックスリストに変換する
    _rec_replace_text(json_dict, kanji_list)

    return json_dict


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert JSON TEXT property to TEXT index list.')
    parser.add_argument('input_json', type=str, help='Path to the input JSON file')
    parser.add_argument('-k', '--kanji_list', required=True, type=str, help='Path to the Kanji list file (required)')
    args = parser.parse_args()

    # 入力JSONファイルを読み込む
    with open(args.input_json, 'r', encoding='utf-8') as infile:
        json_data = json.load(infile)

    # TEXTプロパティをTEXTのインデックスリストに変換
    
    with open(args.kanji_list, 'r', encoding='utf-8') as kfile:
        kanji_list = [char for char in "".join(kfile).strip()]

    converted_json = convert_json_text(json_data, kanji_list)

    # 変換後のJSONを出力
    print(json.dumps(converted_json, ensure_ascii=False, indent=4))

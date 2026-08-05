# uiffバイナリファイルを読んで、解析ツリーを表示する
import argparse
from iff import *

# argparseでファイル名を受け取る
parser = argparse.ArgumentParser(description='UIFFファイルを解析する')
parser.add_argument('filename', type=str, help='UIFFファイルのパス')
args = parser.parse_args()

def getUInt16(data, offset):
    return int.from_bytes(data[offset:offset+2], byteorder='little')

# uiffバイナリファイルを読む
with open(args.filename, "rb") as f:
    data = f.read()

# ヘッダのチェック
if data[:4] != b'UIFF':
    raise ValueError("Invalid UIFF file")

# サイズの表示
data_size = getUInt16(data, 4)
print("data-size:", data_size)

def parse_chunk(data, size, indent=""):
    offset = 0
    type_count = 0  # 表示調整用

    while(offset < size):
        chunk_type = getUInt16(data, offset)
        chunk_size = getUInt16(data, offset + 2)
        chunk_data = data[offset + 4:offset + 4 + chunk_size]
        offset += 4 + chunk_size

        # Type
        if chunk_type == IFF_TYPE:
            if type_count > 0:
                print()  # separate
            type_count += 1

            type_ = getUInt16(chunk_data, 0)
            subtype = getUInt16(chunk_data, 2)
            match type_:
                case 1:
                    print(f"{indent}Chunk Type: TYPE_WINDOW:{subtype}")
                case 2:
                    print(f"{indent}Chunk Type: TYPE_AREA:{subtype}")
                case 3:
                    print(f"{indent}Chunk Type: TYPE_LABEL:{subtype}")
                case 4:
                    print(f"{indent}Chunk Type: TYPE_SELECT:{subtype}")
                case _:
                    print(f"{indent}Chunk Type: Unknown ({type_}:{subtype})")

            x = getUInt16(chunk_data, 4)
            y = getUInt16(chunk_data, 6)
            w = getUInt16(chunk_data, 8)
            h = getUInt16(chunk_data, 10)
            print(f"{indent}Position: ({x}, {y}), Size: ({w}, {h})")

            continue  # 次のchunkに進む

        # Select
        elif chunk_type == IFF_SELECT:
            sel_rows = getUInt16(chunk_data, 0)
            print(f"{indent}SelRows: {sel_rows}")

            # SEL_ITEMの解析
            sel_offset = 2
            while sel_offset < chunk_size:
                sel_item_type = getUInt16(chunk_data, sel_offset)
                sel_item_size = getUInt16(chunk_data, sel_offset+2)
                if sel_item_type != IFF_SEL_ITEM:
                    raise ValueError(f"Expected SEL_ITEM chunk, got {sel_item_type}")

                sel_str_len = getUInt16(chunk_data, sel_offset+4)
                sel_str_data = chunk_data[sel_offset + 6:sel_offset + 6 + sel_str_len]
                print(f"{indent}SEL_ITEM: {sel_str_data.decode('ascii', 'replace')}")
                sel_offset += 4 + sel_item_size

            continue

        # Events
        elif chunk_type == IFF_EVENTS:
            events = []
            event_count = chunk_size // 2
            for i in range(event_count):
                events.append(getUInt16(chunk_data, i * 2))
            print(f"{indent}Event ID: {events}")

            continue  # 次のchunkに進む

        # Script
        elif chunk_type == IFF_SCRIPT:
            print(f"{indent}Script: {chunk_data.hex()}")

            continue  # 次のchunkに進む

        # Text
        elif chunk_type == IFF_TEXT:
            text_len = getUInt16(chunk_data, 0)
            text_data = chunk_data[2:2 + text_len]
            print(f"{indent}Text: {text_data.decode('ascii', 'replace')}")

            continue  # 次のchunkに進む

        # child
        elif chunk_type == IFF_CHILD:
            print()  # separate
            print(f"{indent}in child chunk:")
            parse_chunk(chunk_data, chunk_size, indent + "  ")  # IFF_CHILDのデータサイズはchunk_sizeバイト

            continue  # 次のchunkに進む

        raise ValueError(f"Unknown chunk type: {chunk_type}({hex(chunk_type)})")

    return offset

parse_chunk(data[6:], getUInt16(data, 4))  # ヘッダの後の最初のchunkを解析する

import os, sys
sys.path.append(os.getcwd())  # カレントディレクトリをパスに追加

# uiffバイナリファイルを読んで、解析ツリーを表示する
import argparse
from compiler.uiff_types import *

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

    while(offset < size):
        chunk_type = getUInt16(data, offset)
        chunk_size = getUInt16(data, offset + 2)
        chunk_data = data[offset + 4:offset + 4 + chunk_size]
        offset += 4 + chunk_size

        # Entry
        if chunk_type == IFF_ENTRY:
            # EnetryHeader
            # ---------------------------------------------
            type_ = getUInt16(chunk_data, 0)
            subtype = getUInt16(chunk_data, 2)

            enable = "Enable" if getUInt16(chunk_data, 4) else "Disable"
            visible = "Visible" if getUInt16(chunk_data, 6) else "Hidden"

            print(f"{indent}Chunk Type: {type_}:{subtype} [{enable}, {visible}]")

            # x,yは32768以上の値を負の値として扱う
            x = getUInt16(chunk_data, 8)
            if x >= 32768:
                x -= 65536
            y = getUInt16(chunk_data, 10)
            if y >= 32768:
                y -= 65536
            w = getUInt16(chunk_data, 12)
            h = getUInt16(chunk_data, 14)
            print(f"{indent}Pos: ({x}, {y}), Size: ({w}, {h})")

            # payloadsの解析
            if chunk_size > 16:
                parse_chunk(chunk_data[16:], chunk_size - 16, indent)

            print("")  # Entry区切り

            continue  # 次のEntryに進む

        # Select
        elif chunk_type == IFF_SELECT:
            sel_rows = getUInt16(chunk_data, 0)
            print(f"{indent}SelRows: {sel_rows}")

            item_num = getUInt16(chunk_data, 2)

            # SEL_ITEMの解析
            sel_offset = 4
            sel_items = []
            while sel_offset < chunk_size:
                sel_item_type = getUInt16(chunk_data, sel_offset)
                sel_item_size = getUInt16(chunk_data, sel_offset+2)
                if sel_item_type != IFF_TEXT:
                    raise ValueError(f"Expected SEL_ITEM chunk, got {sel_item_type}")

                sel_str_len = getUInt16(chunk_data, sel_offset+4)
                sel_str_data = chunk_data[sel_offset + 6:sel_offset + 6 + sel_str_len]
                sel_items.append(sel_str_data.decode('ascii', 'replace'))
                sel_offset += 4 + sel_item_size
            if len(sel_items) != item_num:
                raise ValueError(f"Expected {item_num} SEL_ITEMs, got {len(sel_items)}")
            print(f"{indent}SelItems: {sel_items}")

            continue

        # Events
        elif chunk_type == IFF_EVENTS:
            events = []
            event_count = chunk_size // 2
            for i in range(event_count):
                events.append(getUInt16(chunk_data, i * 2))
            print(f"{indent}Events: {events}")

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

        # Colors
        elif chunk_type == IFF_COLORS:
            colors = []
            color_count = chunk_size // 4
            for i in range(color_count):
                colors.append(int.from_bytes(chunk_data[i*4:(i+1)*4], byteorder='little'))
            print(f"{indent}Colors: {[f'{color:#010x}' for color in colors]}")

            continue  # 次のchunkに進む

        # childrenの処理
        # *********************************************************************
        # child
        elif chunk_type == IFF_CHILD:
            print(f"{indent}in child chunk:")
            parse_chunk(chunk_data, chunk_size, indent + "  ")  # IFF_CHILDのデータサイズはchunk_sizeバイト

            continue  # 次のchunkに進む

        # チェッカでは警告を出して飛ばす
        else:
            print(f"{indent}🐥 User chunk type: {hex(chunk_type)}({chunk_type}), chunk size: {chunk_size}")
            continue  # 次のchunkに進む

    return offset

parse_chunk(data[6:], getUInt16(data, 4))  # ヘッダの後の最初のchunkを解析する

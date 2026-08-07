# IFF format
# *****************************************************************************
# 2byte: chunk type
# 2byte: chunk size
# chunk data
# 0... 4byte境界にpaddingする

# text format
# 0x80未満: ascii
# 0x80以上: UI漢字テーブル

# header
# UIFF + len(2byte)

# chank typeの定義
# *****************************************************************************
# 基本系
IFF_TYPE = 0x01  # [type_id(2byte)][subtype_id(2byte)][Enable(2byte)][Visible(2byte)][X(2byte)][Y(2byte)][W(2byte)][H(2byte)]
IFF_CHILD = 0x02  # [child chunk][child_chunk]...

# 選択系
IFF_DEF_SELECT = 0x10
IFF_SELECT = IFF_DEF_SELECT + 1  # [SelRows(2byte)][item_num(2byte)][SEL_ITEM][SEL_ITEM]...

# イベント
IFF_DEF_EVENT = 0x20
IFF_EVENTS = IFF_DEF_EVENT + 1  # ブロック受信 [event_id(2byte)][event_id(2byte)]...
IFF_LISTEN = IFF_DEF_EVENT + 2  # リスナー [event_id(2byte)][event_id(2byte)]...  

# データ系
IFF_DEF_DATA = 0x30
IFF_TEXT = IFF_DEF_DATA + 1  # [len(2byte)][data + padding(2)]
IFF_SCRIPT = IFF_DEF_DATA + 2  # [bytecode(padding4)]
IFF_COLORS = IFF_DEF_DATA + 3  # [color(4byte)][color(4byte)]...


# ユーザー定義 chunk type
# *****************************************************************************
IFF_DEF_USER = 0x100  # これ以降はユーザー定義chunk typeとして使用

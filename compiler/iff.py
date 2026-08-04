# IFF format
# *****************************************************************************
# 2byte: chunk type
# 2byte: chunk size
# chunk data
# 0... 4byte境界にpaddingする

# text format
# 0x80未満: ascii
# 0x80以上: UI漢字テーブル

# chank typeの定義
# *****************************************************************************
# 基本系
IFF_TYPE = 0x01  # [TYPE][chunk_size][type_id(1byte)][subtype_id(1byte)][X(2byte)][Y(2byte)][W(2byte)][H(2byte)]

# 選択系
IFF_DEF_SELECT = 0x10
IFF_SELECT = IFF_DEF_SELECT + 1  # [SELECT][chunk_size][SelRows(1byte)][SEL_ITEM][SEL_ITEM]...
IFF_SEL_ITEM = IFF_DEF_SELECT + 2  # [SEL_ITEM][chunk_size][data]

# イベント
IFF_DEF_EVENT = 0x20
# ブロック受信
IFF_EVENTS = IFF_DEF_EVENT + 1  # [EVENTS][chunk_size][event_id(1byte)][event_id(1byte)]...

# データ系
IFF_DEF_DATA = 0x30
IFF_TEXT = IFF_DEF_DATA + 1  # [TEXT][chunk_size][data]
IFF_SCRIPT = IFF_DEF_DATA + 2  # [SCRIPT][chunk_size][bytecode]

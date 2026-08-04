# IFF format
# *****************************************************************************
# 1byte: chunk type
# 2byte: chunk size
# chunk data
# 0... 4byte境界にpaddingする

# text format
# 0x80未満: ascii
# 0x80以上: UI漢字テーブル

# chank typeの定義
# *****************************************************************************
# 基本系
IFF_TYPE = 0x01  # [TYPE][chunk_size][type_id(2byte)]
IFF_ID = 0x02  # [ID][chunk_size][id(1byte)]
IFF_CHILDREN = 0x03  # [CHILDREN][chunk_size][chiled][child]...
IFF_TEXT = 0x04  # [TEXT][chunk_size][text format]
IFF_SCRIPT = 0x05  # [SCRIPT][chunk_size][script(bytecode)]
IFF_EVENTS = 0x06  # [EVENTS][chunk_size][event_id(2byte)][event_id(2byte)]...

# 座標系
IFF_DEF_AREA = 0x10
IFF_X = IFF_DEF_AREA + 1  # [X][chunk_size][x(2byte)]
IFF_Y = IFF_DEF_AREA + 2  # [Y][chunk_size][y(2byte)]
IFF_W = IFF_DEF_AREA + 3  # [W][chunk_size][w(2byte)]
IFF_H = IFF_DEF_AREA + 4  # [H][chunk_size][h(2byte)]

# 選択系
IFF_DEF_SELECT = 0x20
IFF_ROWS_NUM = IFF_DEF_SELECT + 1  # [ROWS_NUM][chunk_size][rows num(1byte)]
IFF_EVENTS = IFF_DEF_SELECT + 2  # [EVENTS][chunk_size][event_id(2byte)][event_id(2byte)]...
IFF_CLOSE_IDS = IFF_DEF_SELECT + 3  # [CLOSE_ID][chunk_size][id(1byte)][id(1byte)]...
IFF_ITEMS = IFF_DEF_SELECT + 4  # [ITEMS][chunk_size][ITEM][ITEM]...
IFF_ITEM = IFF_DEF_SELECT + 5  # [ITEM][chunk_size][text format]

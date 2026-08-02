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
TYPE = 0x01  # [TYPE][chunk_size][type_id(2byte)]
ID = 0x02  # [ID][chunk_size][id(1byte)]
CHILDREN = 0x03  # [CHILDREN][chunk_size][chiled][child]...
TEXT = 0x04  # [TEXT][chunk_size][text format]
SCRIPT = 0x05  # [SCRIPT][chunk_size][script(bytecode)]

# 座標系
DEF_AREA = 0x10
X = DEF_AREA + 1  # [X][chunk_size][x(2byte)]
Y = DEF_AREA + 2  # [Y][chunk_size][y(2byte)]
W = DEF_AREA + 3  # [W][chunk_size][w(2byte)]
H = DEF_AREA + 4  # [H][chunk_size][h(2byte)]

# 選択系
DEF_SELECT = 0x20
ROWS_NUM = DEF_SELECT + 1  # [ROWS_NUM][chunk_size][rows num(1byte)]
EVENTS = DEF_SELECT + 2  # [EVENTS][chunk_size][event_id(2byte)][event_id(2byte)]...
CLOSE_ID = DEF_SELECT + 3  # [CLOSE_ID][chunk_size][id(1byte)]
ITEMS = DEF_SELECT + 4  # [ITEMS][chunk_size][ITEM][ITEM]...
ITEM = DEF_SELECT + 5  # [ITEM][chunk_size][text format]

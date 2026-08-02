# IFF format
# 1byte: chunk type
# 2byte: chunk size
# chunk data
# 0... 4byte境界にpaddingする

# 基本系
TYPE = 0x01
ID = 0x02
CHILDREN = 0x03
TEXT = 0x04
SCRIPT = 0x05

# 座標系
DEF_AREA = 0x10
X = DEF_AREA + 1
Y = DEF_AREA + 2
W = DEF_AREA + 3
H = DEF_AREA + 4

# 選択系
DEF_SELECT = 0x20
ROWS_NUM = DEF_SELECT + 1
EVENTS = DEF_SELECT + 2
CLOSE_ID = DEF_SELECT + 3

# メモリ
VM = [0] * 256

# アドレス定義
# *********************************************************
# エラー終了時のアドレス
ADDR_ERROR = 0xFF

# 追加の専用レジスタを定義
VM_EVENT = 1
VM_SELECT_NO = 2
VM_NOTIFY = 3

# 以下自由に
VM_FREE = 16


# イベント定義
# *********************************************************
# システム固定イベントコード
EVENT_KEY = 0x10
EVENT_KEY_START = EVENT_KEY | 1
EVENT_KEY_SELECT = EVENT_KEY | 2
EVENT_KEY_A = EVENT_KEY | 3
EVENT_KEY_B = EVENT_KEY | 4
EVENT_KEY_LEFT = EVENT_KEY | 5
EVENT_KEY_RIGHT = EVENT_KEY | 6
EVENT_KEY_UP = EVENT_KEY | 7
EVENT_KEY_DOWN = EVENT_KEY | 8
EVENT_WIN_CLOSE = 25


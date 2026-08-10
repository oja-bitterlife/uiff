# UIFF
( 厂˙ω˙ )厂うぃっふー

UIをIFF(Interchange File Format)形式のバイナリで扱うためのコンバーター

## 使い方

```bash
usage: uiff_conv_test.py [-h] [-def DEFINE] input_file

Convert UIFF to JSON

positional arguments:
  input_file            Input UIFF file

options:
  -h, --help            show this help message and exit
  -def, --define DEFINE
                        Define JSON files [複数指定可]
```


Define JSON
```json
{
  "SubType": {
    "TITLE_START": 1,
    "TITLE_SPEED": 2
  },
  "Event": {
    "EVENT_KEY": 16,
    "EVENT_KEY_START": 17,
    "EVENT_KEY_SELECT": 18,
  }
```

基本的にはPropertyと同じ名前の置換用辞書を作ってください。


## 実装済みチャンク

### チャンク部の構成

[chank_id(2byte)][payload_size(2byte)][payload...]

### 定義済みchunk_id

```
# 基本系
UIFF_ENTRY = 0x01
  # [type_id(2byte)][subtype_id(2byte)][Enable(2byte)][Visible(2byte)]
  # [X(2byte)][Y(2byte)][W(2byte)][H(2byte)]
  # [recv_event_id(2byte)]  # Runtime用。受信したイベントID
  # [properties...]
UIFF_CHILD = 0x02  # [child chunk][child_chunk]...

# 選択系
UIFF_DEF_SELECT = 0x10
UIFF_SELECT_INFO = UIFF_DEF_SELECT + 1  # [SelRows(2byte)][item_num(2byte)][SEL_ITEM][SEL_ITEM]...

# イベント
UIFF_DEF_EVENT = 0x20
UIFF_EVENTS = UIFF_DEF_EVENT + 1  # ブロック受信 [event_id(2byte)][event_id(2byte)]...
UIFF_LISTEN = UIFF_DEF_EVENT + 2  # リスナー [event_id(2byte)][event_id(2byte)]...  

# データ系
UIFF_DEF_DATA = 0x30
UIFF_TEXT = UIFF_DEF_DATA + 1  # [len(2byte)][data + padding(2)]
UIFF_SCRIPT = UIFF_DEF_DATA + 2  # [bytecode(padding4)]
UIFF_COLORS = UIFF_DEF_DATA + 3  # [color(4byte)][color(4byte)]...

# ユーザー定義 chunk type
UIFF_DEF_USER = 0x100  # これ以降はユーザー定義chunk typeとして使用
```

スクリプト部分はpyvmでpythonスクリプトをByteCodeにコンパイルされます。

ColorはFG,BG用に複数入る形で用意してます。

### 定義済みProperty

- Type
  - ID(str)
  - 定義済みID
    - TYPE_LAYOUT
    - TYPE_WINDOW
    - TYPE_LABEL
    - TYPE_SELECT
- SubType
  - int or ID(str)
- children
  - child components
- Enable
  - bool
- Visible
  - bool
- X,Y,W,H
  - int
  - offset from parent
- Popup
  - bool
  - x,y,w,hの直接設定
- Extend
  - bool
  - 親より大きい場合x,y,w,hが拡張されます
- AlignLeft,AlignCenterX,AlignRight,AlignTop,AlignCenterY,AlignBottom
  - bool
- Colors
  - int Array
- Events
  - int or ID(str) Array
- SelRows
  - int
- SelItems
  - text Array
- Script
  - PYVM Script

## 拡張の仕方

追加のPropertyが欲しい場合は`compiler/uiff_conv`をimportして、DispatchTreeを拡張するか、そのまま使用してDispatcherを追加してください。

`MyProp`というプロパティを追加する例

YAML
```yaml
- Type: TYPE_LAYOUT
  MyProp: 0x1234  # 追加
  W: 30
  H: 20
```

Python
```python
from compiler.uiff_comv import DispatchTree, DispatcherBase

# ディスパッチャの作成
class MyDispatcher(DispatcherBase):
  def get_dispatch_name(self):
      return "MyProp"

  def get_chunk(self, type_info, props, define_data):
      # ユーザー定義チャンク(0x1000)で、numを書き込む
      num = props.get(self.get_dispatch_name(), 0)
      return self.create_chunk_buf(0x1000, num.to_bytes(2, byteorder='little'))

# ディスパッチャを登録してUIFFバイナリを出力
root = DispatchTree(ui_data, define_dict)
root.add_prop_dispatcher(MyDispatcher)
root.print_uiff()
```

ユーザー定義プロパティはチェッカーを通すと`User chunk type`として表示されます

```
  Chunk Type: 1:0
  Position: (0, 0), Size: (30, 20)
  🐥 User chunk type: 0x1000(4096), chunk size: 2
```


特殊なType用に`add_type_dispatcher`も用意していますが、ほとんどの場合プロパティを増やすだけでいけると思います。

## サンプル

YAML. キーは大文字小文字どちらでもOK
```yaml
Type: TYPE_WINDOW
W: 30
H: 20
Colors: [0xffffff, 0x80c0ff]
Events: [EVENT_WIN_CLOSE]
children:
- Type: TYPE_WINDOW  # タイトルロゴ
  W: 20
  Y: 4
  H: 4
  Colors: [0xffffff, 0xffffffff]
  AlignCenterX: true
- Type: TYPE_LAYOUT  # スタートメニュー
  X: 0
  Y: 10
  W: 30
  Popup: true
  children:
  - Type: TYPE_SELECT
    SubType: TITLE_START
    X: 10
    W: 10
    H: 2
    SelRows: 1  # 縦並び
    SelItems: ["START", "CONTINUE"]
    Events: [EVENT_KEY_UP, EVENT_KEY_DOWN, EVENT_KEY_START]
    Script: |-
      from assets.vm import *
      def main():
        if VM[VM_EVENT] == EVENT_KEY_START:
          VM[VM_NOTIFY] = EVENT_WIN_CLOSE
          match VM[VM_SELECT_NO]:
            case 0:  # START
              return 1
            case _:  # CONTINUE
              return 2
- Type: TYPE_LAYOUT  # メッセージスピード
  Y: 15
  W: 30
  H: 20
  Popup: true
  children:
  - Type: TYPE_LABEL
    AlignCenterX: true
    Text: "-MESSAGE SPEED-"
    W: 15
    H: 1
  - Type: TYPE_SELECT
    SubType: TITLE_SPEED
    AlignCenterX: true
    Y: 2
    W: 20
    H: 1
    SelItems: ["SLOW", "NORMAL", "FAST"]
    Events: [EVENT_KEY_LEFT, EVENT_KEY_RIGHT]
```

UIFF Binary
```
55 49 46 46 62 01 01 00 5E 01 02 00 00 00 01 00 01 00 00 00 00 00 1E 00 14 00 00 00 33 00 08 00 FF FF FF 00 FF C0 80 00 21 00 02 00 19 00 02 00 36 01 01 00 1E 00 02 00 00 00 01 00 01 00 05 00 04 00 14 00 04 00 00 00 33 00 08 00 FF FF FF 00 FF FF FF FF 01 00 84 00 01 00 00 00 01 00 01 00 00 00 0A 00 1E 00 FF 7F 00 00 02 00 6E 00 01 00 6A 00 04 00 01 00 01 00 01 00 0A 00 0A 00 0A 00 02 00 00 00 11 00 1E 00 01 00 02 00 31 00 08 00 05 00 53 54 41 52 54 00 31 00 0A 00 08 00 43 4F 4E 54 49 4E 55 45 21 00 06 00 17 00 18 00 11 00 32 00 28 00 02 01 01 02 11 20 00 11 24 00 02 19 02 03 04 02 02 01 05 02 00 20 00 11 20 00 02 01 00 10 23 00 02 02 00 08 02 00 00 00 01 00 88 00 01 00 00 00 01 00 01 00 00 00 0F 00 1E 00 14 00 00 00 02 00 72 00 01 00 28 00 03 00 00 00 01 00 01 00 07 00 0F 00 0F 00 01 00 00 00 31 00 12 00 0F 00 2D 4D 45 53 53 41 47 45 20 53 50 45 45 44 2D 00 01 00 42 00 04 00 02 00 01 00 01 00 05 00 11 00 14 00 01 00 00 00 11 00 24 00 FF 7F 03 00 31 00 06 00 04 00 53 4C 4F 57 31 00 08 00 06 00 4E 4F 52 4D 41 4C 31 00 06 00 04 00 46 41 53 54 21 00 04 00 15 00 16 00
```

逆アセンブルチェック
```
data-size: 354
Chunk Type: 2:0 [Enable, Visible]
Pos: (0, 0), Size: (30, 20)
Colors: ['0x00ffffff', '0x0080c0ff']
Events: [25]
in child chunk:
  Chunk Type: 2:0 [Enable, Visible]
  Pos: (5, 4), Size: (20, 4)
  Colors: ['0x00ffffff', '0xffffffff']

  Chunk Type: 1:0 [Enable, Visible]
  Pos: (0, 10), Size: (30, 32767)
  in child chunk:
    Chunk Type: 4:1 [Enable, Visible]
    Pos: (10, 10), Size: (10, 2)
    SelRows: 1
    SelItems: ['START', 'CONTINUE']
    Events: [23, 24, 17]
    Script: 02010102112000112400021902030402020105020020001120000201001023000202000802000000


  Chunk Type: 1:0 [Enable, Visible]
  Pos: (0, 15), Size: (30, 20)
  in child chunk:
    Chunk Type: 3:0 [Enable, Visible]
    Pos: (7, 15), Size: (15, 1)
    Text: -MESSAGE SPEED-

    Chunk Type: 4:2 [Enable, Visible]
    Pos: (5, 17), Size: (20, 1)
    SelRows: 32767
    SelItems: ['SLOW', 'NORMAL', 'FAST']
    Events: [21, 22]
```
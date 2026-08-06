# UIFF
( 厂˙ω˙ )厂うぃっふー

UIをIFF(Interchange File Format)形式のバイナリで扱うためのコンバーター

## 予定

相対座標、アライメントの解決を、UIFFのコンバート時に行う

絶対座標指定Type(相対座標のリセット)を作る

## 実装済み

たぶんそのまま再生させるだけならもうイケル

- IFF_TYPE

    [type_id(2byte)][subtype_id(2byte)][X(2byte)][Y(2byte)][W(2byte)][H(2byte)]

- IFF_CHILD = 0x02

    [child chunk][child_chunk]...

- IFF_SELECT

    [SelRows(2byte)][IFF_TEXT][IFF_TEXT]...

- IFF_EVENTS

    [event_id(2byte)][event_id(2byte)]...

- IFF_TEXT

    [len(2byte)][data + padding(2)]

- IFF_SCRIPT

    [bytecode]

    スクリプト部分はpyvmでpythonスクリプトをByteCodeにコンパイル。

- IFF_COLORS

  [color(4byte)][color(4byte)]...

  FG,BG用に複数入る形で用意

## サンプル

YAML
```yaml
- Type: TYPE_WINDOW
  W: 8
  H: 3
  Events: [EVENT_WIN_CLOSE]
  children:
  - Type: TYPE_AREA
    W: 6  # 幅を決めないとAlignが効かない
    AlignCenterX: true
    children:
    - Type: TYPE_AREA
    - Type: TYPE_AREA
      Y: 2
      W: 2
      AlignCenterX: true
      children:
      - Type: TYPE_SELECT
        SubType: SEL_START
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
    - Type: TYPE_LABEL
      Text: "-MESSAGE SPEAD-"
      X: 2
      Y: 2
    - Type: TYPE_SELECT
      SubType: SEL_SPEED
      X: 1 
      Y: 2
      SelItems: ["SLOW", "NORMAL", "FAST"]
      Events: [EVENT_KEY_LEFT, EVENT_KEY_RIGHT]
```

UIFF
```
55 49 46 46 20 01 02 00 1C 01 01 00 0C 00 01 00 00 00 00 00 00 00 08 00 03 00 21 00 02 00 19 00 02 00 02 01 01 00 0C 00 02 00 00 00 00 00 00 00 06 00 FF FF 02 00 EE 00 01 00 0C 00 02 00 00 00 00 00 00 00 FF FF FF FF 01 00 0C 00 02 00 00 00 00 00 02 00 02 00 FF FF 02 00 66 00 01 00 0C 00 04 00 01 00 00 00 00 00 FF FF FF FF 11 00 1C 00 01 00 12 00 08 00 05 00 53 54 41 52 54 00 12 00 0A 00 08 00 43 4F 4E 54 49 4E 55 45 21 00 06 00 17 00 18 00 11 00 32 00 28 00 02 01 01 02 11 20 00 11 24 00 02 19 02 03 04 02 02 01 05 02 00 20 00 11 20 00 02 01 00 10 23 00 02 02 00 08 02 00 00 00 01 00 0C 00 03 00 00 00 02 00 02 00 FF FF FF FF 31 00 12 00 0F 00 2D 4D 45 53 53 41 47 45 20 53 50 45 41 44 2D 00 01 00 0C 00 04 00 02 00 01 00 02 00 FF FF FF FF 11 00 22 00 FF 7F 12 00 06 00 04 00 53 4C 4F 57 12 00 08 00 06 00 4E 4F 52 4D 41 4C 12 00 06 00 04 00 46 41 53 54 21 00 04 00 15 00 16 00 00 00
```

解析チェック
```
data-size: 288

in child chunk:
  Chunk Type: TYPE_WINDOW:0
  Position: (0, 0), Size: (8, 3)
  Event ID: [25]

  in child chunk:
    Chunk Type: TYPE_AREA:0
    Position: (0, 0), Size: (6, 65535)

    in child chunk:
      Chunk Type: TYPE_AREA:0
      Position: (0, 0), Size: (65535, 65535)

      Chunk Type: TYPE_AREA:0
      Position: (0, 2), Size: (2, 65535)

      in child chunk:
        Chunk Type: TYPE_SELECT:1
        Position: (0, 0), Size: (65535, 65535)
        SelRows: 1
        SEL_ITEM: ['START', 'CONTINUE']
        Event ID: [23, 24, 17]
        Script: 02010102112000112400021902030402020105020020001120000201001023000202000802000000

      Chunk Type: TYPE_LABEL:0
      Position: (2, 2), Size: (65535, 65535)
      Text: -MESSAGE SPEAD-

      Chunk Type: TYPE_SELECT:2
      Position: (1, 2), Size: (65535, 65535)
      SelRows: 32767
      SEL_ITEM: ['SLOW', 'NORMAL', 'FAST']
      Event ID: [21, 22]
```
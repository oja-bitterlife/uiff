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

    [SelRows(2byte)][SEL_ITEM][SEL_ITEM]...

- IFF_SEL_ITEM

    [len][data + padding(2)]

- IFF_EVENTS

    [event_id(2byte)][event_id(2byte)]...

- IFF_TEXT

    [len(2byte)][data + padding(2)]

- IFF_SCRIPT

    [bytecode]

    スクリプト部分はpyvmでpythonスクリプトをByteCodeにコンパイル。

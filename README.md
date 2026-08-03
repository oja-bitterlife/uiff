# UIFF
( 厂˙ω˙ )厂うぃっふー

UIをIFF(Interchange File Format)形式のバイナリで扱うためのコンバーター

## 予定

スクリプト部分は別途コンパイラを用意してバイナリで置換する。
現在はpyvmでpythonスクリプトをByteCodeにコンパイルする予定。

yamluiのときは実行時Alignmentを実装したけど今回は組み込み向けなので絶対座標のみで
相対座標、アライメントの解決は、UIFFのコンバート時に行う

# pyvm

Pythonスクリプトを小さな独自バイトコードへ変換し、組み込み向けVMで実行するためのプロジェクトです。

実行系をSwiftで用意しており、GBA向けにビルドすると4.2KB程度になります。

## 目的

- Pythonの一部構文を独自バイトコードへコンパイルする
- 組み込み向けに小さいメモリフットプリントで実行する
- ホスト環境で検証しつつ、最終的に組み込みターゲットへ移植する

## 使い方

```bash
usage: pyvm_bc.py [-h] [-o OUTPUT_FILE] input_file

Compile Python code to stack-machine bytecode.

positional arguments:
  input_file            Path to the input Python file.

options:
  -h, --help            show this help message and exit
  -o, --output_file OUTPUT_FILE
                        Path to the output bytecode file (optional).
```

`-o`でファイル名を指定するとバイナリファイル出力、なければ標準出力にHexで出力します。

## サンプル

組み込みUI向けスクリプトで、決定キーが押された時に選択されているアイテムによってReturnを変化させる

```python
# 定数定義ファイルの読み込み
from assets.vm import *

# mainから開始になります
def main():
    # Test用状態設定
    VM[VM_EVENT] = EVENT_KEY_START
    VM[VM_SELECT_NO] = 2

    if VM[VM_EVENT] == EVENT_KEY_A or VM[VM_EVENT] == EVENT_KEY_START:
        match VM[VM_SELECT_NO]:
            case 0:
                return 1  # START
            case 1:
                return 2  # CONTINUE
            case _:
                return -1  # INVALID SELECTION

    return 0  # No Select
```

出力

```bash
$ task data_ck
02 11 02 01 04 02 02 02 02 04 02 01 01 02 13 20 00 02 01 01 02 11 20 00 22 11 43 00 02 02 01 05 02 00 20 00 11 2D 00 02 01 00 10 42 00 05 02 01 20 00 11 3B 00 02 02 00 10 42 00 02 01 02 00 07 31 00 08 02 00 00 02 00 00
```

実行

```bash
$ task run
0: PUSHB 17
2: PUSHB 1
4: POPA VM[1] <= 17
5: PUSHB 2
7: PUSHB 2
9: POPA VM[2] <= 2
10: PUSHB 1
12: PUSHA 17 from VM[1]
13: PUSHB 19
15: CMP 17 == 19 => 0
17: PUSHB 1
19: PUSHA 17 from VM[1]
20: PUSHB 17
22: CMP 17 == 17 => 1
24: OR 0 | 1 => 1
25: JZ 1: pass
28: PUSHB 2
30: PUSHA 2 from VM[2]
31: DUP 2
32: PUSHB 0
34: CMP 2 == 0 => 0
36: JZ 0: jump to 45
45: DUP 2
46: PUSHB 1
48: CMP 2 == 1 => 0
50: JZ 0: jump to 59
59: PUSHB 1
61: PUSHB 0
63: SWP [1, 0] => [0, 1]
64: SUB 0 - 1 => 65535
65: HALT
return: 65535
Stack max usage: 3 / 64
```

VM[VM_EVENT] が `EVENT_KEY_START` なので ifの中に入り、`VM[VM_SELECT_NO]` が2なので `-1(0xffff)` が返ります

## 補足

Pythonスクリプトでは、関数や例外は使用できません。

mainの中では変数定義ができません。VM(実機メモリ)を使ってください。

for文は `for VM[???] in [list or tuple]` の形式のみ使えます。iter部分は`list or tuple`であれば変数でもOK。


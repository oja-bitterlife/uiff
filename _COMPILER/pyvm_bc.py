import argparse
import ast
import os

# メモリ用定数
MEMORY_ARRAY = "VM"  # メモリ配列の名前
ADDR_ERROR_L  = 0xFF
ADDR_ERROR_H  = 0xFF
ADDR_ERROR  = (ADDR_ERROR_L, ADDR_ERROR_H<<8)  # エラー時のジャンプ先アドレス (0xFFFF)

# 定数定義
# *****************************************************************************
# スタックマシン用のオペコード
OP_HALT     = 0x00  # 終了
OP_PUSHA    = 0x01  # スタックにVM[<address>] をプッシュ
OP_PUSHB    = 0x02  # スタックにByteをプッシュ
OP_PUSHW    = 0x03  # スタックにWordをプッシュ
OP_POPA     = 0x04  # スタックからVM[<address>] にポップ
OP_DUP      = 0x05  # スタックトップの値を複製して積む
OP_OVER     = 0x06  # スタックトップの2つ目の値を複製して積む
OP_SWP      = 0x07  # スタックトップの2つの値を入れ替える
OP_DEL      = 0x08  # スタックから値をポップして破棄
OP_JMP      = 0x10
OP_JZ       = 0x11
OP_CMP      = 0x20  # スタックから [左辺, 右辺] をポップして比較し、結果(0 or 1)をプッシュ
OP_AND      = 0x21
OP_OR       = 0x22
OP_XOR      = 0x23
OP_ADD      = 0x30  # スタックから [左辺, 右辺] をポップし、左辺+右辺の結果をプッシュ
OP_SUB      = 0x31
OP_MUL      = 0x32
OP_DIV      = 0x33
OP_MOD      = 0x34

# 比較演算のサブコード
CMP_EQ      = 0x00
CMP_NE      = 0x01
CMP_LT      = 0x02
CMP_LE      = 0x03
CMP_GT      = 0x04
CMP_GE      = 0x05


# ヘルパー
# *****************************************************************************
from functools import wraps
def need_main(func):
    @wraps(func)
    def wrapper(self, node):
        # mainの外であれば、コード生成をせずに単に子ノードを辿るだけにする
        if not self.has_main:
            return super(type(self), self).generic_visit(node)
        return func(self, node)
    return wrapper


# コンパイラ実装
# *****************************************************************************
class BytecodeCompiler(ast.NodeVisitor):
    def __init__(self, source_code, paths = []):
        for path in paths:
            if path not in sys.path:
                sys.path.append(path)

        self.code = bytearray()
        self.has_main = False  # main関数の中を処理しているかどうかのフラグ

        # 変数定義を実行してグローバル変数に反映
        self.global_ns = {}
        exec(source_code, self.global_ns)
        globals().update(self.global_ns)

        # ASTを解析してバイトコードを生成
        self.visit(ast.parse(source_code))
        self.code.append(OP_HALT)

        # 4byte境界にパディング
        while len(self.code) % 4 != 0:
            self.code.append(0x00)

    # デフォルト動作
    # *****************************************************************************
    def generic_visit(self, node):
        if self.has_main:
            raise NotImplementedError(f"Unsupported AST node: {type(node).__name__}")
        super().generic_visit(node)


    # メイン関数
    # *****************************************************************************
    def visit_FunctionDef(self, node):
        if node.name == "main":
            if self.has_main:
                raise Exception("Multiple 'main' functions are not allowed.")
            self.has_main = True

            for stmt in node.body:
                self.visit(stmt)

            # メイン終了時rerunがない場合は0を返す
            self.code.extend([OP_PUSHB, 0])

        else:
            # 関数は使えないので、エラーを出す
            raise NotImplementedError(f"Function '{node.name}' is not supported.")

    def visit_Return(self, node):
        if node.value is None:
            # 何もなければ0をプッシュして終了
            self.code.extend([OP_PUSHB, 0])
        else:
            # 返り値を評価してスタックに積む
            self.visit(node.value)

        # mainしかないのでreturnされたら終了
        self.code.append(OP_HALT)


    # 定数・変数
    # *****************************************************************************
    @need_main
    def visit_Constant(self, node):
        val = int(node.value)
        if(val & 0xFF00) == 0:
            self.code.extend([OP_PUSHB, val & 0xFF])
        else:
            self.code.extend([OP_PUSHW, val & 0xFF, (val >> 8) & 0xFF])

    @need_main
    def visit_Name(self, node):
        # mainの中では新たに変数を作れない
        if node.id not in globals():
            raise NotImplementedError(f"Variable '{node.id}' is not supported.")

        val = globals().get(node.id)
        if(val & 0xFF00) == 0:
            self.code.extend([OP_PUSHB, val & 0xFF])
        else:
            self.code.extend([OP_PUSHW, val & 0xFF, (val >> 8) & 0xFF])

    # VM[index] の値をロードしてスタックに積む
    @need_main
    def visit_Subscript(self, node):
        if not isinstance(node.value, ast.Name) or node.value.id != MEMORY_ARRAY:
            raise NotImplementedError(f"Only {MEMORY_ARRAY}[] subscript is supported.")

        # インデックスを評価してスタックに積む
        self.visit(node.slice)

        # スタックトップのインデックスに対応するメモリ値をロード
        self.code.append(OP_PUSHA)


    # 演算子
    # *****************************************************************************
    # 代入文: VM[<address>] = value
    def visit_Assign(self, node):
        # 左辺がVM[<address>]であることを確認
        left_is_VM = isinstance(node.targets[0], ast.Subscript) and isinstance(node.targets[0].value, ast.Name) and node.targets[0].value.id == MEMORY_ARRAY

        # mainの外であれば、コード生成をせずに単に子ノードを辿るだけにする
        if not self.has_main:
            # VMに値を入れてはいけない(VMは実機メモリなのでPythonでは入らない)
            if left_is_VM:
                raise NotImplementedError(f"Assignment to {MEMORY_ARRAY}[] is not supported outside of main.")

            # 代入先がVMでなければ、generic_visitに任せる
            return super(type(self), self).generic_visit(node)

        # mainの中であれば、左辺はVM[<address>]でなければならない(変数は作れない)
        if not left_is_VM:
            raise NotImplementedError(f"Only assignment to {MEMORY_ARRAY}[] is supported.")

        # 値を先に評価 (スタックに積まれる)
        self.visit(node.value)

        # POPA用のaddressを直前で評価し、先に積んだ値をVM[<address>]にポップ
        self.visit(node.targets[0].slice)
        self.code.append(OP_POPA)

    # 単項演算子
    @need_main
    def visit_UnaryOp(self, node):
        # 値を先に評価 (スタックに積まれる)
        self.visit(node.operand)

        # 演算子に応じたバイトコードを付与
        if isinstance(node.op, ast.USub):
            self.code.extend([OP_PUSHB, 0, OP_SWP, OP_SUB])  # 0 - operand
        elif isinstance(node.op, ast.Invert):
            self.code.extend([OP_PUSHW, 0xFF, 0xFF, OP_XOR])  # ビット反転 (XOR 0xFF)
        elif isinstance(node.op, ast.Not):
            self.code.extend([OP_PUSHB, 0, OP_CMP, CMP_EQ])  # 論理否定 (0なら1、0以外なら0)
        elif isinstance(node.op, ast.UAdd):
            pass  # 単項プラスは何もしない
        else:
            raise NotImplementedError(f"Unsupported unary operator: {type(node.op)}")

    # ニ項演算子
    @need_main
    def visit_BinOp(self, node):
        # 左辺を先に評価 (スタックに積まれる)
        self.visit(node.left)
        # 右辺を後から評価 (スタックに積まれる)
        self.visit(node.right)

        # 演算子に応じたバイトコードを付与
        # （VM側でスタックから [左辺, 右辺] をポップして計算し、結果をプッシュする）
        if isinstance(node.op, ast.BitAnd):
            self.code.append(OP_AND)
        elif isinstance(node.op, ast.BitOr):
            self.code.append(OP_OR)
        elif isinstance(node.op, ast.BitXor):
            self.code.append(OP_XOR)
        elif isinstance(node.op, ast.Add):
            self.code.append(OP_ADD)
        elif isinstance(node.op, ast.Sub):
            self.code.append(OP_SUB)
        elif isinstance(node.op, ast.Mult):
            self.code.append(OP_MUL)
        elif isinstance(node.op, ast.Div):
            self.code.append(OP_DIV)
        elif isinstance(node.op, ast.Mod):
            self.code.append(OP_MOD)
        else:
            raise NotImplementedError(f"Unsupported binary operator: {type(node.op)}")

    # 複合代入演算子 (例: a += 1) を、単純な代入 (a = a + 1) に変換して処理する
    @need_main
    def visit_AugAssign(self, node):
        # binOpに変換する
        bin_op = ast.BinOp(left=node.target, op=node.op, right=node.value)
        assign = ast.Assign(targets=[node.target], value=bin_op)
        self.visit(assign)

    # 論理演算子 (and/or)
    @need_main
    def visit_BoolOp(self, node):
        # 複数の比較が含まれている場合は、and/or のツリーに変換して再帰的に処理する
        if isinstance(node.op, ast.And):
            # 左辺の値を評価
            self.visit(node.values[0])

            # 右辺の値を順に評価
            for value in node.values[1:]:
                self.visit(value)
                self.code.append(OP_AND)

        elif isinstance(node.op, ast.Or):
            # 左辺の値を評価
            self.visit(node.values[0])

            # 右辺の値を順に評価
            for value in node.values[1:]:
                self.visit(value)
                self.code.append(OP_OR)
        else:
            raise NotImplementedError(f"Unsupported boolean operator: {type(node.op)}")


    # 比較
    # *****************************************************************************
    # 複数の比較（例: a < b < c）を、(a < b) and (b < c) の ast.BoolOp に分解するヘルパー
    @need_main
    def desugar_compare(self, node):
        if len(node.ops) == 1:
            return node  # 1つだけならそのまま返す

        comparisons = []
        left = node.left

        for op, right in zip(node.ops, node.comparators):
            # 個別の比較式 (left op right) を作る
            comp = ast.Compare(left=left, ops=[op], comparators=[right])
            comparisons.append(comp)
            # 次の比較のために、今の右辺を次の左辺にする
            left = right

        # comparisons が [ (a < b), (b < c) ] になっているので、
        # これを ast.And でつないだ BoolOp にする
        return ast.BoolOp(op=ast.And(), values=comparisons)

    # 比較演算の処理
    @need_main
    def visit_Compare(self, node):
        # 複数比較が含まれている場合は、and のツリーに変換して再帰的に処理する
        if len(node.ops) > 1:
            desugared_node = self.desugar_compare(node)
            return self.visit(desugared_node)

        # ここから先は「単一の比較 (len(node.ops) == 1)」だけを処理すればOK
        self.visit(node.left)
        self.visit(node.comparators[0])
        
        op = node.ops[0]
        if isinstance(op, ast.Eq): cmp_subcode = CMP_EQ
        elif isinstance(op, ast.NotEq): cmp_subcode = CMP_NE
        elif isinstance(op, ast.Lt): cmp_subcode = CMP_LT
        elif isinstance(op, ast.LtE): cmp_subcode = CMP_LE
        elif isinstance(op, ast.Gt): cmp_subcode = CMP_GT
        elif isinstance(op, ast.GtE): cmp_subcode = CMP_GE
        else: raise NotImplementedError(f"Unsupported operator: {type(op)}")
        
        self.code.extend([OP_CMP, cmp_subcode])


    # 条件分岐
    # *****************************************************************************
    # if 文の処理
    @need_main
    def visit_If(self, node):
        # 条件式の評価
        self.visit(node.test)
        
        # 偽だった場合にジャンプする場所
        else_jump_pos = len(self.code)
        self.code.extend([OP_JZ, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット
        
        # 条件が真のときの本体 (body)
        for stmt in node.body:
            self.visit(stmt)
            
        # else部分を飛ばすJMP
        if node.orelse:
            exit_jump_pos = len(self.code)
            self.code.extend([OP_JMP, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット
        
        # else/elif が始まる場所をパッチ
        self.code[else_jump_pos + 1] = len(self.code)&0xFF
        self.code[else_jump_pos + 2] = (len(self.code)>>8)&0xFF
        
        if node.orelse:
            if len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If):
                self.visit(node.orelse[0])
            else:
                for stmt in node.orelse:
                    self.visit(stmt)
                    
            # 脱出用 JMP のアドレスをパッチ
            self.code[exit_jump_pos + 1] = len(self.code)&0xFF
            self.code[exit_jump_pos + 2] = (len(self.code)>>8)&0xFF

    # if式
    @need_main
    def visit_IfExp(self, node):
        # 条件式の評価
        self.visit(node.test)

        # 偽だった場合にジャンプする場所
        else_jump_pos = len(self.code)
        self.code.extend([OP_JZ, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット

        # 条件が真のときの値を評価してスタックに積む
        self.visit(node.body)

        # else部分を飛ばすJMP
        exit_jump_pos = len(self.code)
        self.code.extend([OP_JMP, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット

        # elseが始まる場所をパッチ
        self.code[else_jump_pos + 1] = len(self.code)&0xFF
        self.code[else_jump_pos + 2] = (len(self.code)>>8)&0xFF

        # 偽のときの値を評価してスタックに積む
        self.visit(node.orelse)

        # 脱出用 JMP のアドレスをパッチ
        self.code[exit_jump_pos + 1] = len(self.code)&0xFF
        self.code[exit_jump_pos + 2] = (len(self.code)>>8)&0xFF


    # match 文の処理
    @need_main
    def visit_Match(self, node):
        # match 文の対象となる値を評価してスタックに積む
        self.visit(node.subject)
        break_jumps = []  # 複数の case の本体が終わった後にジャンプするためのアドレスを保持するリスト

        # 各 case の処理
        for case in node.cases:
            # case _: のときは無条件で case の本体を評価する
            if isinstance(case.pattern, ast.MatchAs) and case.pattern.name is None and case.pattern.pattern is None:
                # case _ の本体を評価
                for stmt in case.body:
                    self.visit(stmt)
                break

            # case のパターン全体を評価してスタックに積む
            self.visit(case.pattern)

            # 比較結果が 0 (False) なら次の case にジャンプする
            next_case_jump_pos = len(self.code)
            self.code.extend([OP_JZ, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット

            # case の本体を評価
            for stmt in case.body:
                self.visit(stmt)

            # case の本体が終わったらbreak 用のジャンプを追加
            break_jumps.append(len(self.code))
            self.code.extend([OP_JMP, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット

            self.code[next_case_jump_pos + 1] = len(self.code)&0xFF
            self.code[next_case_jump_pos + 2] = (len(self.code)>>8)&0xFF

        # case の本体が終わったら、ジャンプ先を修正する
        for pos in break_jumps:
            self.code[pos + 1] = len(self.code)&0xFF
            self.code[pos + 2] = (len(self.code)>>8)&0xFF

        self.code.append(OP_DEL)  # スタックから対象値をポップして破棄

    @need_main
    def visit_MatchValue(self, node):  # case <value> のパターン
        # スタックトップの値を複製して積む (対象値を保持するため)
        self.code.append(OP_DUP)

        # パターンを評価してスタックに積む
        self.visit(node.value)

        # スタックから [対象値, パターン値] をポップして比較し、結果をスタックに積む
        self.code.extend([OP_CMP, CMP_EQ])

    @need_main
    def visit_MatchAs(self, node):  # case <name> のパターン
        # スタックトップの値を複製して積む (対象値を保持するため)
        self.code.append(OP_DUP)

        # match 文の case のパターン値を評価してスタックに積む
        if node.name is not None:
            # 変数名が指定されている場合は、その変数に値を代入する
            val = globals()[node.name]
            if(val & 0xFF00) == 0:
                self.code.extend([OP_PUSHB, val & 0xFF])
            else:
                self.code.extend([OP_PUSHW, val & 0xFF, (val >> 8) & 0xFF])
        else:
            # 変数名が指定されていない場合は、単純にパターン値を評価する
            self.visit(node.pattern)

        # スタックから [対象値, パターン値] をポップして比較し、結果をスタックに積む
        self.code.extend([OP_CMP, CMP_EQ])

    @need_main
    def visit_MatchOr(self, node):  # case <pattern1> | <pattern2> | ... のパターン
        # 最初のパターンを評価してスタックに積む
        self.visit(node.patterns[0])  # [対象値, 評価1]

        # match 文の case のシーケンスパターンを評価してスタックに積む
        for i, val in enumerate(node.patterns[1:]):
            self.code.append(OP_OVER)  # [対象値, 評価1, 複製]
            self.visit(val)  # [対象値, 評価1, 複製, 評価2]
            self.code.append(OP_SWP)  # [対象値, 評価1, 評価2, 複製]
            self.code.append(OP_DEL)  # [対象値, 評価1, 評価2]
            self.code.append(OP_OR)  # [対象値, OR結果]


    # ループ
    # *****************************************************************************
    # while 文の処理
    @need_main
    def visit_While(self, node):
        # while 文の開始位置を記録
        loop_start_pos = len(self.code)

        # 条件式の評価
        self.visit(node.test)

        # 偽だった場合にジャンプする場所
        exit_jump_pos = len(self.code)
        self.code.extend([OP_JZ, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット

        # while の本体 (body)
        for stmt in node.body:
            self.visit(stmt)

        # ループの先頭に戻るJMP
        self.code.extend([OP_JMP, loop_start_pos&0xFF, (loop_start_pos>>8)&0xFF])

        # 偽だった場合のジャンプ先をパッチ
        self.code[exit_jump_pos + 1] = len(self.code)&0xFF
        self.code[exit_jump_pos + 2] = (len(self.code)>>8)&0xFF

    # for 文の処理
    @need_main
    def visit_For(self, node):
        # 引数はリストかタプルであることを確認
        if isinstance(node.iter, (ast.List, ast.Tuple)):
            items = node.iter.elts
        # グローバル変数がリストかタプルである場合はOK
        elif isinstance(node.iter, ast.Name) and node.iter.id in globals() and isinstance(globals()[node.iter.id], (list, tuple)):
            items = globals()[node.iter.id]
        else:
            raise NotImplementedError("Only for loops over lists or tuples are supported.")

        # リストを一旦スタックに入れる
        for val in reversed(items):
            if isinstance(val, ast.Constant) or isinstance(val, ast.Name):
                self.visit(val)
            # mainの外で定義したリストやタプルにも対応
            elif isinstance(val, int):
                if(val & 0xFF00) == 0:
                    self.code.extend([OP_PUSHB, val & 0xFF])
                else:
                    self.code.extend([OP_PUSHW, val & 0xFF, (val >> 8) & 0xFF])
            else:
                raise NotImplementedError("Only integer values in lists or tuples are supported.")
        self.code.extend([OP_PUSHB, len(items)])  # リストの長さをスタックに積む

        # ループの開始位置を記録
        loop_start_pos = len(self.code)

        # スタックトップの長さを複製
        self.code.append(OP_DUP)

        # ループ終了のジャンプ先を記録
        exit_jump_pos = len(self.code)
        self.code.extend([OP_JZ, ADDR_ERROR_L, ADDR_ERROR_H])  # 仮のジャンプ先をセット

        # 最初の要素を取り出して変数に代入
        self.code.append(OP_SWP)  # 最初の要素をスタックトップに移動
        self.visit(node.target.slice)  # addressをスタックに
        self.code.append(OP_POPA)  # VM[<address>] にポップ

        # forの本体を展開
        for stmt in node.body:
            self.visit(stmt)

        # リストの長さを１つ減らす
        self.code.extend([OP_PUSHB, 1, OP_SUB])  # 右辺を積んでSub

        # ループの先頭に戻るJMP
        self.code.extend([OP_JMP, loop_start_pos&0xFF, (loop_start_pos>>8)&0xFF])

        # 偽だった場合のジャンプ先をパッチ
        self.code[exit_jump_pos + 1] = len(self.code)&0xFF
        self.code[exit_jump_pos + 2] = (len(self.code)>>8)&0xFF

        # for文の最後に、スタックに残っているリストの長さを破棄する
        self.code.append(OP_DEL)


    # モジュール呼び出し用
    # *****************************************************************************
    def get_bytecode(self):
        return self.code

    def print_bytecode(self, separator=" "):
        print(separator.join(f"{byte:02X}" for byte in self.code))


# コマンドライン
# *****************************************************************************
import os, sys
if __name__ == "__main__":
    # ファイル名入力
    arg_parser = argparse.ArgumentParser(description="Compile Python code to stack-machine bytecode.")
    arg_parser.add_argument("input_file", help="Path to the input Python file.")
    arg_parser.add_argument("-o", "--output_file", help="Path to the output bytecode file (optional).")
    args = arg_parser.parse_args()

    sys.path.insert(0, os.getcwd())

    with open(args.input_file, "r") as f:
        bc = BytecodeCompiler(f.read())
        if args.output_file:
            with open(args.output_file, "wb") as out_file:
                out_file.write(bytearray(bc.get_bytecode()))
        else:
            bc.print_bytecode()

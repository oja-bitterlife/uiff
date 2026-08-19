// IRQ関係
// ****************************************************************************
public enum IRQ: UInt32 {
    case VBLANK = 0
    case HBLANK = 1
    case RASTER = 2
    case TIMER0 = 3
    case TIMER1 = 4
    case TIMER2 = 5
    case TIMER3 = 6
    case SERIAL = 7
    case DMA0 = 8
    case DMA1 = 9
    case DMA2 = 10
    case DMA3 = 11
    case KEYPAD = 12
    case GAMEPAK = 13
}

@_silgen_name("irqInit")
public func irqInit()

@_silgen_name("irqEnable")
private func _irqEnable(_ irq: UInt32)
public func irqEnable(irq: IRQ) {
    _irqEnable(1 << irq.rawValue)
}

@_silgen_name("irqDisable")
private func _irqDisable(_ irq: UInt32)
public func irqDisable(irq: IRQ) {
    _irqDisable(1 << irq.rawValue)
}

@_silgen_name("irqSet")
private func _irqSet(_ irq: UInt32, _ handler: @convention(c) () -> Void)
public func irqSet(irq: IRQ, handler: @convention(c) () -> Void) {
    _irqSet(1 << irq.rawValue, handler)
}

// Input関係
// ****************************************************************************
nonisolated(unsafe) private var current_held: UInt16 = 0
nonisolated(unsafe) private var current_down: UInt16 = 0
nonisolated(unsafe) private var current_up: UInt16 = 0
public enum KEY: UInt16 {
    case A = 0x0001
    case B = 0x0002
    case SELECT = 0x0004
    case START = 0x0008
    case RIGHT = 0x0010
    case LEFT = 0x0020
    case UP = 0x0040
    case DOWN = 0x0080
    case R = 0x0100
    case L = 0x0200
}

// 毎フレームごとに呼ぶ
@_silgen_name("scanKeys")
private func _scanKeys()
public func scanKeys() {
    _scanKeys()
    current_held = _keysHeld()
    current_up = _keysUp()
    current_down = _keysDown()
}

// 押されているボタン状態を取得する
@_silgen_name("keysHeld")
private func _keysHeld() -> UInt16
public func keysHeld() -> UInt16 {
    return current_held
}
public func keyHeld(key: KEY) -> Bool {
    return current_held & key.rawValue != 0
}

// 押された瞬間のボタン状態を取得する
@_silgen_name("keysDown")
private func _keysDown() -> UInt16
public func keysDown() -> UInt16 {
    return current_down
}
public func keyDown(key: KEY) -> Bool {
    return current_down & key.rawValue != 0
}

// 離された瞬間のボタン状態を取得する
@_silgen_name("keysUp")
private func _keysUp() -> UInt16
public func keysUp() -> UInt16 {
    return current_up
}
public func keyUp(key: KEY) -> Bool {
    return current_up & key.rawValue != 0
}

// ロギング
// ****************************************************************************
nonisolated(unsafe) private let REG_DEBUG_STRING = UnsafeMutablePointer<CChar>(
    bitPattern: 0x4FFF600)!
nonisolated(unsafe) private let REG_DEBUG_FLAGS = UnsafeMutablePointer<UInt16>(
    bitPattern: 0x4FFF700)!
nonisolated(unsafe) private let REG_DEBUG_ENABLE = UnsafeMutablePointer<UInt16>(
    bitPattern: 0x4FFF780)!

// mGBAのログレベル定義
public enum LOG_LEVEL: UInt16 {
    case FATAL = 0
    case ERROR = 1
    case WARN = 2
    case INFO = 3
    case DEBUG = 4
}

// mGBAのログに1メッセージを飛ばす関数（ゼロアロケーション）
public func LogPrintPtr(level: LOG_LEVEL, ptr: UnsafePointer<CChar>) {
    // デバッグ機能が有効か最初に一度フラグを立てておく（0xC0DEを書き込むお作法）
    REG_DEBUG_ENABLE.pointee = 0xC0DE

    // レジスタのバッファに文字をコピー
    var idx = 0
    while true {
        let byte = ptr.advanced(by: idx).pointee
        REG_DEBUG_STRING[idx] = byte
        idx += 1
        if byte == 0 {
            break
        }
    }

    // mGBAに「書き込み完了（ログレベル ＋ フラグ 0x100）」を通知する
    // ※ libgbaの mgba.c の実装仕様に準拠
    REG_DEBUG_FLAGS.pointee = level.rawValue | 0x100
}

public func LogPrint(level: LOG_LEVEL, msg: StaticString) {
    msg.withUTF8Buffer { buffer in
        buffer.withMemoryRebound(to: CChar.self) { ptr in
            LogPrintPtr(level: level, ptr: ptr.baseAddress!)
        }
    }
}

import UIFFLib

// ロギング
// ****************************************************************************
nonisolated(unsafe) private let REG_DEBUG_STRING = UnsafeMutablePointer<UInt8>(
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
public func LogPrintPtr(logLv: LOG_LEVEL, ptr: UnsafeMutableRawPointer) {
    // デバッグ機能が有効か最初に一度フラグを立てておく（0xC0DEを書き込むお作法）
    REG_DEBUG_ENABLE.pointee = 0xC0DE

    let ptr = ptr.assumingMemoryBound(to: UInt8.self)

    // レジスタのバッファに文字をコピー
    var idx = 0
    while true {
        REG_DEBUG_STRING[idx] = ptr[idx]
        idx += 1
        if ptr[idx] == 0 {
            break
        }
        if idx >= 255 {
            // 255文字以上は切り捨てる
            break
        }
    }

    // mGBAに「書き込み完了（ログレベル ＋ フラグ 0x100）」を通知する
    REG_DEBUG_FLAGS.pointee = logLv.rawValue | 0x100
}

public func LogPrint(logLv: LOG_LEVEL, msg: StaticString) {
    LogPrintPtr(logLv: logLv, ptr: UnsafeMutableRawPointer(mutating: msg.utf8Start))
}

// ロギングのラッパー。普段使い用
// ------------------------------------------------------------------
public func LogErrorPtr(_ ptr: UnsafeMutableRawPointer) {
    LogPrintPtr(logLv: .ERROR, ptr: ptr)
}
public func LogDebugPtr(_ ptr: UnsafeMutableRawPointer) {
    LogPrintPtr(logLv: .DEBUG, ptr: ptr)
}
public func LogInfoPtr(_ ptr: UnsafeMutableRawPointer) {
    LogPrintPtr(logLv: .INFO, ptr: ptr)
}
public func LogWarnPtr(_ ptr: UnsafeMutableRawPointer) {
    LogPrintPtr(logLv: .WARN, ptr: ptr)
}

public func LogError(_ msg: StaticString) {
    LogPrint(logLv: .ERROR, msg: msg)
}
public func LogDebug(_ msg: StaticString) {
    LogPrint(logLv: .DEBUG, msg: msg)
}
public func LogInfo(_ msg: StaticString) {
    LogPrint(logLv: .INFO, msg: msg)
}
public func LogWarn(_ msg: StaticString) {
    LogPrint(logLv: .WARN, msg: msg)
}

// 画面表示用
public func LogDisp(
    _ msg: StaticString, _ x: Int, _ y: Int, drawFunc: (Int, Int, Int) -> Void
) {
    for i in 0..<msg.utf8CodeUnitCount {
        drawFunc(Int(msg.utf8Start[i]), x + i * 8, y)
    }
}

public func LogDispFill(
    _ msg: StaticString, _ x: Int, _ y: Int, minLen: Int = 0, fill: Int = 0x20,
    drawFunc: (Int, Int, Int) -> Void
) {
    for i in 0..<msg.utf8CodeUnitCount {
        drawFunc(Int(msg.utf8Start[i]), x + i * 8, y)
    }
    for i in msg.utf8CodeUnitCount..<minLen {
        drawFunc(fill, x + i * 8, y)
    }
}

// パレット操作
// ****************************************************************************
public func RGB555(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> UInt16 {
    let r = UInt16(red >> 3)
    let g = UInt16(green >> 3)
    let b = UInt16(blue >> 3)
    return (b << 10) | (g << 5) | r
}

public func MakePalette16(palBlock: Int, no: Int, color: UInt16, isObj: Bool = false) {
    if palBlock < 0 || palBlock >= 16 {
        FatalMsg("Palette block index out of bounds")  // FATAL_MEM_ALIGN
    }
    if no < 0 || no >= 16 {
        FatalMsg("Palette index out of bounds")  // FATAL_MEM_ALIGN
    }
    if isObj {
        PALETTE_MEM.writeUInt16(offset: 512 + palBlock * 32 + no * 2, value: color)
    } else {
        PALETTE_MEM.writeUInt16(offset: palBlock * 32 + no * 2, value: color)
    }
}
public func MakePalette256(no: Int, color: UInt16, isObj: Bool = false) {
    if no < 0 || no >= 256 {
        FatalMsg("Palette index out of bounds")  // FATAL_MEM_ALIGN
    }
    if isObj {
        PALETTE_MEM.writeUInt16(offset: 512 + no * 2, value: color)
    } else {
        PALETTE_MEM.writeUInt16(offset: no * 2, value: color)
    }
}

// フェード
// ****************************************************************************
public enum FADE_TYPE {
    case NONE
    case BLACK_IN
    case BLACK_OUT
    case WHITE_IN
    case WHITE_OUT
}

public struct FADE_GBA {
    private var fadeType: FADE_TYPE = .NONE
    private var fadeAlpha: UInt16 = 0
    private var fadeInSpeed: UInt8 = 0
    private var fadeOutSpeed: UInt8 = 0

    private init() {}  // 外部からのインスタンス化を禁止

    // フェードの初期化。スピードを決めておく
    public mutating func initialize(fadeInSpeed: Int = 16, fadeOutSpeed: Int = 8) {
        self.fadeInSpeed = UInt8(max(0, min(255, fadeInSpeed)))
        self.fadeOutSpeed = UInt8(max(0, min(255, fadeOutSpeed)))
    }

    // フェード開始
    public mutating func startFade(_ fadeType: FADE_TYPE) {
        self.fadeType = fadeType
        self.fadeAlpha = 0

        // 初回分を適用
        self.updateFade()
        self.fadeAlpha = 0
    }

    // フェード更新
    public mutating func updateFade() {
        switch fadeType {
        case .BLACK_IN, .WHITE_IN:
            fadeAlpha = min(fadeAlpha + UInt16(fadeInSpeed), 255)
        case .BLACK_OUT, .WHITE_OUT:
            fadeAlpha = min(fadeAlpha + UInt16(fadeOutSpeed), 255)
        default:
            return
        }

        switch fadeType {
        case .BLACK_IN:
            FADE_GBA.fadeBlack(alpha: 255 - Int(fadeAlpha))
        case .BLACK_OUT:
            FADE_GBA.fadeBlack(alpha: Int(fadeAlpha))
        case .WHITE_IN:
            FADE_GBA.fadeWhite(alpha: 255 - Int(fadeAlpha))
        case .WHITE_OUT:
            FADE_GBA.fadeWhite(alpha: Int(fadeAlpha))
        default:
            break
        }

        // fade終了
        if fadeAlpha >= 255 {
            fadeType = .NONE
        }
    }

    // フェード中かどうか
    public func isFading() -> Bool {
        return fadeType != .NONE
    }

    // フェードの実装（GBAレジスタ操作）
    // --------------------------------------------------------------
    static public func fadeBlack(alpha: Int) {
        let DST = 0x3f  // all
        let BM = 0x3 << 6  // fade black
        WorkMemory(address: UnsafeMutableRawPointer(bitPattern: 0x4000050)!, byteSize: 2)
            .writeUInt16(offset: 0, value: UInt16(DST | BM))
        WorkMemory(address: UnsafeMutableRawPointer(bitPattern: 0x4000054)!, byteSize: 2)
            .writeUInt16(
                offset: 0, value: UInt16(max(0, min(16, alpha * 16 / 255))))
    }

    static public func fadeWhite(alpha: Int) {
        let DST = 0x3f  // all
        let BM = 0x2 << 6  // fade white
        WorkMemory(address: UnsafeMutableRawPointer(bitPattern: 0x4000050)!, byteSize: 2)
            .writeUInt16(offset: 0, value: UInt16(DST | BM))
        WorkMemory(address: UnsafeMutableRawPointer(bitPattern: 0x4000054)!, byteSize: 2)
            .writeUInt16(
                offset: 0, value: UInt16(max(0, min(16, alpha * 16 / 255))))
    }

}

// ランダム
// ****************************************************************************
public struct RANDOM {
    static public let defaultSeed: UInt32 = 20_260_911
    var xorshiftState: UInt32

    public init(seed: UInt32 = RANDOM.defaultSeed) {
        self.xorshiftState = seed
    }

    public mutating func next() -> UInt32 {
        var x = xorshiftState

        // 0はシフトしても0になってしまうのでガード
        if x == 0 {
            x = RANDOM.defaultSeed
        }

        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        xorshiftState = x

        return x
    }

    public mutating func nextInt() -> Int {
        return Int(next() & 0x7fff_ffff)
    }
}

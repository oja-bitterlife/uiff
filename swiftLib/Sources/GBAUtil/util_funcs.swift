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
public func LogPrintPtr(logLv: LOG_LEVEL, msgAddr: UInt) {
    // デバッグ機能が有効か最初に一度フラグを立てておく（0xC0DEを書き込むお作法）
    REG_DEBUG_ENABLE.pointee = 0xC0DE

    let ptr = UnsafePointer<UInt8>(bitPattern: msgAddr)!

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
    msg.withUTF8Buffer { buffer in
        buffer.withMemoryRebound(to: UInt8.self) { ptr in
            LogPrintPtr(logLv: logLv, msgAddr: UInt(bitPattern: ptr.baseAddress!))
        }
    }
}

// ロギングのラッパー。普段使い用
// ------------------------------------------------------------------
public func LogErrorPtr(_ msgAddr: UInt) {
    LogPrintPtr(logLv: .ERROR, msgAddr: msgAddr)
}
public func LogDebugPtr(_ msgAddr: UInt) {
    LogPrintPtr(logLv: .DEBUG, msgAddr: msgAddr)
}
public func LogInfoPtr(_ msgAddr: UInt) {
    LogPrintPtr(logLv: .INFO, msgAddr: msgAddr)
}
public func LogWarnPtr(_ msgAddr: UInt) {
    LogPrintPtr(logLv: .WARN, msgAddr: msgAddr)
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
    case FADE_BLACK_IN
    case FADE_BLACK_OUT
    case FADE_WHITE_IN
    case FADE_WHITE_OUT
}

public struct FADE {
    public var fadeType: FADE_TYPE = .NONE
    public var fadeAlpha: Int = 0
    public var fadeInSpeed: Int = 0
    public var fadeOutSpeed: Int = 0

    // フェードの初期化。スピードを決めておく
    public init(fadeInSpeed: Int = 4, fadeOutSpeed: Int = 4) {
        self.fadeInSpeed = fadeInSpeed
        self.fadeOutSpeed = fadeOutSpeed
    }

    // フェード開始
    public mutating func startFade(_ fadeType: FADE_TYPE) {
        self.fadeType = fadeType
        self.fadeAlpha = 0
    }

    // フェード更新
    public mutating func updateFade() {
        switch fadeType {
        case .FADE_BLACK_IN, .FADE_WHITE_IN:
            fadeAlpha = max(0, min(fadeAlpha + fadeInSpeed, 255))
        case .FADE_BLACK_OUT, .FADE_WHITE_OUT:
            fadeAlpha = max(0, min(fadeAlpha + fadeOutSpeed, 255))
        default:
            return
        }

        switch fadeType {
        case .FADE_BLACK_IN:
            FADE.fadeBlack(alpha: 255 - fadeAlpha)
        case .FADE_BLACK_OUT:
            FADE.fadeBlack(alpha: fadeAlpha)
        case .FADE_WHITE_IN:
            FADE.fadeWhite(alpha: 255 - fadeAlpha)
        case .FADE_WHITE_OUT:
            FADE.fadeWhite(alpha: fadeAlpha)
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
        WorkMemory(address: 0x4000050, byteSize: 2).writeUInt16(offset: 0, value: UInt16(DST | BM))
        WorkMemory(address: 0x4000054, byteSize: 2).writeUInt16(
            offset: 0, value: UInt16(max(0, min(16, alpha * 16 / 255))))
    }

    static public func fadeWhite(alpha: Int) {
        let DST = 0x3f  // all
        let BM = 0x2 << 6  // fade white
        WorkMemory(address: 0x4000050, byteSize: 2).writeUInt16(offset: 0, value: UInt16(DST | BM))
        WorkMemory(address: 0x4000054, byteSize: 2).writeUInt16(
            offset: 0, value: UInt16(max(0, min(16, alpha * 16 / 255))))
    }

}

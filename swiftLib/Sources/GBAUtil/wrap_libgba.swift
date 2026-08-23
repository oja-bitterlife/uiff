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
public func keyHeld(_ key: KEY) -> Bool {
    return current_held & key.rawValue != 0
}

// 押された瞬間のボタン状態を取得する
@_silgen_name("keysDown")
private func _keysDown() -> UInt16
public func keysDown() -> UInt16 {
    return current_down
}
public func keyDown(_ key: KEY) -> Bool {
    return current_down & key.rawValue != 0
}

// 離された瞬間のボタン状態を取得する
@_silgen_name("keysUp")
private func _keysUp() -> UInt16
public func keysUp() -> UInt16 {
    return current_up
}
public func keyUp(_ key: KEY) -> Bool {
    return current_up & key.rawValue != 0
}

import UIFFLib

public func RGB555(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> UInt16 {
    let r = UInt16(red & 0x1F)
    let g = UInt16(green & 0x1F)
    let b = UInt16(blue & 0x1F)
    return (b << 10) | (g << 5) | r
}

public func makeBGPalette16(palBlock: Int, no: Int, color: UInt16) {
    if palBlock < 0 || palBlock >= 16 {
        FatalMsg("Palette block index out of bounds")  // FATAL_MEM_ALIGN
    }
    if no < 0 || no >= 16 {
        FatalMsg("Palette index out of bounds")  // FATAL_MEM_ALIGN
    }
    PALETTE_MEM.writeUInt16(offset: palBlock * 32 + no * 2, value: color)
}
public func makeBGPalette256(no: Int, color: UInt16) {
    if no < 0 || no >= 256 {
        FatalMsg("Palette index out of bounds")  // FATAL_MEM_ALIGN
    }
    PALETTE_MEM.writeUInt16(offset: no * 2, value: color)
}

public func makeObjPalette16(palBlock: Int, no: Int, color: UInt16) {
    if palBlock < 0 || palBlock >= 16 {
        FatalMsg("Palette block index out of bounds")  // FATAL_MEM_ALIGN
    }
    if no < 0 || no >= 16 {
        FatalMsg("Palette index out of bounds")  // FATAL_MEM_ALIGN
    }
    PALETTE_MEM.writeUInt16(offset: 512 + palBlock * 32 + no * 2, value: color)
}

public func makeObjPalette256(no: Int, color: UInt16) {
    if no < 0 || no >= 256 {
        FatalMsg("Palette index out of bounds")  // FATAL_MEM_ALIGN
    }
    PALETTE_MEM.writeUInt16(offset: 512 + no * 2, value: color)
}

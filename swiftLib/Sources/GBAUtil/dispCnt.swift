import UIFFLib

public struct DISPCNT {
    static public func disableAll() {
        DISPCNT_MEM.writeUInt16(value: 0)
    }

    static public func setEnable(
        BG0: Bool = false, BG1: Bool = false, BG2: Bool = false, BG3: Bool = false,
        OBJ: Bool = false, WIN: Bool = false
    ) {
        let BG0E: UInt16 = UInt16(BG0 ? 1 : 0) << 8  // BG0 Enable
        let BG1E: UInt16 = UInt16(BG1 ? 1 : 0) << 9  // BG1 Enable
        let BG2E: UInt16 = UInt16(BG2 ? 1 : 0) << 10  // BG2 Enable
        let BG3E: UInt16 = UInt16(BG3 ? 1 : 0) << 11  // BG3 Enable
        let OBJE: UInt16 = UInt16(OBJ ? 1 : 0) << 12  // OBJ Enable
        let WINE: UInt16 = UInt16(WIN ? 1 : 0) << 15  // WIN Enable
        DISPCNT_MEM.writeUInt16(value: BG0E | BG1E | BG2E | BG3E | OBJE | WINE)
    }

    static public func setBG(
        bgIndex: Int,
        tileBlock: Int, mapBlock: Int,
        prio: Int = 0, mosaic: Bool = false,
        colorMode: COLOR_MODE = .COLOR_16
    ) {
        if tileBlock < 0 || tileBlock > 3 {
            FatalMsg("tileBlock must be in the range of 0 to 3.")
        }
        if mapBlock < 0 || mapBlock > 31 {
            FatalMsg("mapBlock must be in the range of 0 to 31.")
        }

        let PR = UInt16(prio) << 0
        let TB = UInt16(tileBlock) << 2
        let MZ = UInt16(mosaic ? 1 : 0) << 6
        let CM = UInt16(colorMode.rawValue) << 7
        let MB = UInt16(mapBlock) << 8
        let MT = UInt16(0) << 13  // BGエリア外 0:透明
        let SZ = UInt16(11) << 14  // BGサイズ 11: 512x512

        DISPCNT_MEM.writeUInt16(offset: 8 + bgIndex * 2, value: PR | TB | MZ | CM | MB | MT | SZ)
    }
}

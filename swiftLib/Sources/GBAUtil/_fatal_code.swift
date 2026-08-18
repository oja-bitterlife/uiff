import UIFFLib

public let FATAL_TILE_MAGIC = 1
public let FATAL_PAL_INDEX = 2
public let FATAL_PAL_NUM = 3
public let FATAL_TILE_VRAM_OUTOFBOUNDS = 4
public let FATAL_MAP_NOT_FOUND = 5
public let FATAL_TILE_CHAR_INVALID = 6
public let FATAL_MEM_ALIGN = 7
public let FATAL_DMA_SIZE = 8
public let FATAL_UIFF_ENTRY_UNKNOWN = 9
public let FATAL_BG_INDEX = 10

public func InitFatalFunc() {
    SetFatalFunc(fatalFunc: { code in
        DISPCNT_MEM.writeUInt16(value: 0x0000)  // 画面OFF

        // 0x0300_0000は後で上書きするので一旦塗りつぶし色で
        IWRAM.writeUInt16(value: RGB555(255, 0, 0))  // 赤色を表示するためのパレットデータを書き込む
        DMA3_UInt16(
            srcAddr: UInt(WORK_ADDR), dstAddr: UInt(VRAM_ADDR), size: 240 * 160 * 2, fixedSrc: true)  // VRAMに赤色を表示するためのデータを書き込む;

        // 0x0300_0000にコードを書き込むことで、fatalコードを通知する
        IWRAM.writeUInt(value: UInt(bitPattern: code))

        // BG3CNTの設定(BG2の設定)
        DISPCNT_MEM.writeUInt16(offset: 0x0c, value: 0)

        // BG2の表示ON
        let MD: UInt16 = UInt16(3)  // BitmapMode
        let BE: UInt16 = UInt16(1 << 2) << 8  // BG2 Enable
        DISPCNT_MEM.writeUInt16(value: MD | BE)
    })
}

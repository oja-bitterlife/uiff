// Sources/swift-gba/swift_gba.swift
import UIFFLib

// 定数
public let ROM_ADDR: UInt = 0x0800_0000
public let EWRAM_ADDR: UInt = 0x0202_0000  // EWRAM後半128KB
public let DISPCNT_ADDR: UInt = 0x0400_0000
public let PALETTE_ADDR: UInt = 0x0500_0000
public let VRAM_ADDR: UInt = 0x0600_0000
public let OAM_ADDR: UInt = 0x0700_0000

// concurrency safe global variable
nonisolated(unsafe) public let ROM = WorkMemory(
    address: UInt(ROM_ADDR), byteSize: 8 * 1024 * 1024)  // ROM: 8MB
nonisolated(unsafe) public let DISPCNT_MEM = WorkMemory(
    address: UInt(DISPCNT_ADDR), byteSize: 0x10000)  // DISP_CNT: 64KB
nonisolated(unsafe) public let PALETTE_MEM = WorkMemory(
    address: UInt(PALETTE_ADDR), byteSize: 1 * 1024)  // PALETTE: 1KB(BG:0x000-0x1ff, OBJ:0x200-0x3ff)
nonisolated(unsafe) public let VRAM = WorkMemory(
    address: UInt(VRAM_ADDR), byteSize: 96 * 1024)  // VRAM: 96KB(BG:64k, OBJ:32k)
nonisolated(unsafe) public let OAM = WorkMemory(
    address: UInt(OAM_ADDR), byteSize: 1 * 1024)  // OAM: 1KB

// DMA
// ****************************************************************************
private let DMA_THRESHOLD: UInt16 = 64

// 32bitDMA
@_optimize(none)
public func DMA3_UInt(srcAddr: UInt, dstAddr: UInt, size: Int, fixedSrc: Bool = false) {
    // 転送量が4バイト境界に揃っていない場合はエラー
    if (srcAddr | dstAddr | UInt(size)) & 3 != 0 {
        FatalMsg("Memory alignment error")  // FATAL_MEM_ALIGN
    }
    if size < 0 || size > 0xFFFF * 4 {
        FatalMsg("DMA size error")  // FATAL_DMA_SIZE
    }

    // 転送量が64バイト未満の場合は手動転送
    if size < DMA_THRESHOLD {
        let src = WorkMemory(address: srcAddr, byteSize: Int(size))
        let dst = WorkMemory(address: dstAddr, byteSize: Int(size))
        for i in 0..<Int(size / 2) {
            dst.writeUInt16(offset: i * 2, value: src.readUInt16(offset: i * 2))
        }
        return
    }

    DISPCNT_MEM.writeUInt(offset: 0xd4, value: srcAddr)  // 転送元アドレス
    DISPCNT_MEM.writeUInt(offset: 0xd8, value: dstAddr)  // 転送先アドレス
    DISPCNT_MEM.writeUInt16(offset: 0xdc, value: UInt16(size / 4))  // 転送量(32bit単位)

    // 転送開始
    let DMA_ENABLE: UInt16 = 1 << 15
    let DMA_SZ: UInt16 = 1 << 10  // 転送サイズ(32bit)
    let DMA_SRC_CTRL: UInt16 = (fixedSrc ? 2 : 0) << 7
    let DMA_DST_CTRL: UInt16 = 0 << 5
    let dmaFlag = DMA_ENABLE | DMA_SZ | DMA_SRC_CTRL | DMA_DST_CTRL
    DISPCNT_MEM.writeUInt16(offset: 0xde, value: dmaFlag)

    // 転送待ち
    while (DISPCNT_MEM.readUInt16(offset: 0xde) & 0x8000) != 0 {}
}

// 16bitDMA
@_optimize(none)
public func DMA3_UInt16(srcAddr: UInt, dstAddr: UInt, size: Int, fixedSrc: Bool = false) {
    // 転送量が2バイト境界に揃っていない場合はエラー
    if (srcAddr | dstAddr | UInt(size)) & 1 != 0 {
        FatalMsg("Memory alignment error")  // FATAL_MEM_ALIGN
    }
    if size < 0 || size > 0xFFFF * 2 {
        FatalMsg("DMA size error")  // FATAL_DMA_SIZE
    }

    // 転送量が64バイト未満の場合は手動転送
    if size < DMA_THRESHOLD {
        let src = WorkMemory(address: srcAddr, byteSize: Int(size))
        let dst = WorkMemory(address: dstAddr, byteSize: Int(size))
        for i in 0..<Int(size / 2) {
            dst.writeUInt16(offset: i * 2, value: src.readUInt16(offset: i * 2))
        }
        return
    }

    DISPCNT_MEM.writeUInt(offset: 0xd4, value: srcAddr)  // 転送元アドレス
    DISPCNT_MEM.writeUInt(offset: 0xd8, value: dstAddr)  // 転送先アドレス
    DISPCNT_MEM.writeUInt16(offset: 0xdc, value: UInt16(size / 2))  // 転送量(16bit単位)

    // 転送開始
    let DMA_ENABLE: UInt16 = 1 << 15
    let DMA_SZ: UInt16 = 0 << 10  // 転送サイズ(16bit)
    let DMA_SRC_CTRL: UInt16 = (fixedSrc ? 2 : 0) << 7
    let DMA_DST_CTRL: UInt16 = 0 << 5
    let dmaFlag = DMA_ENABLE | DMA_SZ | DMA_SRC_CTRL | DMA_DST_CTRL
    DISPCNT_MEM.writeUInt16(offset: 0xde, value: dmaFlag)

    // 転送待ち
    while (DISPCNT_MEM.readUInt16(offset: 0xde) & 0x8000) != 0 {}
}

// 読み込むファイル名
let uiff_file = "assets/title.uiff"

let UIFF_ENTRY = 0x01
// [type_id(2byte)][subtype_id(2byte)][Enable(2byte)][Visible(2byte)]
// [X(2byte)][Y(2byte)][W(2byte)][H(2byte)]
// [payloads...]
let UIFF_CHILD = 0x02  // [child chunk][child_chunk]...

// 選択系
let UIFF_DEF_SELECT = 0x10
let UIFF_SELECT = UIFF_DEF_SELECT + 1  // [SelRows(2byte)][item_num(2byte)][SEL_ITEM][SEL_ITEM]...

// イベント
let UIFF_DEF_EVENT = 0x20
let UIFF_EVENTS = UIFF_DEF_EVENT + 1  // ブロック受信 [event_id(2byte)][event_id(2byte)]...
let UIFF_LISTEN = UIFF_DEF_EVENT + 2  // リスナー [event_id(2byte)][event_id(2byte)]...

// データ系
let UIFF_DEF_DATA = 0x30
let UIFF_TEXT = UIFF_DEF_DATA + 1  // [len(2byte)][data + padding(2)]
let UIFF_SCRIPT = UIFF_DEF_DATA + 2  // [bytecode(padding4)]
let UIFF_COLORS = UIFF_DEF_DATA + 3  // [color(4byte)][color(4byte)]...

#if DEBUG
import SwiftUI

// MARK: - Canvas preview for CycleHUD styling
//
// Open this file in Xcode with the Canvas panel open (Editor ▸ Canvas).
// Edit styling constants in CycleHUD.swift and Canvas refreshes automatically —
// no need to build and run the full app.
//
// The badge panel is a separate NSPanel so it won't appear here, but all main
// panel styling (material, corner radius, font, padding, sizing) is fully visible.

private struct HUDContentPreview: NSViewRepresentable {
    var text: String
    var index: Int
    var total: Int

    func makeNSView(context: Context) -> NSView {
        let hud = CycleHUD()
        hud.show(text: text, index: index, total: total)
        return hud.contentView ?? NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview("Short — single line") {
    HUDContentPreview(
        text: "git commit -m \"fix: guard commitPaste on HUD visibility\"",
        index: 2,
        total: 5
    )
    .frame(width: 500, height: 60)
    .padding(24)
}

#Preview("Medium — two lines") {
    HUDContentPreview(
        text: "Dear team,\n\nPlease find the updated report attached. Let me know if you have questions.",
        index: 1,
        total: 8
    )
    .frame(width: 500, height: 100)
    .padding(24)
}

#Preview("Long — multi-line code") {
    HUDContentPreview(
        text: "func cycleOlder() {\n    guard !entries.isEmpty else { return }\n    if cyclingActive {\n        if cursor > 0 { cursor -= 1 }\n    } else {\n        cyclingActive = true\n    }\n}",
        index: 3,
        total: 12
    )
    .frame(width: 500, height: 180)
    .padding(24)
}
#endif

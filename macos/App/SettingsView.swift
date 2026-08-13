import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("terminalFontSize") private var fontSize: Double = 13
    @AppStorage("terminalFontName") private var fontName: String = "Menlo"

    private static let monospaceFamilies: [String] = NSFontManager.shared
        .availableFontFamilies
        .filter { NSFont(name: $0, size: 12)?.isFixedPitch == true }
        .sorted()

    var body: some View {
        Form {
            Section("Terminal") {
                Picker("Font", selection: $fontName) {
                    ForEach(Self.monospaceFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                Stepper(value: $fontSize, in: 9...24, step: 1) {
                    Text("Font size: \(Int(fontSize)) pt")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }
}

#Preview {
    SettingsView()
}

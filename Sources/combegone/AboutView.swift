import SwiftUI

struct Component: Identifiable {
    let name: String
    let version: String
    let license: String
    let url: String
    let file: String
    var id: String { name }
}

let components: [Component] = [
    Component(name: "ComBeGone", version: Bundle.main.shortVersion, license: "GNU GPL v2 or later",
              url: "https://github.com/ceadd/combegone", file: "combegone"),
    Component(name: "Comskip", version: "0.83.001", license: "GNU GPL v2",
              url: "https://github.com/erikkaashoek/Comskip", file: "comskip"),
    Component(name: "FFmpeg", version: "6.1.2", license: "GNU GPL v2 or later (built with --enable-gpl)",
              url: "https://ffmpeg.org", file: "ffmpeg"),
    Component(name: "Argtable", version: "2.13", license: "GNU LGPL v2 or later",
              url: "https://argtable.sourceforge.io", file: "argtable2"),
]

struct AboutView: View {
    @State private var selected: String = "ComBeGone"

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                Text("ComBeGone").font(.title.weight(.semibold))
                Text("Version \(Bundle.main.shortVersion)").foregroundStyle(.secondary)
                Text("Commercials, be gone. Removes the ads from TV recordings.\nFree and open source.")
                    .font(.callout).multilineTextAlignment(.center)
                Text("Made by CEADD (Chad L)")
                    .font(.callout.weight(.medium)).padding(.top, 2)
                Link("github.com/ceadd/combegone", destination: URL(string: "https://github.com/ceadd/combegone")!)
                    .font(.callout)
            }

            Picker("License", selection: $selected) {
                ForEach(components) { Text($0.name).tag($0.name) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let c = components.first(where: { $0.name == selected }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(c.name) \(c.version)").font(.headline)
                        Spacer()
                        if let u = URL(string: c.url) { Link(c.name == "ComBeGone" ? "GitHub" : "Source", destination: u) }
                    }
                    Text(c.license).font(.subheadline).foregroundStyle(.secondary)
                    ScrollView {
                        Text(licenseText(c.file))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 560)
    }

    private func licenseText(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Licenses"),
              let s = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text not found in this build."
        }
        return s
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
}

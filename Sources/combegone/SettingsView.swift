import SwiftUI
import CombegoneCore

private typealias K = ProcessingOptions.Key
private let defaults = ProcessingOptions()

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            DetectionSettings().tabItem { Label("Detection", systemImage: "waveform.path.ecg") }
        }
        .frame(width: 520)
    }
}

private struct GeneralSettings: View {
    @AppStorage(K.replaceOriginal) private var replaceOriginal = defaults.replaceOriginal
    @AppStorage(K.useUserIni) private var useUserIni = defaults.useUserIni

    private var hasUserIni: Bool {
        FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".comskip.ini").path)
    }

    var body: some View {
        Form {
            Section("When a file is finished") {
                Picker("Output", selection: $replaceOriginal) {
                    Text("Save a copy next to the original").tag(false)
                    Text("Replace the original file").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if replaceOriginal {
                    Label("The original recording is overwritten with the cut version, keeping its name. This can't be undone.",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                } else {
                    Text("Saved as “Name (no ads)” in the same folder. The original is left untouched.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            if hasUserIni {
                Section("comskip settings file") {
                    Toggle("Use my ~/.comskip.ini instead of the built-in settings", isOn: $useUserIni)
                    Text("The built-in settings are tuned to catch more ads on cable channels. Only turn this on if you've tuned your own file.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DetectionSettings: View {
    @AppStorage(K.customDetection) private var custom = defaults.customDetection
    @AppStorage(K.detectMethod) private var mask = defaults.detectMethods.bitmask
    @AppStorage(K.trustLogo) private var trustLogo = defaults.trustLogo
    @AppStorage(K.minCommercialBreak) private var minBreak = defaults.minCommercialBreak
    @AppStorage(K.maxCommercialBreak) private var maxBreak = defaults.maxCommercialBreak
    @AppStorage(K.minShowSegment) private var minShow = defaults.minShowSegment
    @AppStorage(K.minCommercialSize) private var minAd = defaults.minCommercialSize
    @AppStorage(K.maxCommercialSize) private var maxAd = defaults.maxCommercialSize
    @AppStorage(K.keepFirstSeconds) private var keepFirst = defaults.keepFirstSeconds
    @AppStorage(K.keepLastSeconds) private var keepLast = defaults.keepLastSeconds
    @AppStorage(K.threadCount) private var threads = defaults.threadCount

    var body: some View {
        Form {
            Section {
                number("Never cut the last", $keepLast, 0...3600, unit: "seconds")
                number("Never cut the first", $keepFirst, 0...3600, unit: "seconds")
            } header: {
                Text("Protect start and end")
            } footer: {
                Text("Missing end credits? Set “Never cut the last” to about the length of the credits (say 60 s). Anything in that window is kept, so don’t go much longer. 0 = off.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Use custom detection settings", isOn: $custom)
                Text(custom ? "These values override the settings file."
                            : "Off: uses the built-in settings, tuned to catch more ads (recommended).")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Group {
                Section("Look for") {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]) {
                        ForEach(DetectMethod.allCases) { m in
                            Toggle(m.title, isOn: Binding(
                                get: { mask & m.rawValue != 0 },
                                set: { mask = $0 ? (mask | m.rawValue) : (mask & ~m.rawValue) }))
                        }
                    }
                    if mask == 0 { Text("Pick at least one.").font(.callout).foregroundStyle(.red) }
                    Toggle("Trust the channel logo for long ads", isOn: $trustLogo)
                    Text("Keeps long ads (2+ minutes) from being mistaken for the show when the channel logo is missing.")
                        .font(.callout).foregroundStyle(.secondary)
                }

                Section("Commercial breaks (seconds)") {
                    number("Shortest break", $minBreak, 1...3600)
                    number("Longest break", $maxBreak, 1...7200)
                    number("Shortest single ad", $minAd, 1...600)
                    number("Longest single ad", $maxAd, 1...3600)
                    number("Shortest show segment", $minShow, 1...3600)
                }

                Section("Performance") {
                    number("Threads", $threads, 1...32)
                }

                Section {
                    Button("Reset to Defaults") { reset() }
                }
            }
            .disabled(!custom)
        }
        .formStyle(.grouped)
        .frame(height: 560)
    }

    private func number(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, unit: String? = nil) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: value, format: .number)
                    .labelsHidden().multilineTextAlignment(.trailing).frame(width: 70)
                Stepper(title, value: value, in: range, step: unit == nil ? 1 : 5).labelsHidden()
                if let unit { Text(unit).foregroundStyle(.secondary) }
            }
        }
    }

    private func reset() {
        mask = defaults.detectMethods.bitmask; trustLogo = defaults.trustLogo
        minBreak = defaults.minCommercialBreak; maxBreak = defaults.maxCommercialBreak
        minShow = defaults.minShowSegment; minAd = defaults.minCommercialSize; maxAd = defaults.maxCommercialSize
        threads = defaults.threadCount
    }
}

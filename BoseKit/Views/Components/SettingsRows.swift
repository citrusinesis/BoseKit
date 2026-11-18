import SwiftUI

struct SettingsGroupStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
                .labelStyle(.titleOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        } label: {
            Text(title)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title).fixedSize()
                Spacer(minLength: 8)
                content.labelsHidden().fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                HStack {
                    Spacer(minLength: 0)
                    content.labelsHidden()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsPicker<Value: Hashable, Options: View>: View {
    let title: LocalizedStringResource
    @Binding var selection: Value
    @ViewBuilder let options: Options

    var body: some View {
        SettingsRow(title: title) {
            Picker(title, selection: $selection) { options }
                .pickerStyle(.menu)
        }
    }
}

struct SettingsToggle: View {
    let title: LocalizedStringResource
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .frame(minHeight: 24)
    }
}

struct SettingsFootnote: View {
    let text: LocalizedStringResource

    init(_ text: LocalizedStringResource) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct InformationRow<Value: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
            Spacer(minLength: 8)
            value
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

extension InformationRow where Value == Text {
    init(_ title: LocalizedStringResource, value: String) {
        self.init(title: title) { Text(value) }
    }

    init(_ title: LocalizedStringResource, value: LocalizedStringResource) {
        self.init(title: title) { Text(value) }
    }
}

extension View {
    func settingsContentStyle() -> some View {
        font(.body)
            .controlSize(.regular)
            .buttonStyle(.bordered)
            .groupBoxStyle(SettingsGroupStyle())
    }
}

#Preview("Settings rows") {
    @Previewable @State var enabled = true
    @Previewable @State var level = 1
    VStack(spacing: 16) {
        SettingsSection(title: .connectionTitle) {
            SettingsToggle(title: .deviceMultipoint, isOn: $enabled)
            Divider()
            SettingsPicker(title: .deviceSelfVoice, selection: $level) {
                Text(.commonOff).tag(0)
                Text(.commonLow).tag(1)
            }
            SettingsFootnote(.deviceMultipointListHelp)
        }
        SettingsSection(title: .deviceInformation) {
            InformationRow(.deviceModel, value: "QuietComfort Ultra Headphones")
            InformationRow(.deviceFirmware, value: "1.6.7")
        }
    }
    .settingsContentStyle()
    .padding(20)
    .frame(width: 420)
}

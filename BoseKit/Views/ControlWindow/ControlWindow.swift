import SwiftUI

enum ControlPage: String, CaseIterable, Identifiable {
    case sound, device, app

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .sound: .commonSound
        case .device: .commonDevice
        case .app: .commonApp
        }
    }
}

struct ControlWindow: View {
    static let id = "control"

    @Bindable var model: BoseAppModel
    @State private var page: ControlPage = .sound

    var body: some View {
        VStack(spacing: 0) {
            DeviceHeader(model: model)
            Picker(.commonSettings, selection: $page) {
                ForEach(ControlPage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("controlPage")
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                ControlPageContent(model: model, page: page)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .settingsContentStyle()
            }
            Divider()
            AppFooter(model: model)
        }
        .frame(width: 420, height: 650)
    }
}

private struct ControlPageContent: View {
    let model: BoseAppModel
    let page: ControlPage

    var body: some View {
        switch page {
        case .app: AppPreferencesView(model: model)
        case .sound: deviceContent(.sound)
        case .device: deviceContent(.device)
        }
    }

    @ViewBuilder
    private func deviceContent(_ page: DevicePage) -> some View {
        if let device = model.selected {
            DeviceContent(device: device, page: page).id(device.id)
        } else {
            ConnectionPlaceholder()
        }
    }
}

private enum DevicePage {
    case sound, device
}

private struct DeviceContent: View {
    let device: DeviceController
    let page: DevicePage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = device.error {
                Label(error.message, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
            if device.connected {
                DevicePageContent(device: device, page: page)
            } else {
                ConnectionPlaceholder(device: device)
            }
        }
        .tracksDeviceVisibility(device)
    }
}

private struct DevicePageContent: View {
    let device: DeviceController
    let page: DevicePage

    var body: some View {
        switch page {
        case .sound: SoundSettings(device: device)
        case .device: DeviceSettings(device: device)
        }
    }
}

#Preview("Control window") {
    ControlWindow(model: BoseAppModel())
}

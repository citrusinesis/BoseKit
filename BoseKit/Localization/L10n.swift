import Foundation

enum L10n {
    enum Common {
        static var appName: LocalizedStringResource {
            LocalizedStringResource("common.appName", defaultValue: "BoseKit", comment: "Common interface label or message: appName.")
        }

        static var sound: LocalizedStringResource {
            LocalizedStringResource("common.sound", defaultValue: "Sound", comment: "Common interface label or message: sound.")
        }

        static var modes: LocalizedStringResource {
            LocalizedStringResource("common.modes", defaultValue: "Modes", comment: "Common interface label or message: modes.")
        }

        static var device: LocalizedStringResource {
            LocalizedStringResource("common.device", defaultValue: "Device", comment: "Common interface label or message: device.")
        }

        static var app: LocalizedStringResource {
            LocalizedStringResource("common.app", defaultValue: "App", comment: "Common interface label or message: app.")
        }

        static var settings: LocalizedStringResource {
            LocalizedStringResource("common.settings", defaultValue: "Settings", comment: "Common interface label or message: settings.")
        }

        static var cancel: LocalizedStringResource {
            LocalizedStringResource("common.cancel", defaultValue: "Cancel", comment: "Common interface label or message: cancel.")
        }

        static var save: LocalizedStringResource {
            LocalizedStringResource("common.save", defaultValue: "Save", comment: "Common interface label or message: save.")
        }

        static var edit: LocalizedStringResource {
            LocalizedStringResource("common.edit", defaultValue: "Edit", comment: "Common interface label or message: edit.")
        }

        static var delete: LocalizedStringResource {
            LocalizedStringResource("common.delete", defaultValue: "Delete", comment: "Common interface label or message: delete.")
        }

        static var change: LocalizedStringResource {
            LocalizedStringResource("common.change", defaultValue: "Change", comment: "Common interface label or message: change.")
        }

        static var off: LocalizedStringResource {
            LocalizedStringResource("common.off", defaultValue: "Off", comment: "Common interface label or message: off.")
        }

        static var high: LocalizedStringResource {
            LocalizedStringResource("common.high", defaultValue: "High", comment: "Common interface label or message: high.")
        }

        static var medium: LocalizedStringResource {
            LocalizedStringResource("common.medium", defaultValue: "Medium", comment: "Common interface label or message: medium.")
        }

        static var low: LocalizedStringResource {
            LocalizedStringResource("common.low", defaultValue: "Low", comment: "Common interface label or message: low.")
        }

        static var none: LocalizedStringResource {
            LocalizedStringResource("common.none", defaultValue: "None", comment: "Common interface label or message: none.")
        }

        static var selected: LocalizedStringResource {
            LocalizedStringResource("common.selected", defaultValue: "Selected", comment: "Common interface label or message: selected.")
        }

        static var notSelected: LocalizedStringResource {
            LocalizedStringResource("common.notSelected", defaultValue: "Not Selected", comment: "Common interface label or message: notSelected.")
        }

        static var name: LocalizedStringResource {
            LocalizedStringResource("common.name", defaultValue: "Name", comment: "Common interface label or message: name.")
        }
    }

    enum Menu {
        static var title: LocalizedStringResource {
            LocalizedStringResource("menu.title", defaultValue: "Menu Bar", comment: "Menu interface label or message: title.")
        }

        static var hideWhenUnavailable: LocalizedStringResource {
            LocalizedStringResource("menu.hideWhenUnavailable", defaultValue: "Hide when no supported device is connected", comment: "Menu interface label or message: hideWhenUnavailable.")
        }

        static var hiddenHelp: LocalizedStringResource {
            LocalizedStringResource("menu.hiddenHelp", defaultValue: "The icon returns when a device connects. While it is hidden, open BoseKit from Finder or Spotlight to access settings.", comment: "Menu interface label or message: hiddenHelp.")
        }

        static var showBattery: LocalizedStringResource {
            LocalizedStringResource("menu.showBattery", defaultValue: "Show battery in the menu bar", comment: "Menu interface label or message: showBattery.")
        }

        static var refresh: LocalizedStringResource {
            LocalizedStringResource("menu.refresh", defaultValue: "Refresh", comment: "Menu interface label or message: refresh.")
        }

        static var openWindow: LocalizedStringResource {
            LocalizedStringResource("menu.openWindow", defaultValue: "Open in a Window", comment: "Menu interface label or message: openWindow.")
        }

        static var quit: LocalizedStringResource {
            LocalizedStringResource("menu.quit", defaultValue: "Quit", comment: "Menu interface label or message: quit.")
        }

        static var tagline: LocalizedStringResource {
            LocalizedStringResource("menu.tagline", defaultValue: "Your sound, within reach", comment: "Menu interface label or message: tagline.")
        }
    }

    enum Connection {
        static var emptyTitle: LocalizedStringResource {
            LocalizedStringResource("connection.emptyTitle", defaultValue: "Connect a Bose Device", comment: "Connection interface label or message: emptyTitle.")
        }

        static var emptyHelp: LocalizedStringResource {
            LocalizedStringResource("connection.emptyHelp", defaultValue: "Pair a supported Bose device in macOS Bluetooth settings to see it here.", comment: "Connection interface label or message: emptyHelp.")
        }

        static var openBluetoothSettings: LocalizedStringResource {
            LocalizedStringResource("connection.openBluetoothSettings", defaultValue: "Open Bluetooth Settings", comment: "Connection interface label or message: openBluetoothSettings.")
        }

        static var connecting: LocalizedStringResource {
            LocalizedStringResource("connection.connecting", defaultValue: "Connecting", comment: "Connection interface label or message: connecting.")
        }

        static var disconnected: LocalizedStringResource {
            LocalizedStringResource("connection.disconnected", defaultValue: "Not Connected", comment: "Connection interface label or message: disconnected.")
        }

        static var help: LocalizedStringResource {
            LocalizedStringResource("connection.help", defaultValue: "Make sure your device is on and within Bluetooth range of your Mac.", comment: "Connection interface label or message: help.")
        }

        static var connect: LocalizedStringResource {
            LocalizedStringResource("connection.connect", defaultValue: "Connect", comment: "Connection interface label or message: connect.")
        }

        static var updating: LocalizedStringResource {
            LocalizedStringResource("connection.updating", defaultValue: "Updating…", comment: "Connection interface label or message: updating.")
        }

        static var connected: LocalizedStringResource {
            LocalizedStringResource("connection.connected", defaultValue: "Connected", comment: "Connection interface label or message: connected.")
        }

        static var waiting: LocalizedStringResource {
            LocalizedStringResource("connection.waiting", defaultValue: "Waiting for Connection", comment: "Connection interface label or message: waiting.")
        }

        static var title: LocalizedStringResource {
            LocalizedStringResource("connection.title", defaultValue: "Device Connection", comment: "Connection interface label or message: title.")
        }

        static var discoveryHelp: LocalizedStringResource {
            LocalizedStringResource("connection.discoveryHelp", defaultValue: "BoseKit shows supported paired devices and automatically connects to devices available over Bluetooth.", comment: "Connection interface label or message: discoveryHelp.")
        }

        static var resume: LocalizedStringResource {
            LocalizedStringResource("connection.resume", defaultValue: "Resume Automatic Connection", comment: "Connection interface label or message: resume.")
        }

        static var disconnect: LocalizedStringResource {
            LocalizedStringResource("connection.disconnect", defaultValue: "Disconnect Device Controls", comment: "Connection interface label or message: disconnect.")
        }

        static var refreshHelp: LocalizedStringResource {
            LocalizedStringResource("connection.refreshHelp", defaultValue: "While this view is open, settings refresh periodically to reflect changes from other apps or headphone buttons.", comment: "Connection interface label or message: refreshHelp.")
        }
    }

    enum Sound {
        static var ambient: LocalizedStringResource {
            LocalizedStringResource("sound.ambient", defaultValue: "Ambient Sound", comment: "Sound interface label or message: ambient.")
        }

        static var noiseCancellation: LocalizedStringResource {
            LocalizedStringResource("sound.noiseCancellation", defaultValue: "Noise Cancellation", comment: "Sound interface label or message: noiseCancellation.")
        }

        static var windReduction: LocalizedStringResource {
            LocalizedStringResource("sound.windReduction", defaultValue: "Wind Reduction", comment: "Sound interface label or message: windReduction.")
        }

        static var equalizer: LocalizedStringResource {
            LocalizedStringResource("sound.equalizer", defaultValue: "Equalizer", comment: "Sound interface label or message: equalizer.")
        }

        static var bass: LocalizedStringResource {
            LocalizedStringResource("sound.bass", defaultValue: "Bass", comment: "Sound interface label or message: bass.")
        }

        static var midrange: LocalizedStringResource {
            LocalizedStringResource("sound.midrange", defaultValue: "Midrange", comment: "Sound interface label or message: midrange.")
        }

        static var treble: LocalizedStringResource {
            LocalizedStringResource("sound.treble", defaultValue: "Treble", comment: "Sound interface label or message: treble.")
        }

        static var resetEqualizer: LocalizedStringResource {
            LocalizedStringResource("sound.resetEqualizer", defaultValue: "Reset Equalizer", comment: "Sound interface label or message: resetEqualizer.")
        }

        static var empty: LocalizedStringResource {
            LocalizedStringResource("sound.empty", defaultValue: "No adjustable sound settings are available for this device.", comment: "Sound interface label or message: empty.")
        }

        static var maximumCancellation: LocalizedStringResource {
            LocalizedStringResource("sound.maximumCancellation", defaultValue: "Maximum Cancellation", comment: "Sound interface label or message: maximumCancellation.")
        }

        static var maximumAwareness: LocalizedStringResource {
            LocalizedStringResource("sound.maximumAwareness", defaultValue: "Maximum Awareness", comment: "Sound interface label or message: maximumAwareness.")
        }

        static var presetHelp: LocalizedStringResource {
            LocalizedStringResource("sound.presetHelp", defaultValue: "Preset settings cannot be changed. Create a custom mode in Listening Modes to adjust them.", comment: "Sound interface label or message: presetHelp.")
        }

        static var immersiveAudio: LocalizedStringResource {
            LocalizedStringResource("sound.immersiveAudio", defaultValue: "Immersive Audio", comment: "Sound interface label or message: immersiveAudio.")
        }

        static var still: LocalizedStringResource {
            LocalizedStringResource("sound.still", defaultValue: "Still", comment: "Sound interface label or message: still.")
        }

        static var motion: LocalizedStringResource {
            LocalizedStringResource("sound.motion", defaultValue: "Motion", comment: "Sound interface label or message: motion.")
        }

        static var windBlock: LocalizedStringResource {
            LocalizedStringResource("sound.windBlock", defaultValue: "Wind Block", comment: "Sound interface label or message: windBlock.")
        }

        static var windBlockHelp: LocalizedStringResource {
            LocalizedStringResource("sound.windBlockHelp", defaultValue: "Ambient sound adjustments are limited while Wind Block is on.", comment: "Sound interface label or message: windBlockHelp.")
        }

        static var automaticAmbient: LocalizedStringResource {
            LocalizedStringResource("sound.automaticAmbient", defaultValue: "Automatic Ambient Sound", comment: "Sound interface label or message: automaticAmbient.")
        }

        static func band(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("sound.band", defaultValue: "Band \(value)", comment: "Equalizer band name; the argument is the band identifier, not a count.")
        }

        static func ambientLevel(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("sound.ambientLevel", defaultValue: "Ambient Sound: \(value)", comment: "Ambient sound stepper label; the argument is the current level from 0 to 10.")
        }
    }

    enum Modes {
        static var newName: LocalizedStringResource {
            LocalizedStringResource("modes.newName", defaultValue: "Work", comment: "Initial editable name for a newly created custom mode. Saved to the headphones only after confirmation.")
        }

        static var title: LocalizedStringResource {
            LocalizedStringResource("modes.title", defaultValue: "Listening Modes", comment: "Modes interface label or message: title.")
        }

        static var current: LocalizedStringResource {
            LocalizedStringResource("modes.current", defaultValue: "Current Mode", comment: "Modes interface label or message: current.")
        }

        static var create: LocalizedStringResource {
            LocalizedStringResource("modes.create", defaultValue: "New Mode", comment: "Modes interface label or message: create.")
        }

        static var emptyTitle: LocalizedStringResource {
            LocalizedStringResource("modes.emptyTitle", defaultValue: "No Modes", comment: "Modes interface label or message: emptyTitle.")
        }

        static var emptyHelp: LocalizedStringResource {
            LocalizedStringResource("modes.emptyHelp", defaultValue: "This device does not support modes, or the mode list has not loaded yet.", comment: "Modes interface label or message: emptyHelp.")
        }

        static var favoritesHelp: LocalizedStringResource {
            LocalizedStringResource("modes.favoritesHelp", defaultValue: "Use the headphone button to cycle through starred modes.", comment: "Modes interface label or message: favoritesHelp.")
        }

        static var powerOn: LocalizedStringResource {
            LocalizedStringResource("modes.powerOn", defaultValue: "Power-On Mode", comment: "Modes interface label or message: powerOn.")
        }

        static var deleteConfirmation: LocalizedStringResource {
            LocalizedStringResource("modes.deleteConfirmation", defaultValue: "Delete this custom mode?", comment: "Modes interface label or message: deleteConfirmation.")
        }

        static var delete: LocalizedStringResource {
            LocalizedStringResource("modes.delete", defaultValue: "Delete Mode", comment: "Modes interface label or message: delete.")
        }

        static var deleteHelp: LocalizedStringResource {
            LocalizedStringResource("modes.deleteHelp", defaultValue: "If this mode is active, your headphones will switch to a preset before it is deleted.", comment: "Modes interface label or message: deleteHelp.")
        }

        static var custom: LocalizedStringResource {
            LocalizedStringResource("modes.custom", defaultValue: "Custom Mode", comment: "Modes interface label or message: custom.")
        }

        static var preset: LocalizedStringResource {
            LocalizedStringResource("modes.preset", defaultValue: "Preset", comment: "Modes interface label or message: preset.")
        }

        static var voicePromptName: LocalizedStringResource {
            LocalizedStringResource("modes.voicePromptName", defaultValue: "Voice Prompt Name", comment: "Modes interface label or message: voicePromptName.")
        }

        static var voicePromptHelp: LocalizedStringResource {
            LocalizedStringResource("modes.voicePromptHelp", defaultValue: "The Bose app may display the voice prompt name instead.", comment: "Modes interface label or message: voicePromptHelp.")
        }

        static var invalidName: LocalizedStringResource {
            LocalizedStringResource("modes.invalidName", defaultValue: "Enter a name of up to 31 UTF-8 bytes.", comment: "Modes interface label or message: invalidName.")
        }

        static func favorite(_ name: String) -> LocalizedStringResource {
            LocalizedStringResource("modes.favorite", defaultValue: "Favorite \(name)", comment: "Accessibility label for a mode favorite button; the argument is the device-provided mode name.")
        }

        static func manage(_ name: String) -> LocalizedStringResource {
            LocalizedStringResource("modes.manage", defaultValue: "Manage \(name)", comment: "Accessibility label for a mode actions menu; the argument is the mode name.")
        }

        static func promptName(_ value: UInt16) -> LocalizedStringResource {
            LocalizedStringResource("modes.promptName", defaultValue: "Name \(value)", comment: "Fallback voice prompt name; the argument is a prompt identifier, not a count.")
        }

        static func fallbackName(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("modes.fallbackName", defaultValue: "Mode \(value)", comment: "Fallback mode name; the argument is the one-based mode slot, not a count.")
        }
    }

    enum Device {
        static var stopPairing: LocalizedStringResource {
            LocalizedStringResource("device.stopPairing", defaultValue: "Stop Pairing", comment: "Device connection and shortcut controls: stopPairing.")
        }

        static var pairingHelp: LocalizedStringResource {
            LocalizedStringResource("device.pairingHelp", defaultValue: "Choose these headphones in the other device’s Bluetooth settings.", comment: "Device connection and shortcut controls: pairingHelp.")
        }

        static var connectionDetails: LocalizedStringResource {
            LocalizedStringResource("device.connectionDetails", defaultValue: "Connection Details", comment: "Device connection and shortcut controls: connectionDetails.")
        }

        static var multipointListHelp: LocalizedStringResource {
            LocalizedStringResource("device.multipointListHelp", defaultValue: "BoseKit can show the current audio source, but cannot yet list every device connected to these headphones.", comment: "Device connection and shortcut controls: multipointListHelp.")
        }

        static var sourceUnknown: LocalizedStringResource {
            LocalizedStringResource("device.sourceUnknown", defaultValue: "Current audio source unavailable", comment: "Device connection and shortcut controls: sourceUnknown.")
        }

        static var shortcutAction: LocalizedStringResource {
            LocalizedStringResource("device.shortcutAction", defaultValue: "Button Action", comment: "Device connection and shortcut controls: shortcutAction.")
        }

        static var longPress: LocalizedStringResource {
            LocalizedStringResource("device.longPress", defaultValue: "Press and Hold", comment: "Device connection and shortcut controls: longPress.")
        }

        static var linkDevices: LocalizedStringResource {
            LocalizedStringResource("device.linkDevices", defaultValue: "Device Connection", comment: "Shortcut button action that links devices.")
        }

        static var settings: LocalizedStringResource {
            LocalizedStringResource("device.settings", defaultValue: "Device Settings", comment: "Device interface label or message: settings.")
        }

        static var name: LocalizedStringResource {
            LocalizedStringResource("device.name", defaultValue: "Device Name", comment: "Device interface label or message: name.")
        }

        static var multipoint: LocalizedStringResource {
            LocalizedStringResource("device.multipoint", defaultValue: "Multipoint", comment: "Device interface label or message: multipoint.")
        }

        static var autoPause: LocalizedStringResource {
            LocalizedStringResource("device.autoPause", defaultValue: "Pause when removed", comment: "Device interface label or message: autoPause.")
        }

        static var autoAnswer: LocalizedStringResource {
            LocalizedStringResource("device.autoAnswer", defaultValue: "Answer calls when worn", comment: "Device interface label or message: autoAnswer.")
        }

        static var selfVoice: LocalizedStringResource {
            LocalizedStringResource("device.selfVoice", defaultValue: "Self Voice During Calls", comment: "Device interface label or message: selfVoice.")
        }

        static var pairing: LocalizedStringResource {
            LocalizedStringResource("device.pairing", defaultValue: "Pair a new device", comment: "Device interface label or message: pairing.")
        }

        static var powerOff: LocalizedStringResource {
            LocalizedStringResource("device.powerOff", defaultValue: "Power Off Headphones", comment: "Device interface label or message: powerOff.")
        }

        static var powerOffConfirmation: LocalizedStringResource {
            LocalizedStringResource("device.powerOffConfirmation", defaultValue: "Power off your headphones?", comment: "Device interface label or message: powerOffConfirmation.")
        }

        static var confirmPowerOff: LocalizedStringResource {
            LocalizedStringResource("device.confirmPowerOff", defaultValue: "Power Off", comment: "Device interface label or message: confirmPowerOff.")
        }

        static var powerOffHelp: LocalizedStringResource {
            LocalizedStringResource("device.powerOffHelp", defaultValue: "Playback and calls will end. You will need to turn your headphones back on manually.", comment: "Device interface label or message: powerOffHelp.")
        }

        static var shortcut: LocalizedStringResource {
            LocalizedStringResource("device.shortcut", defaultValue: "Shortcut Button", comment: "Device interface label or message: shortcut.")
        }

        static var voiceAssistant: LocalizedStringResource {
            LocalizedStringResource("device.voiceAssistant", defaultValue: "Voice Assistant", comment: "Device interface label or message: voiceAssistant.")
        }

        static var batteryLevel: LocalizedStringResource {
            LocalizedStringResource("device.batteryLevel", defaultValue: "Battery Level", comment: "Device interface label or message: batteryLevel.")
        }

        static var playPause: LocalizedStringResource {
            LocalizedStringResource("device.playPause", defaultValue: "Play / Pause", comment: "Device interface label or message: playPause.")
        }

        static var increaseAmbient: LocalizedStringResource {
            LocalizedStringResource("device.increaseAmbient", defaultValue: "Increase Ambient Sound", comment: "Device interface label or message: increaseAmbient.")
        }

        static var decreaseAmbient: LocalizedStringResource {
            LocalizedStringResource("device.decreaseAmbient", defaultValue: "Decrease Ambient Sound", comment: "Device interface label or message: decreaseAmbient.")
        }

        static var wakeWord: LocalizedStringResource {
            LocalizedStringResource("device.wakeWord", defaultValue: "Wake Word", comment: "Device interface label or message: wakeWord.")
        }

        static var switchDevice: LocalizedStringResource {
            LocalizedStringResource("device.switchDevice", defaultValue: "Switch Device", comment: "Device interface label or message: switchDevice.")
        }

        static var conversationMode: LocalizedStringResource {
            LocalizedStringResource("device.conversationMode", defaultValue: "Conversation Mode", comment: "Device interface label or message: conversationMode.")
        }

        static var nextTrack: LocalizedStringResource {
            LocalizedStringResource("device.nextTrack", defaultValue: "Next Track", comment: "Device interface label or message: nextTrack.")
        }

        static var previousTrack: LocalizedStringResource {
            LocalizedStringResource("device.previousTrack", defaultValue: "Previous Track", comment: "Device interface label or message: previousTrack.")
        }

        static var notifications: LocalizedStringResource {
            LocalizedStringResource("device.notifications", defaultValue: "Notifications", comment: "Device interface label or message: notifications.")
        }

        static var disabled: LocalizedStringResource {
            LocalizedStringResource("device.disabled", defaultValue: "Disabled", comment: "Device interface label or message: disabled.")
        }

        static var appAction: LocalizedStringResource {
            LocalizedStringResource("device.appAction", defaultValue: "App Action", comment: "Device interface label or message: appAction.")
        }

        static var spotify: LocalizedStringResource {
            LocalizedStringResource("device.spotify", defaultValue: "Spotify", comment: "Device interface label or message: spotify.")
        }

        static var cycleModes: LocalizedStringResource {
            LocalizedStringResource("device.cycleModes", defaultValue: "Cycle Modes", comment: "Device interface label or message: cycleModes.")
        }

        static var wiredInput: LocalizedStringResource {
            LocalizedStringResource("device.wiredInput", defaultValue: "Wired Input", comment: "Device interface label or message: wiredInput.")
        }

        static var voicePrompts: LocalizedStringResource {
            LocalizedStringResource("device.voicePrompts", defaultValue: "Voice Prompts", comment: "Device interface label or message: voicePrompts.")
        }

        static var promptLanguage: LocalizedStringResource {
            LocalizedStringResource("device.promptLanguage", defaultValue: "Prompt Language", comment: "Device interface label or message: promptLanguage.")
        }

        static var voicePromptConfirmation: LocalizedStringResource {
            LocalizedStringResource("device.voicePromptConfirmation", defaultValue: "Change voice prompt settings?", comment: "Device interface label or message: voicePromptConfirmation.")
        }

        static var voicePromptWarning: LocalizedStringResource {
            LocalizedStringResource("device.voicePromptWarning", defaultValue: "On first-generation QC Ultra headphones, turning voice prompts off and back on leaves some internal prompt settings changed. Button announcements are unaffected.", comment: "Device interface label or message: voicePromptWarning.")
        }

        static var sourceDevices: LocalizedStringResource {
            LocalizedStringResource("device.sourceDevices", defaultValue: "Devices", comment: "Section title listing devices paired with the headphones.")
        }

        static var thisMac: LocalizedStringResource {
            LocalizedStringResource("device.thisMac", defaultValue: "This Mac", comment: "Tag on the paired device that is the Mac running BoseKit.")
        }

        static var activeSource: LocalizedStringResource {
            LocalizedStringResource("device.activeSource", defaultValue: "Playing", comment: "Tag on the paired device currently sending audio to the headphones.")
        }

        static var notConnected: LocalizedStringResource {
            LocalizedStringResource("device.notConnected", defaultValue: "Not Connected", comment: "Status of a paired device that is not connected to the headphones.")
        }

        static var switchToDevice: LocalizedStringResource {
            LocalizedStringResource("device.switchToDevice", defaultValue: "Switch", comment: "Button that makes a connected device the headphones' audio source.")
        }

        static var switchSource: LocalizedStringResource {
            LocalizedStringResource("device.switchSource", defaultValue: "Switch Audio Source", comment: "Device interface label or message: switchSource.")
        }

        static var sourceAddress: LocalizedStringResource {
            LocalizedStringResource("device.sourceAddress", defaultValue: "Connected source’s Bluetooth address", comment: "Device interface label or message: sourceAddress.")
        }

        static var confirmSwitchSource: LocalizedStringResource {
            LocalizedStringResource("device.confirmSwitchSource", defaultValue: "Switch to This Source", comment: "Device interface label or message: confirmSwitchSource.")
        }

        static var information: LocalizedStringResource {
            LocalizedStringResource("device.information", defaultValue: "Device Information", comment: "Device interface label or message: information.")
        }

        static var model: LocalizedStringResource {
            LocalizedStringResource("device.model", defaultValue: "Model", comment: "Device interface label or message: model.")
        }

        static var firmware: LocalizedStringResource {
            LocalizedStringResource("device.firmware", defaultValue: "Firmware", comment: "Device interface label or message: firmware.")
        }

        static var serialNumber: LocalizedStringResource {
            LocalizedStringResource("device.serialNumber", defaultValue: "Serial Number", comment: "Device interface label or message: serialNumber.")
        }

        static var bluetoothAddress: LocalizedStringResource {
            LocalizedStringResource("device.bluetoothAddress", defaultValue: "Bluetooth Address", comment: "Device interface label or message: bluetoothAddress.")
        }

        static var audioSource: LocalizedStringResource {
            LocalizedStringResource("device.audioSource", defaultValue: "Audio Source", comment: "Device interface label or message: audioSource.")
        }

        static var bluetooth: LocalizedStringResource {
            LocalizedStringResource("device.bluetooth", defaultValue: "Bluetooth", comment: "Device interface label or message: bluetooth.")
        }

        static var wired: LocalizedStringResource {
            LocalizedStringResource("device.wired", defaultValue: "Wired", comment: "Device interface label or message: wired.")
        }

        static var unavailableHelp: LocalizedStringResource {
            LocalizedStringResource("device.unavailableHelp", defaultValue: "Some features did not respond and are hidden for this connection. Reconnect to check them again.", comment: "Device interface label or message: unavailableHelp.")
        }

        static var rightBattery: LocalizedStringResource {
            LocalizedStringResource("device.rightBattery", defaultValue: "Right Battery", comment: "Device interface label or message: rightBattery.")
        }

        static var leftBattery: LocalizedStringResource {
            LocalizedStringResource("device.leftBattery", defaultValue: "Left Battery", comment: "Device interface label or message: leftBattery.")
        }

        static var caseBattery: LocalizedStringResource {
            LocalizedStringResource("device.caseBattery", defaultValue: "Case Battery", comment: "Device interface label or message: caseBattery.")
        }

        static var overallBattery: LocalizedStringResource {
            LocalizedStringResource("device.overallBattery", defaultValue: "Overall Battery", comment: "Device interface label or message: overallBattery.")
        }

        static func batteryPercentage(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("device.batteryPercentage", defaultValue: "\(value)%", comment: "Battery percentage; the argument is a number from 0 to 100.")
        }

        static func action(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("device.action", defaultValue: "Action \(value)", comment: "Fallback shortcut action name; the argument is the action identifier, not a count.")
        }

        static func battery(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("device.battery", defaultValue: "Battery \(value)", comment: "Fallback battery label; the argument is the component identifier, not a count.")
        }
    }

    enum Errors {
        static var disconnected: LocalizedStringResource {
            LocalizedStringResource("errors.disconnected", defaultValue: "The device disconnected. Check its connection.", comment: "Errors interface label or message: disconnected.")
        }

        static var timeout: LocalizedStringResource {
            LocalizedStringResource("errors.timeout", defaultValue: "The device did not respond. BoseKit will try to reconnect shortly.", comment: "Errors interface label or message: timeout.")
        }

        static var transport: LocalizedStringResource {
            LocalizedStringResource("errors.transport", defaultValue: "The Bluetooth connection failed. Check that your device is on and BoseKit has Bluetooth access.", comment: "Errors interface label or message: transport.")
        }

        static var unsupported: LocalizedStringResource {
            LocalizedStringResource("errors.unsupported", defaultValue: "This feature is not supported by this device or its current mode.", comment: "Errors interface label or message: unsupported.")
        }

        static var rejected: LocalizedStringResource {
            LocalizedStringResource("errors.rejected", defaultValue: "The device rejected this change. Check the current mode and connection.", comment: "Errors interface label or message: rejected.")
        }

        static var verification: LocalizedStringResource {
            LocalizedStringResource("errors.verification", defaultValue: "The verified setting differs from the requested value. Refresh to check the current setting.", comment: "Errors interface label or message: verification.")
        }

        static var invalidValue: LocalizedStringResource {
            LocalizedStringResource("errors.invalidValue", defaultValue: "The setting could not be applied. Check the value you entered.", comment: "Errors interface label or message: invalidValue.")
        }
    }

    enum Language {
        static var englishUK: LocalizedStringResource {
            LocalizedStringResource("language.englishUK", defaultValue: "English (UK)", comment: "Language interface label or message: englishUK.")
        }

        static var englishUS: LocalizedStringResource {
            LocalizedStringResource("language.englishUS", defaultValue: "English (US)", comment: "Language interface label or message: englishUS.")
        }

        static var french: LocalizedStringResource {
            LocalizedStringResource("language.french", defaultValue: "French", comment: "Language interface label or message: french.")
        }

        static var italian: LocalizedStringResource {
            LocalizedStringResource("language.italian", defaultValue: "Italian", comment: "Language interface label or message: italian.")
        }

        static var german: LocalizedStringResource {
            LocalizedStringResource("language.german", defaultValue: "German", comment: "Language interface label or message: german.")
        }

        static var spanish: LocalizedStringResource {
            LocalizedStringResource("language.spanish", defaultValue: "Spanish", comment: "Language interface label or message: spanish.")
        }

        static var spanishMexico: LocalizedStringResource {
            LocalizedStringResource("language.spanishMexico", defaultValue: "Spanish (Mexico)", comment: "Language interface label or message: spanishMexico.")
        }

        static var portuguese: LocalizedStringResource {
            LocalizedStringResource("language.portuguese", defaultValue: "Portuguese", comment: "Language interface label or message: portuguese.")
        }

        static var mandarin: LocalizedStringResource {
            LocalizedStringResource("language.mandarin", defaultValue: "Mandarin Chinese", comment: "Language interface label or message: mandarin.")
        }

        static var korean: LocalizedStringResource {
            LocalizedStringResource("language.korean", defaultValue: "Korean", comment: "Language interface label or message: korean.")
        }

        static var russian: LocalizedStringResource {
            LocalizedStringResource("language.russian", defaultValue: "Russian", comment: "Language interface label or message: russian.")
        }

        static var polish: LocalizedStringResource {
            LocalizedStringResource("language.polish", defaultValue: "Polish", comment: "Language interface label or message: polish.")
        }

        static var hebrew: LocalizedStringResource {
            LocalizedStringResource("language.hebrew", defaultValue: "Hebrew", comment: "Language interface label or message: hebrew.")
        }

        static var turkish: LocalizedStringResource {
            LocalizedStringResource("language.turkish", defaultValue: "Turkish", comment: "Language interface label or message: turkish.")
        }

        static var dutch: LocalizedStringResource {
            LocalizedStringResource("language.dutch", defaultValue: "Dutch", comment: "Language interface label or message: dutch.")
        }

        static var japanese: LocalizedStringResource {
            LocalizedStringResource("language.japanese", defaultValue: "Japanese", comment: "Language interface label or message: japanese.")
        }

        static var cantonese: LocalizedStringResource {
            LocalizedStringResource("language.cantonese", defaultValue: "Cantonese", comment: "Language interface label or message: cantonese.")
        }

        static var arabic: LocalizedStringResource {
            LocalizedStringResource("language.arabic", defaultValue: "Arabic", comment: "Language interface label or message: arabic.")
        }

        static var swedish: LocalizedStringResource {
            LocalizedStringResource("language.swedish", defaultValue: "Swedish", comment: "Language interface label or message: swedish.")
        }

        static var danish: LocalizedStringResource {
            LocalizedStringResource("language.danish", defaultValue: "Danish", comment: "Language interface label or message: danish.")
        }

        static var norwegian: LocalizedStringResource {
            LocalizedStringResource("language.norwegian", defaultValue: "Norwegian", comment: "Language interface label or message: norwegian.")
        }

        static var finnish: LocalizedStringResource {
            LocalizedStringResource("language.finnish", defaultValue: "Finnish", comment: "Language interface label or message: finnish.")
        }

        static var hindi: LocalizedStringResource {
            LocalizedStringResource("language.hindi", defaultValue: "Hindi", comment: "Language interface label or message: hindi.")
        }

        static func unknown(_ value: UInt8) -> LocalizedStringResource {
            LocalizedStringResource("language.unknown", defaultValue: "Language \(value)", comment: "Fallback voice prompt language; the argument is the language identifier, not a count.")
        }
    }
}

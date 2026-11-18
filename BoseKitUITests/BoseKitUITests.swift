import XCTest

final class BoseKitUITests: XCTestCase {
    @MainActor
    func testLiveDeviceReadOnly() async throws {
        guard ProcessInfo.processInfo.environment["BOSEKIT_RUN_HARDWARE_UI"] == "1" else {
            throw XCTSkip("Set BOSEKIT_RUN_HARDWARE_UI=1 in the test scheme to inspect a paired physical device.")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-hideWhenUnavailable", "NO", "-AppleLanguages", "(en)"]
        app.launch()
        app.activate()
        defer { app.terminate() }
        let window = app.windows["BoseKit"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let hasControls = window.sliders.firstMatch.waitForExistence(timeout: 25)
        let reset = window.buttons["Reset Equalizer"]
        XCTAssertTrue(reset.exists)
        for _ in 0..<24 {
            XCTAssertTrue(reset.isEnabled, "Polling disabled the controls")
            try await Task.sleep(for: .milliseconds(500))
        }
        for page in ["Sound", "Device"] {
            window.radioButtons[page].click()
            XCTAssertTrue(window.staticTexts["Connected"].waitForExistence(timeout: 8))
            let attachment = XCTAttachment(screenshot: window.screenshot())
            attachment.name = "Live read-only \(page)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(hasControls, "Live device controls did not load: \(window.debugDescription)")
    }

    @MainActor
    func testEnglishPreferencesWithHiddenMenuIcon() throws {
        try checkPreferences(locale: "en", title: "Menu Bar")
    }

    @MainActor
    func testKoreanPreferencesWithHiddenMenuIcon() throws {
        try checkPreferences(locale: "ko", title: "메뉴 막대")
    }

    @MainActor
    private func checkPreferences(locale: String, title: String) throws {
        let app = XCUIApplication()
        app.launchEnvironment["BOSEKIT_DISABLE_BLUETOOTH"] = "1"
        app.launchArguments = ["-hideWhenUnavailable", "NO", "-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        app.launch()
        app.activate()
        defer { app.terminate() }
        let window = app.windows["BoseKit"]
        guard window.waitForExistence(timeout: 10) else {
            XCTFail("Control window is missing: \(app.debugDescription)")
            return
        }
        let appTab = window.radioButtons[locale == "ko" ? "앱" : "App"]
        guard appTab.waitForExistence(timeout: 5) else {
            XCTFail("App tab is missing: \(window.debugDescription)")
            return
        }
        XCTAssertEqual(window.radioButtons.count, 3)
        XCTAssertFalse(window.radioButtons[locale == "ko" ? "모드" : "Modes"].exists)
        appTab.click()
        XCTAssertTrue(window.staticTexts[title].exists)
        let hide = window.switches["hideWhenUnavailable"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        let statusItem = app.descendants(matching: .statusItem).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        hide.click()
        XCTAssertTrue(statusItem.waitForNonExistence(timeout: 5))
        XCTAssertTrue(window.exists)
        XCTAssertTrue(window.switches["showBattery"].exists)
        hide.click()
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = "BoseKit preferences \(locale)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

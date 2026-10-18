import XCTest

final class NativeUtilityTests: XCTestCase {
    func testSemanticValuesRefreshOnExistingElement() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(bundleIdentifier: "app.curseofstrahd.nativeprobe")
        app.launch()
        let field = app.buttons["Update search value"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(field.value as? String, "before", app.debugDescription)
        XCTAssertFalse(field.isSelected, app.debugDescription)
        field.tap()
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "zzzz"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 10), .completed, app.debugDescription)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, app.debugDescription)
        field.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND selected == false", "before"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed, app.debugDescription)
    }

    func testSwitchStateMatchesItsSelectionAfterEachTap() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(bundleIdentifier: "app.curseofstrahd.nativeprobe")
        app.launch()
        let toggle = app.buttons["Reduce extra motion"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(toggle.value as? String, "Off", app.debugDescription)
        XCTAssertFalse(toggle.isSelected, app.debugDescription)
        for enabled in [true, false] {
            toggle.tap()
            let state = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND selected == %@", enabled ? "On" : "Off", NSNumber(value: enabled)), object: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [state], timeout: 10), .completed, app.debugDescription)
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "switch-off-after-two-taps"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFilesPickerAndShareSheetCanBeCancelled() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(bundleIdentifier: "app.curseofstrahd.nativeprobe")
        app.launch()
        // This fixture uses the real compiled extension and UIKit, with a minimal Godot scene.
        let share = app.buttons["Share test save"]
        XCTAssertTrue(share.waitForExistence(timeout: 20), app.debugDescription)
        share.tap()
        let saveToFiles = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 10), app.debugDescription)
        let close = app.buttons["Close"]
        if close.exists { close.tap() } else { app.swipeDown() }
        XCTAssertTrue(app.staticTexts["file_cancelled"].waitForExistence(timeout: 10), app.debugDescription)
        let pick = app.buttons["Import JSON from Files"]
        XCTAssertTrue(pick.waitForExistence(timeout: 10))
        pick.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(pick.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testJSONCanBeExportedAndImportedThroughFiles() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(bundleIdentifier: "app.curseofstrahd.nativeprobe")
        app.launch()
        let share = app.buttons["Share test save"]
        XCTAssertTrue(share.waitForExistence(timeout: 20), app.debugDescription)
        let filename = app.staticTexts["save_filename"].label
        share.tap()
        let saveToFiles = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 10), app.debugDescription)
        saveToFiles.tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), app.debugDescription)
        if !save.isEnabled {
            let local = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "On My")).firstMatch
            XCTAssertTrue(local.waitForExistence(timeout: 10), app.debugDescription)
            local.tap()
        }
        XCTAssertTrue(save.isEnabled, app.debugDescription)
        save.tap()
        let replace = app.buttons["Replace"]
        if replace.waitForExistence(timeout: 2) { replace.tap() }
        XCTAssertTrue(app.staticTexts["file_shared"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["Import JSON from Files"].tap()
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", filename)).firstMatch
        if !file.waitForExistence(timeout: 5) {
            let browse = app.buttons["Browse"]
            if browse.exists { browse.tap() }
            let local = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "On My")).firstMatch
            if local.waitForExistence(timeout: 3) { local.tap() }
            let downloads = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "Downloads")).firstMatch
            if downloads.waitForExistence(timeout: 3) { downloads.tap() }
        }
        XCTAssertTrue(file.waitForExistence(timeout: 10), app.debugDescription)
        file.tap()
        XCTAssertTrue(app.staticTexts["file_imported"].waitForExistence(timeout: 10), app.debugDescription)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}

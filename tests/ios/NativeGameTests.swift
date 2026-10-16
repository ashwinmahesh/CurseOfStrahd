import XCTest

/// Journeys through the shipping game and native accessibility bridge, without test-only game commands.
final class NativeGameTests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "app.curseofstrahd.game")

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(app.buttons["New game"].waitForExistence(timeout: 90), app.debugDescription)
    }

    func capture(_ name: String) {
        XCTAssertFalse(app.staticTexts["Something went wrong"].exists, app.debugDescription)
        // Capture the display: the Godot host's app crop can retain portrait bounds after rotation.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    func tap(_ label: String, scroll: Bool = true) -> XCUIElement {
        var button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        for _ in 0..<(scroll ? 32 : 30) {
            // Resolve afresh after scrolling or a modal transition: UIKit's semantic elements move while
            // Godot draws, and a retained XCTest element can keep its earlier clipped hit rectangle.
            button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if button.waitForExistence(timeout: scroll ? 1 : 2) && button.isHittable {
                XCTAssertTrue(button.isEnabled, app.debugDescription)
                button.tap()
                return button
            }
            if scroll { scrollBody() }
        }
        XCTFail("Missing button: \(label)\n\(app.debugDescription)")
        return button
    }

    func scrollBody() {
        // Start inside the page body, below fixed headers and horizontal tab strips.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.84))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.34))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
    }

    func waitForWorld() {
        for _ in 0..<60 {
            if app.staticTexts["Something went wrong"].exists {
                XCTFail("Game reported an error during the world transition\n\(app.debugDescription)")
                return
            }
            if app.buttons["Actions"].waitForExistence(timeout: 2) { return }
            let skip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Skip")).firstMatch
            if skip.exists && skip.isHittable { skip.tap() }
        }
        XCTFail("World did not become interactive\n\(app.debugDescription)")
    }

    func testCampaignInventoryCameraSaveAndRelaunch() throws {
        capture("title")
        tap("New game")
        tap("Go on with these 4")
        tap("Begin on Balanced")
        tap("Start campaign")
        waitForWorld()
        capture("campaign")
        tap("Actions", scroll: false)
        tap("Inventory")
        XCTAssertTrue(app.buttons["Equipment"].waitForExistence(timeout: 60), app.debugDescription)
        capture("inventory")
        tap("Equipment", scroll: false)
        capture("equipment")
        tap("Back", scroll: false)
        tap("More", scroll: false)
        tap("Camera")
        tap("Zoom in")
        tap("Turn right")
        tap("Recenter")
        capture("camera-controls")
        tap("Back", scroll: false)
        tap("Actions", scroll: false)
        tap("Journal")
        capture("journal")
        tap("Back", scroll: false)
        tap("Menu", scroll: false)
        tap("Save game")
        tap("New save")
        capture("saved")
        // A normal termination must retain the saved campaign and the Continue route.
        app.terminate()
        app.launch()
        tap("Continue")
        waitForWorld()
        capture("campaign-after-relaunch")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout: 15), app.debugDescription)
        tap("Continue", scroll: false)
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 15), app.debugDescription)
        capture("campaign-after-interruption")
    }

    func testBattlefieldActionsAndPracticeRecovery() throws {
        tap("Skirmish and Character Lab")
        tap("Godrick Pendlebrook")
        tap("Add hero")
        tap("Foes", scroll: false)
        let search = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Search creatures by name or type")).firstMatch
        for _ in 0..<8 {
            if search.waitForExistence(timeout: 1) && search.isHittable { break }
            scrollBody()
        }
        XCTAssertTrue(search.exists, app.debugDescription)
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        let keyboardIntroduction = app.otherElements["UIContinuousPathIntroductionView"]
        if keyboardIntroduction.waitForExistence(timeout: 1) {
            keyboardIntroduction.buttons["Continue"].tap()
        }
        capture("creature-search-keyboard")
        // Godot's text editor uses a UIKit input responder behind the semantic game view. Touch the real
        // keyboard keys, as a player does, instead of requiring XCTest's native text-field focus metadata.
        for character in "zombie" {
            let key = app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", String(character))).firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 5), app.debugDescription)
            key.tap()
        }
        if app.buttons["Done"].waitForExistence(timeout: 5) { tap("Done", scroll: false) }
        let zombie = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Zombie · CR")).firstMatch
        for _ in 0..<8 {
            if zombie.waitForExistence(timeout: 1) && zombie.isHittable { break }
            scrollBody()
        }
        XCTAssertTrue(zombie.exists, app.debugDescription)
        zombie.tap()
        tap("Add foe")
        tap("Review and fight")
        capture("fight-review")
        tap("Fight")
        waitForWorld()
        capture("battlefield")
        tap("Actions", scroll: false)
        XCTAssertTrue(app.buttons["Common"].waitForExistence(timeout: 60), app.debugDescription)
        capture("combat-actions")
        tap("Close", scroll: false)
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Common"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 60), .completed, "Actions must not cover the battlefield after closing")
        tap("Actions", scroll: false)
        XCTAssertTrue(app.buttons["Common"].waitForExistence(timeout: 60))
        tap("Close", scroll: false)
        tap("More", scroll: false)
        tap("Choose a creature to target")
        capture("target-list")
        tap("Back", scroll: false)
        let round = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Round ")).firstMatch
        XCTAssertTrue(round.waitForExistence(timeout: 10))
        let turnBeforeRelaunch = round.label
        app.terminate()
        app.launch()
        tap("Resume practice battle")
        waitForWorld()
        XCTAssertEqual(round.label, turnBeforeRelaunch, "Practice recovery restores the committed turn")
        capture("practice-after-relaunch")
    }
}

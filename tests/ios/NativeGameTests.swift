import XCTest
import UIKit

/// Journeys through the shipping game and native accessibility bridge, without test-only game commands.
final class NativeGameTests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "app.curseofstrahd.game")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--", "--native-ui-testing"]
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
        for attempt in 0..<(scroll ? 32 : 30) {
            // Resolve afresh after scrolling or a modal transition: UIKit's semantic elements move while
            // Godot draws, and a retained XCTest element can keep its earlier clipped hit rectangle.
            button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if button.waitForExistence(timeout: scroll ? 1 : 2) && button.isHittable {
                XCTAssertTrue(button.isEnabled, app.debugDescription)
                button.tap()
                return button
            }
            // A page may retain its position, or arrive after the first swipe. Search both
            // directions so a control above the current viewport remains reachable.
            if scroll { scrollBody(upward: attempt % 16 >= 8) }
        }
        XCTFail("Missing button: \(label)\n\(app.debugDescription)")
        return button
    }

    func enterSearch(_ label: String, text: String) {
        tap(label)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        if introduction.waitForExistence(timeout: 1) { introduction.buttons["Continue"].tap() }
        for character in text {
            let key = app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", String(character))).firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 5), app.debugDescription)
            key.tap()
        }
        let queryEntered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value ==[c] %@", text), object: app.buttons[label])
        XCTAssertEqual(XCTWaiter.wait(for: [queryEntered], timeout: 60), .completed, "The search field must receive every software-keyboard character")
    }

    func scrollBody(upward: Bool = false) {
        // Start inside the page body, below fixed headers and horizontal tab strips.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: upward ? 0.34 : 0.84))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: upward ? 0.84 : 0.34))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
    }

    func waitForWorld() {
        for _ in 0..<60 {
            if app.staticTexts["Something went wrong"].exists {
                XCTFail("Game reported an error during the world transition\n\(app.debugDescription)")
                return
            }
            if app.buttons["Menu"].waitForExistence(timeout: 1) || app.buttons["Battle Menu"].waitForExistence(timeout: 1) { return }
            let skip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Skip")).firstMatch
            if skip.exists && skip.isHittable { skip.tap() }
        }
        XCTFail("World did not become interactive\n\(app.debugDescription)")
    }

    func testInventoryRarityFilterRecoversWithoutLosingTheBag() throws {
        tap("New game")
        tap("Go on with these 4")
        tap("Begin on Balanced")
        tap("Start campaign")
        waitForWorld()
        tap("Menu", scroll: false)
        tap("Inventory")
        tap("Filters")
        tap("Legendary")
        capture("inventory-rarity-selected")
        tap("Show filtered items")
        XCTAssertTrue(app.buttons["Show all items"].waitForExistence(timeout: 60), app.debugDescription)
        capture("inventory-rarity-empty")
        tap("Show all items")
        let recovered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Show all items"])
        XCTAssertEqual(XCTWaiter.wait(for: [recovered], timeout: 60), .completed)
        capture("inventory-rarity-recovered")
        tap("Filters")
        let legendary = app.buttons["Legendary"]
        XCTAssertTrue(legendary.waitForExistence(timeout: 60), app.debugDescription)
        XCTAssertFalse(legendary.isSelected, "Recovery clears the rarity filter as well as search and marks")
        tap("Show filtered items")
        tap("Back", scroll: false)
        waitForWorld()
    }

    func testCampaignInventoryCameraSaveAndRelaunch() throws {
        capture("title")
        tap("New game")
        tap("Go on with these 4")
        tap("Begin on Balanced")
        tap("Start campaign")
        waitForWorld()
        capture("campaign")
        tap("Menu", scroll: false)
        tap("Inventory")
        XCTAssertTrue(app.buttons["Equipment"].waitForExistence(timeout: 60), app.debugDescription)
        capture("inventory")
        enterSearch("Search items", text: "zzzz")
        capture("inventory-search-keyboard")
        tap("Done", scroll: false)
        XCTAssertTrue(app.buttons["Show all items"].waitForExistence(timeout: 10), app.debugDescription)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(app.buttons["Show all items"].waitForExistence(timeout: 10), app.debugDescription)
        capture("inventory-search-rotated")
        tap("Show all items", scroll: false)
        // UIKit idleness does not imply Godot has processed the deferred touch and semantic snapshot.
        let filtersCleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Show all items"])
        XCTAssertEqual(XCTWaiter.wait(for: [filtersCleared], timeout: 60), .completed, "Clearing filters must restore the inventory after rotation")
        capture("inventory-search-cleared")
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("Equipment", scroll: false)
        capture("equipment")
        tap("Back", scroll: false)
        tap("Menu", scroll: false)
        tap("Camera")
        tap("Zoom in")
        tap("Turn right")
        tap("Recenter")
        capture("camera-controls")
        tap("Back", scroll: false)
        tap("Menu", scroll: false)
        tap("Journal")
        capture("journal")
        tap("Back", scroll: false)
        tap("Menu", scroll: false)
        tap("Save and settings")
        tap("Settings")
        tap("Display", scroll: false)
        let motion = app.buttons["Reduce extra motion"]
        XCTAssertTrue(motion.waitForExistence(timeout: 15), app.debugDescription)
        let wasReduced = motion.isSelected
        motion.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == %@", NSNumber(value: !wasReduced)), object: motion)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
        capture("mobile-display-preferences")
        motion.tap()
        tap("Back", scroll: false)
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
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 60), app.debugDescription)
        capture("campaign-after-interruption")
    }

    func testIPadPortraitPreservesInventorySearchAndNavigation() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad orientation journey") }
        tap("Continue")
        waitForWorld()
        tap("Menu", scroll: false)
        tap("Inventory")
        enterSearch("Search items", text: "zzzz")
        tap("Done", scroll: false)
        let enteredQuery = app.buttons["Search items"].value as? String
        XCTAssertNotNil(enteredQuery)
        for orientation: UIDeviceOrientation in [.portrait, .portraitUpsideDown, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.buttons["Show all items"].waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertEqual(app.buttons["Search items"].value as? String, enteredQuery, "Rotation must retain the exact entered query, including keyboard capitalization")
            // Check real display geometry, rather than accepting a simulator device rotation with a locked app.
            let portrait = orientation == .portrait || orientation == .portraitUpsideDown
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let size = XCUIScreen.main.screenshot().image.size
                return portrait ? size.height > size.width : size.width > size.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 15), .completed, "The game must rotate on iPad")
            capture("ipad-inventory-\(orientation.rawValue)")
        }
        tap("Show all items", scroll: false)
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Show all items"])
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 60), .completed)
        tap("Back", scroll: false)
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 60), app.debugDescription)
        capture("ipad-world-after-rotation")
    }

    func testBackgroundResumePreservesTheCurrentScreen() throws {
        // Exercise the title and a real campaign without replaying unrelated inventory steps.
        for round in 0..<3 {
            if round == 1 {
                tap("Continue")
                waitForWorld()
            }
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
            app.activate()
            XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout: 15), app.debugDescription)
            capture("resume-pause-\(round)")
            tap("Continue", scroll: false)
            let restored = round == 0 ? app.buttons["New game"] : app.buttons["Menu"]
            XCTAssertTrue(restored.waitForExistence(timeout: 60), app.debugDescription)
            capture("resume-cycle-\(round)")
        }
    }

    func testFullPagesReturnToTheWorld() throws {
        tap("Continue")
        waitForWorld()
        capture("performance-world-before")
        let start = Date()
        for page in ["Inventory", "Journal", "Inventory"] {
            tap("Menu", scroll: false)
            tap(page)
            let heading = page == "Inventory" ? app.buttons["Equipment"] : app.staticTexts["Journal"]
            XCTAssertTrue(heading.waitForExistence(timeout: 60), app.debugDescription)
            capture("performance-page-\(page)")
            tap("Back", scroll: false)
            XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 60), app.debugDescription)
            capture("performance-world-after-\(page)")
        }
        print("NATIVE_PAGE_JOURNEY_SECONDS \(Date().timeIntervalSince(start))")
    }

    func testExplorationMenuKeepsWorldClear() throws {
        // This continuation journey uses the campaign created by the campaign test (or an existing QA save).
        tap("Continue")
        waitForWorld()
        XCTAssertFalse(app.buttons["Actions"].exists, "Exploration must not retain the combat action bar")
        XCTAssertFalse(app.buttons["More"].exists, "Secondary controls belong inside Menu")
        let frame = app.windows.firstMatch.frame
        let regular = max(frame.width, frame.height) >= 900 && min(frame.width, frame.height) >= 600
        XCTAssertEqual(app.buttons["Party"].exists, regular)
        XCTAssertEqual(app.buttons["Inventory"].exists, regular)
        capture("exploration-quiet")
        tap("Menu", scroll: false)
        XCTAssertTrue(app.buttons["Inventory"].waitForExistence(timeout: 60))
        capture("exploration-menu")
        tap("Nearby objects")
        capture("nearby-objects")
        enterSearch("Search nearby objects", text: "zzzz")
        capture("nearby-search-keyboard")
        tap("Done", scroll: false)
        tap("Clear search")
        tap("Back", scroll: false)
        tap("Inventory")
        XCTAssertTrue(app.buttons["Equipment"].waitForExistence(timeout: 60))
        tap("Back", scroll: false)
        tap("Menu", scroll: false)
        tap("Messages and narration")
        capture("exploration-messages")
        tap("Back", scroll: false)
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.buttons["Actions"].exists)
        capture("exploration-after-menu")
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
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 60), app.debugDescription)
        XCTAssertTrue(app.buttons["End Turn"].waitForExistence(timeout: 60), app.debugDescription)
        capture("battlefield")
        tap("Actions", scroll: false)
        XCTAssertTrue(app.buttons["All ▾"].waitForExistence(timeout: 60), app.debugDescription)
        capture("combat-actions")
        tap("Close", scroll: false)
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["All ▾"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 60), .completed, "Actions must not cover the battlefield after closing")
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 60), app.debugDescription)
        XCTAssertTrue(app.buttons["End Turn"].waitForExistence(timeout: 60), app.debugDescription)
        capture("battlefield-actions-closed")
        tap("Actions", scroll: false)
        XCTAssertTrue(app.buttons["All ▾"].waitForExistence(timeout: 60))
        tap("Close", scroll: false)
        tap("Battle Menu", scroll: false)
        tap("More controls")
        tap("Choose a creature to target")
        capture("target-list")
        tap("Back", scroll: false)
        let round = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " · Round ")).firstMatch
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

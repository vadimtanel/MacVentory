import XCTest

@MainActor
final class MacventoryUITests: XCTestCase {
    private func inventoryTable(_ app: XCUIApplication) -> XCUIElement {
        // SwiftUI Table is an AXOutline on macOS 26; identify the actual inventory,
        // not the first outline (which is the sidebar) or an assumed AXTable role.
        let table = app.descendants(matching: .any).matching(identifier: "inventory.table").firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertTrue(table.elementType == .outline || table.elementType == .table)
        return table
    }

    private func closeSettings(_ app: XCUIApplication, save: Bool = false) {
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        let button = sheet.buttons[save ? "settings.done" : "settings.cancel"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertTrue(button.isHittable, "Settings actions must be visible above the Dock")
        button.click()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed,
                       "The sheet must close before reopening settings or opening About")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        return app
    }
    func testStartupSidebarSelectionAndDetails() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["All Software"].exists)
        XCTAssertTrue(app.staticTexts["Homebrew Formulae"].firstMatch.exists)
        let row = inventoryTable(app).staticTexts["Example App"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()
        XCTAssertTrue(app.buttons["Copy Identifier"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["org.example.app"].exists)
    }
    func testSearchAndEmptyState() {
        let app = launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.click(); search.typeText("does-not-exist")
        XCTAssertTrue(app.staticTexts["No matching software"].waitForExistence(timeout: 3))
        search.typeKey("a", modifierFlags: .command); search.typeKey(.delete, modifierFlags: [])
        XCTAssertEqual(search.value as? String, "")
        XCTAssertTrue(inventoryTable(app).staticTexts["Example App"].firstMatch.waitForExistence(timeout: 3))
    }
    func testRefreshCancelAndFilters() {
        let app = launch()
        app.buttons["inventory.filters"].click()
        XCTAssertTrue(app.checkBoxes["Missing metadata"].exists)
        app.buttons["inventory.refresh"].click()
        XCTAssertTrue(app.buttons["inventory.cancel"].waitForExistence(timeout: 1))
        app.buttons["inventory.cancel"].click()
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
    }
    func testKeyboardRefreshAndSettings() {
        let app = launch()
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(app.buttons["inventory.cancel"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
        app.buttons["Settings"].firstMatch.click()
        XCTAssertTrue(app.checkBoxes["Show system applications"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.popUpButtons.firstMatch.exists)
    }
    func testUninstallConfirmationSimulationAndCancel() {
        let app = launch()
        inventoryTable(app).staticTexts["Example App"].firstMatch.click()
        app.buttons["inventory.uninstall"].click()
        let confirm = app.buttons["uninstall.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        XCTAssertFalse(confirm.exists)
        app.buttons["inventory.uninstall"].click()
        XCTAssertFalse(app.textFields["uninstall.confirmName"].exists)
        XCTAssertTrue(app.buttons["Move to Trash"].waitForExistence(timeout: 3))
        app.checkBoxes["uninstall.acknowledge"].click()
        XCTAssertTrue(confirm.isEnabled)
        confirm.click()
        XCTAssertTrue(app.staticTexts["Simulation completed. Nothing was removed or modified."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["uninstall.ok"].exists)
        XCTAssertFalse(app.buttons["uninstall.confirm"].exists)
        XCTAssertFalse(app.checkBoxes["uninstall.acknowledge"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists)
        app.buttons["uninstall.ok"].click()
        XCTAssertFalse(app.buttons["uninstall.ok"].exists)
    }
    func testNativeRowPrimaryActionAndProtectedPreview() {
        let app = launch()
        let row = inventoryTable(app).staticTexts["Example App"].firstMatch
        row.click()
        XCTAssertFalse(app.buttons["uninstall.confirm"].exists)
        row.doubleClick()
        let confirm = app.buttons["uninstall.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.checkBoxes["uninstall.acknowledge"].click()
        XCTAssertTrue(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        row.doubleClick()
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        inventoryTable(app).staticTexts["example-tool"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        row.rightClick()
        XCTAssertTrue(app.menuItems["Copy Identifier"].exists)
        XCTAssertTrue(app.menuItems["Uninstall…"].exists)
        app.typeKey(.escape, modifierFlags: [])
        app.buttons["Settings"].click()
        app.checkBoxes["Show system applications"].click()
        closeSettings(app, save: true)
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
        inventoryTable(app).staticTexts["Example System Component"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
    }

    func testColumnVisibilityMenu() {
        let app = launch()
        if #available(macOS 14, *) {
            XCTAssertTrue(inventoryTable(app).buttons["Version"].exists)
            app.buttons["inventory.columns"].click()
            XCTAssertTrue(app.checkBoxes["Version"].firstMatch.exists)
            app.checkBoxes["Version"].firstMatch.click()
            XCTAssertFalse(inventoryTable(app).buttons["Version"].exists)
            app.buttons["Reset Columns"].click()
            XCTAssertTrue(inventoryTable(app).buttons["Version"].exists)
        }
    }
    func testAllNativeHeaderSortsPreserveSelection() {
        let app = launch()
        let table = inventoryTable(app)
        table.staticTexts["Example App"].firstMatch.click()
        for title in ["Version", "Source", "Size", "Installed", "Last Opened", "Name"] {
            let header = table.buttons[title]
            XCTAssertTrue(header.exists)
            header.click()
            XCTAssertTrue(app.buttons["Copy Identifier"].exists)
            header.click()
            XCTAssertTrue(app.buttons["Copy Identifier"].exists)
        }
        let search = app.searchFields.firstMatch
        search.click(); search.typeText("Example")
        table.buttons["Size"].click()
        XCTAssertTrue(table.staticTexts["Example App"].firstMatch.exists)
    }

    func testSettingsPagesThresholdInputAndAboutLinks() {
        let app = launch()
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        let days = app.textFields["Recently installed threshold"]
        XCTAssertTrue(days.waitForExistence(timeout: 3))
        days.click(); days.typeKey("a", modifierFlags: .command); days.typeText("28"); days.typeKey(.tab, modifierFlags: [])
        XCTAssertEqual(days.value as? String, "28")
        app.radioButtons["Scanning"].click()
        XCTAssertTrue(app.textFields["Homebrew prefixes"].exists)
        app.radioButtons["Information"].click()
        XCTAssertTrue(app.buttons["Export Sanitized Diagnostics…"].exists)
        closeSettings(app, save: true)
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        XCTAssertEqual(app.textFields["Recently installed threshold"].value as? String, "28")
        closeSettings(app)
        app.buttons["About"].click()
        let about = app.windows["About Macventory"]
        XCTAssertTrue(about.waitForExistence(timeout: 3), "About must open after Settings closes")
        XCTAssertTrue(about.links["LinkedIn"].waitForExistence(timeout: 3))
        XCTAssertTrue(about.links["GitHub Profile"].exists)
        XCTAssertTrue(about.links["Macventory Repository"].exists)
    }

    func testCancelDiscardsDraftAcrossPages() {
        let app = launch()
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        let field = app.textFields["Recently installed threshold"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "30", "Each fixture launch starts with default settings")
        field.click(); field.typeKey("a", modifierFlags: .command); field.typeText("28"); field.typeKey(.tab, modifierFlags: [])
        XCTAssertEqual(field.value as? String, "28")
        app.radioButtons["Scanning"].click()
        XCTAssertTrue(app.textFields["Homebrew prefixes"].exists)
        closeSettings(app)
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        XCTAssertEqual(app.textFields["Recently installed threshold"].value as? String, "30")
    }

}

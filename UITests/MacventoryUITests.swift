import XCTest

@MainActor
final class MacventoryUITests: XCTestCase {
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
        let row = app.tables.firstMatch.staticTexts["Example App"].firstMatch
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
        search.typeKey("a", modifierFlags: .command); search.typeKey(.delete)
        XCTAssertTrue(app.tables.firstMatch.staticTexts["Example App"].firstMatch.waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.buttons["Show system applications"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.popUpButtons.firstMatch.exists)
    }
    func testUninstallConfirmationSimulationAndCancel() {
        let app = launch()
        app.tables.firstMatch.staticTexts["Example App"].firstMatch.click()
        app.buttons["inventory.uninstall"].click()
        let confirm = app.buttons["management.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        XCTAssertFalse(confirm.exists)
        app.buttons["inventory.uninstall"].click()
        XCTAssertFalse(app.textFields["uninstall.confirmName"].exists)
        let uninstall = app.checkBoxes["management.uninstall"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: uninstall)
        waitForExpectations(timeout: 10)
        uninstall.click()
        app.checkBoxes["management.acknowledge"].click()
        XCTAssertTrue(confirm.isEnabled)
        confirm.click()
        XCTAssertTrue(app.staticTexts["Operation completed."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["management.ok"].exists)
        XCTAssertFalse(app.buttons["management.confirm"].exists)
        XCTAssertFalse(app.checkBoxes["management.acknowledge"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists)
        app.buttons["management.ok"].click()
        XCTAssertFalse(app.buttons["management.ok"].exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        app.tables.firstMatch.staticTexts["Example App"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["management.cancel"].click()
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }
    func testNativeRowPrimaryActionAndProtectedPreview() {
        let app = launch()
        let row = app.tables.firstMatch.staticTexts["Example App"].firstMatch
        row.click()
        XCTAssertFalse(app.buttons["management.confirm"].exists)
        row.doubleClick()
        let confirm = app.buttons["management.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        let uninstall = app.checkBoxes["management.uninstall"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: uninstall)
        waitForExpectations(timeout: 10)
        uninstall.click()
        app.checkBoxes["management.acknowledge"].click()
        XCTAssertTrue(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        row.doubleClick()
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        app.tables.firstMatch.staticTexts["example-tool"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].firstMatch.click()
        row.rightClick()
        XCTAssertTrue(app.menuItems["Copy Identifier"].exists)
        XCTAssertTrue(app.menuItems["Uninstall…"].exists)
        XCTAssertFalse(app.menuItems["Force Quit"].exists)
        XCTAssertFalse(app.menuItems["Manage Application…"].exists)
        XCTAssertFalse(app.menuItems["Clear App Data…"].exists)
        app.typeKey(.escape, modifierFlags: [])
        app.buttons["Settings"].click()
        app.buttons["Show system applications"].click()
        app.buttons["Done"].click()
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
        app.tables.firstMatch.staticTexts["Example System Component"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
    }

    func testRunningContextForceQuitOnlyHasSingleOKAndReopens() {
        let app = launch()
        let row = app.tables.firstMatch.staticTexts["Running Example"].firstMatch
        row.rightClick()
        XCTAssertTrue(app.menuItems["Force Quit"].exists)
        app.menuItems["Force Quit"].click()
        XCTAssertTrue(app.checkBoxes["management.forceQuit"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.checkBoxes["management.forceQuit"].value as? Int, 1)
        let review = app.checkBoxes["management.acknowledge"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: review); waitForExpectations(timeout: 10)
        review.click(); app.buttons["management.confirm"].click()
        XCTAssertTrue(app.buttons["management.ok"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["management.confirm"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists)
        app.buttons["management.ok"].click()
        XCTAssertFalse(app.sheets.firstMatch.exists)
        row.doubleClick()
        XCTAssertTrue(app.buttons["management.confirm"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["management.confirm"].isEnabled)
    }

    func testLeftoverCleanupRemovesOnlyResolvedSyntheticGroupAndRestoresInteraction() {
        let app = launch()
        app.staticTexts["Leftover Data"].firstMatch.click()
        let retired = app.staticTexts["Retired Studio"].firstMatch
        XCTAssertTrue(retired.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Empty Removed App"].exists)
        retired.click()
        app.buttons["Select All Verified Data"].click()
        let helper = app.checkBoxes.matching(NSPredicate(format: "label CONTAINS %@", "Caches/org.example.retired.share")).firstMatch
        XCTAssertEqual(helper.value as? Int, 0, "A friendly helper name must not enable automatic selection")
        helper.click() // Explicit individual review of this synthetic possible-only helper.
        app.buttons["leftovers.trash"].click()
        XCTAssertFalse(app.buttons["cleanup.confirm"].isEnabled)
        app.checkBoxes["cleanup.acknowledge"].click()
        app.buttons["cleanup.confirm"].click()
        XCTAssertTrue(app.buttons["cleanup.ok"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cleanup.confirm"].exists)
        app.buttons["cleanup.ok"].click()
        XCTAssertFalse(app.sheets.firstMatch.exists)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: retired); waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["net.example.unobserved"].exists)
        app.staticTexts["All Software"].firstMatch.click()
        XCTAssertTrue(app.tables.firstMatch.staticTexts["Example App"].firstMatch.exists)
    }

    func testLeftoverFooterSettingsOpensAndReturnsToSamePage() {
        let app = launch()
        app.staticTexts["Leftover Data"].firstMatch.click()
        XCTAssertTrue(app.textFields["leftovers.search"].waitForExistence(timeout: 5))
        app.buttons["Settings"].firstMatch.click()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(app.textFields["leftovers.search"].exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }

    func testColumnVisibilityMenu() {
        let app = launch()
        if #available(macOS 14, *) {
            app.buttons["inventory.columns"].click()
            XCTAssertTrue(app.checkBoxes["Version"].firstMatch.exists)
            app.checkBoxes["Version"].firstMatch.click()
            XCTAssertFalse(app.tables.firstMatch.buttons["Version"].exists)
            app.buttons["Reset Columns"].click()
        }
    }
    func testAllNativeHeaderSortsPreserveSelection() {
        let app = launch()
        let table = app.tables.firstMatch
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
        days.click(); days.typeKey("a", modifierFlags: .command); days.typeText("28"); days.typeKey(.tab)
        XCTAssertEqual(days.value as? String, "28")
        app.radioButtons["Scanning"].click()
        XCTAssertTrue(app.textFields["Homebrew prefixes"].exists)
        app.radioButtons["Information"].click()
        XCTAssertTrue(app.buttons["Export Sanitized Diagnostics…"].exists)
        app.buttons["Done"].click()
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        XCTAssertEqual(app.textFields["Recently installed threshold"].value as? String, "28")
        app.buttons["Cancel"].click()
        app.buttons["About"].click()
        XCTAssertTrue(app.links["LinkedIn"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.links["GitHub Profile"].exists)
        XCTAssertTrue(app.links["Macventory Repository"].exists)
    }

    func testCancelDiscardsDraftAcrossPages() {
        let app = launch()
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        let field = app.textFields["Recently installed threshold"]
        field.click(); field.typeKey("a", modifierFlags: .command); field.typeText("28"); field.typeKey(.tab)
        app.buttons["Cancel"].click()
        app.buttons["Settings"].click()
        app.radioButtons["Discovery"].click()
        XCTAssertEqual(app.textFields["Recently installed threshold"].value as? String, "30")
    }

}

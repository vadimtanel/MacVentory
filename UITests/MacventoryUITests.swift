import XCTest

@MainActor
final class MacventoryUITests: XCTestCase {
    private func clickVisible(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        let target = try XCTUnwrap(element.waitForExistence(timeout: 5) ? element : nil,
                                  "The control must exist before clicking", file: file, line: line)
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: target)
        let result = XCTWaiter.wait(for: [visible], timeout: 5)
        if result != .completed {
            let attachment = XCTAttachment(string: target.debugDescription)
            attachment.name = "Control failed hittability precondition"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        // XCTUnwrap records an assertion failure and throws, stopping the caller's
        // test as well as this helper. Never attempt a click after a failed guard.
        _ = try XCTUnwrap(result == .completed ? target : nil,
                          "The actual control must be hittable; no coordinate fallback", file: file, line: line)
        target.click()
    }

    private func recordHeaderState(_ app: XCUIApplication, phase: String) {
        XCTContext.runActivity(named: "Native header state: " + phase) { activity in
            let table = app.descendants(matching: .any).matching(identifier: "inventory.table").firstMatch
            var lines = ["Phase: " + phase, "Window: " + app.windows.firstMatch.debugDescription]
            for title in ["Name", "Version", "Source", "Size", "Installed", "Last Opened"] {
                let header = table.buttons[title]
                lines.append("\(title): exists=\(header.exists)" +
                             (header.exists ? " frame=\(header.frame) hittable=\(header.isHittable) value=\(String(describing: header.value))" : ""))
            }
            // Include ancestors, sibling overlays, scroll containers and Details,
            // not just the isolated header snapshot retained by the failed click.
            lines.append(app.debugDescription)
            let tree = XCTAttachment(string: lines.joined(separator: "\n"))
            tree.name = phase + " — header geometry and full accessibility tree"
            tree.lifetime = .keepAlways
            activity.add(tree)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = phase + " — screen"
            screen.lifetime = .keepAlways
            activity.add(screen)
        }
    }

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
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        // Actual rendered controls must remain inside the native content window.
        for control in [app.buttons["inventory.settings"], app.buttons["inventory.columns"]] {
            XCTAssertTrue(control.waitForExistence(timeout: 5))
            XCTAssertTrue(window.frame.contains(control.frame), "Control extends outside its inventory window")
            XCTAssertTrue(control.isHittable)
        }
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
    func testKeyboardRefreshAndSettings() throws {
        let app = launch()
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(app.buttons["inventory.cancel"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
        try clickVisible(app.buttons["inventory.settings"])
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
    func testNativeRowPrimaryActionAndProtectedPreview() throws {
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
        try clickVisible(app.buttons["inventory.settings"])
        app.checkBoxes["Show system applications"].click()
        closeSettings(app, save: true)
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
        inventoryTable(app).staticTexts["Example System Component"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
    }

    func testColumnVisibilityMenu() throws {
        let app = launch()
        if #available(macOS 14, *) {
            XCTAssertTrue(inventoryTable(app).buttons["Version"].exists)
            try clickVisible(app.buttons["inventory.columns"])
            XCTAssertTrue(app.checkBoxes["Version"].firstMatch.exists)
            app.checkBoxes["Version"].firstMatch.click()
            XCTAssertFalse(inventoryTable(app).buttons["Version"].exists)
            app.buttons["Reset Columns"].click()
            XCTAssertTrue(inventoryTable(app).buttons["Version"].exists)
        }
    }
    func testAllNativeHeaderSortsPreserveSelection() throws {
        let app = launch()
        let table = inventoryTable(app)
        recordHeaderState(app, phase: "before selection")
        table.staticTexts["Example App"].firstMatch.click()
        XCTAssertTrue(app.buttons["Copy Identifier"].waitForExistence(timeout: 3))
        recordHeaderState(app, phase: "after selection and Details")
        for title in ["Version", "Source", "Size", "Installed", "Last Opened", "Name"] {
            let header = table.buttons[title]
            XCTAssertTrue(header.exists)
            try clickVisible(header)
            XCTAssertTrue(app.buttons["Copy Identifier"].exists)
            XCTAssertTrue(app.staticTexts["org.example.app"].exists)
            if title == "Version" || title == "Source" {
                let firstName = title == "Version" ? "example-tool" : "Example App"
                XCTAssertTrue(table.children(matching: .outlineRow).element(boundBy: 0).staticTexts[firstName].exists,
                              "The first native row must reflect ascending " + title + " sorting")
            }
            recordHeaderState(app, phase: title + " ascending")
            try clickVisible(header)
            XCTAssertTrue(app.buttons["Copy Identifier"].exists)
            XCTAssertTrue(app.staticTexts["org.example.app"].exists)
            if title == "Version" || title == "Source" {
                let firstName = title == "Version" ? "Example App" : "example-tool"
                XCTAssertTrue(table.children(matching: .outlineRow).element(boundBy: 0).staticTexts[firstName].exists,
                              "The first native row must reflect descending " + title + " sorting")
            }
            recordHeaderState(app, phase: title + " descending")
        }
        let search = app.searchFields.firstMatch
        search.click(); search.typeText("Example")
        try clickVisible(table.buttons["Size"])
        XCTAssertTrue(table.staticTexts["Example App"].firstMatch.exists)
    }

    func testSettingsPagesThresholdInputAndAboutLinks() throws {
        let app = launch()
        try clickVisible(app.buttons["inventory.settings"])
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
        try clickVisible(app.buttons["inventory.settings"])
        app.radioButtons["Discovery"].click()
        XCTAssertEqual(app.textFields["Recently installed threshold"].value as? String, "28")
        closeSettings(app)
        try clickVisible(app.buttons["inventory.about"])
        let about = app.windows["About Macventory"]
        XCTAssertTrue(about.waitForExistence(timeout: 3), "About must open after Settings closes")
        XCTAssertTrue(about.links["LinkedIn"].waitForExistence(timeout: 3))
        XCTAssertTrue(about.links["GitHub Profile"].exists)
        XCTAssertTrue(about.links["Macventory Repository"].exists)
    }

    func testCancelDiscardsDraftAcrossPages() throws {
        let app = launch()
        try clickVisible(app.buttons["inventory.settings"])
        app.radioButtons["Discovery"].click()
        let field = app.textFields["Recently installed threshold"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "30", "Each fixture launch starts with default settings")
        field.click(); field.typeKey("a", modifierFlags: .command); field.typeText("28"); field.typeKey(.tab, modifierFlags: [])
        XCTAssertEqual(field.value as? String, "28")
        app.radioButtons["Scanning"].click()
        XCTAssertTrue(app.textFields["Homebrew prefixes"].exists)
        closeSettings(app)
        try clickVisible(app.buttons["inventory.settings"])
        app.radioButtons["Discovery"].click()
        XCTAssertEqual(app.textFields["Recently installed threshold"].value as? String, "30")
    }

}

/// Independent mouse diagnostic. This class never substitutes for the strict
/// ten-method suite above, and is run into its own result bundle in CI.
@MainActor
final class MacventoryHeaderPointerDiagnostics: XCTestCase {
    func testSourceHeaderRealPointerBothDirectionsPreservesIdentity() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
        let window = app.windows.firstMatch
        _ = try XCTUnwrap(window.waitForExistence(timeout: 10) ? window : nil)
        let table = app.descendants(matching: .any).matching(identifier: "inventory.table").firstMatch
        _ = try XCTUnwrap(table.waitForExistence(timeout: 5) ? table : nil)
        let selected = table.staticTexts["Example App"].firstMatch
        _ = try XCTUnwrap(selected.waitForExistence(timeout: 5) && selected.isHittable ? selected : nil)
        selected.click()
        XCTAssertTrue(app.buttons["Copy Identifier"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["org.example.app"].exists)

        func names() -> [String] {
            table.children(matching: .outlineRow).allElementsBoundByIndex.map { row in
                let matches = ["Example App", "example-tool"].filter { row.staticTexts[$0].exists }
                return matches.count == 1 ? matches[0] : "<unexpected row: \(row.debugDescription)>"
            }
        }
        func record(_ phase: String) {
            let header = table.buttons["Source"]
            let attachment = XCTAttachment(string: "phase=\(phase) state=\(app.state.rawValue) " +
                "window=\(window.frame) table=\(table.frame) header=\(header.frame) " +
                "hittable=\(header.isHittable) value=\(String(describing: header.value)) rows=\(names())\n" + app.debugDescription)
            attachment.name = "Source real-pointer diagnostic — " + phase
            attachment.lifetime = .keepAlways
            add(attachment)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = attachment.name
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertEqual(names(), ["Example App", "example-tool"], "Known initial name order is required")
        // Start from the opposite Source order so the ascending click must also
        // visibly reorder rows. Version is the confirmed hittable control.
        let version = table.buttons["Version"]
        _ = try XCTUnwrap(version.exists && version.isHittable ? version : nil)
        version.click()
        let oppositeFirst = table.children(matching: .outlineRow).element(boundBy: 0).staticTexts["example-tool"]
        XCTAssertTrue(oppositeFirst.waitForExistence(timeout: 5))
        XCTAssertEqual(names(), ["example-tool", "Example App"])
        XCTAssertTrue(app.staticTexts["org.example.app"].exists)
        for ascending in [true, false] {
            let phase = ascending ? "ascending" : "descending"
            record("before " + phase)
            defer { record("after " + phase) }
            // Resolve again before each click. isHittable is recorded, deliberately
            // not a precondition in this explicitly named diagnostic.
            let header = table.buttons["Source"]
            _ = try XCTUnwrap(header.waitForExistence(timeout: 5) ? header : nil)
            let frame = header.frame
            let nestedScroll = table.scrollViews.firstMatch
            let viewport = nestedScroll.exists ? nestedScroll : app.scrollViews.containing(.any, identifier: "inventory.table").firstMatch
            _ = try XCTUnwrap(viewport.exists ? viewport : nil, "Resolve the actual enclosing table viewport")
            _ = try XCTUnwrap(app.state == .runningForeground && frame.width > 0 && frame.height > 0 &&
                window.frame.contains(frame) && table.frame.contains(frame) && viewport.frame.contains(frame) ? header : nil,
                "The Source header must be fully inside the active window and table viewport")
            let coordinate = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            _ = try XCTUnwrap(frame.contains(coordinate.screenPoint) ? header : nil,
                              "The element-relative click must remain inside the resolved header")
            let before = names()
            coordinate.click()
            let expected = ascending ? ["Example App", "example-tool"] : ["example-tool", "Example App"]
            // XCTest exposes no dedicated AXSortDirection property. Complete
            // fixture row order is the independent direction oracle; the native
            // probe separately verifies AXSortDirection on this runtime.
            let first = table.children(matching: .outlineRow).element(boundBy: 0).staticTexts[expected[0]]
            XCTAssertTrue(first.waitForExistence(timeout: 5),
                           "A real Source click must apply " + phase + " source order")
            XCTAssertEqual(names(), expected)
            XCTAssertNotEqual(names(), before, "Both Source interactions must visibly reorder rows")
            XCTAssertTrue(app.buttons["Copy Identifier"].exists)
            XCTAssertTrue(app.staticTexts["org.example.app"].exists, "Sorting must preserve the selected application's identity")
        }
    }
}

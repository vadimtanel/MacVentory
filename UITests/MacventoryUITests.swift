import XCTest

@MainActor
final class MacventoryUITests: XCTestCase {
    func testInstallationHealthOrphanPreviewAndSimulatedResult() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--qa-health-scenarios"]
        app.launch()
        let table = inventoryTable(app)
        XCTAssertTrue(table.buttons["Status"].exists)
        let sidebar = app.descendants(matching: .any).matching(identifier: "inventory.sidebar").firstMatch
        let attention = sidebar.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Attention Required")).firstMatch
        try clickVisible(attention)
        let row = table.children(matching: .outlineRow).containing(.staticText, identifier: "macventory").firstMatch
        try clickVisible(row)
        let uninstallButton = app.buttons["inventory.uninstall"]
        try clickVisible(uninstallButton)
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let uninstall = sheet.checkBoxes["management.uninstall"]
        XCTAssertEqual(uninstall.label, "Remove Orphaned Installation")
        XCTAssertTrue(uninstall.isEnabled)
        XCTAssertFalse(sheet.buttons["management.confirm"].isEnabled)
        try clickVisible(uninstall)
        try clickVisible(sheet.checkBoxes["management.acknowledge"])
        try clickVisible(sheet.buttons["management.confirm"])
        XCTAssertTrue(sheet.staticTexts.containing(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "No application, process or data was changed", "No application, process or data was changed")).firstMatch.waitForExistence(timeout: 5))
        try clickVisible(sheet.buttons["management.ok"])
        XCTAssertFalse(sheet.exists)
        XCTAssertTrue(table.exists)
    }

    func testExplicitExecutionLevelsAndInteractiveVerification() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--qa-execution-levels"]
        app.launch()
        let table = inventoryTable(app)
        func preview(_ name: String, level: String, enabled: Bool) throws {
            let row = table.children(matching: .outlineRow).containing(.staticText, identifier: name).firstMatch
            try clickVisible(row)
            try clickVisible(app.buttons["inventory.uninstall"])
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 5))
            let badge = sheet.descendants(matching: .any).matching(identifier: "uninstall.level").firstMatch
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", level), object: badge)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
            XCTAssertEqual(sheet.checkBoxes["management.uninstall"].isEnabled, enabled)
        }
        try preview("Example App", level: "Direct Uninstall", enabled: true)
        try clickVisible(app.sheets.buttons["management.cancel"])
        try preview("Interactive Vendor Example", level: "Interactive Uninstall", enabled: true)
        let sheet = app.sheets.firstMatch
        try clickVisible(sheet.checkBoxes["management.uninstall"])
        XCTAssertFalse(sheet.buttons["management.confirm"].isEnabled)
        try clickVisible(sheet.checkBoxes["management.acknowledge"])
        try clickVisible(sheet.buttons["management.confirm"])
        try clickVisible(sheet.buttons["management.verifyRemoval"])
        XCTAssertTrue(sheet.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Waiting for User", "Waiting for User")).firstMatch.waitForExistence(timeout: 5))
        try clickVisible(sheet.buttons["management.ok"])
        try preview("Partial Removal Example", level: "Guided Only", enabled: false)
        try clickVisible(app.sheets.buttons["management.cancel"])
        try preview("Example System Component", level: "Protected / Blocked", enabled: false)
        try clickVisible(app.sheets.buttons["management.cancel"])
    }

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

    private func inventoryRowNames(_ table: XCUIElement) -> [String] {
        table.children(matching: .outlineRow).allElementsBoundByIndex.map { row in
            let names = ["Example App", "example-tool"].filter { row.staticTexts[$0].exists }
            return names.count == 1 ? names[0] : "<unexpected inventory row>"
        }
    }

    private func clickNativeHeader(_ title: String, in app: XCUIApplication, phase: String,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        var clicked = false
        defer { if !clicked { recordHeaderState(app, phase: phase + " — click precondition failed") } }
        _ = try XCTUnwrap(["Name", "Version", "Source", "Size", "Installed", "Last Opened"].contains(title) ? title : nil,
                          "This interaction helper is restricted to native inventory headers", file: file, line: line)
        let table = inventoryTable(app)
        let window = app.windows.firstMatch
        _ = try XCTUnwrap(window.waitForExistence(timeout: 5) ? window : nil, file: file, line: line)
        // Resolve the current proxy for every interaction, including after reordering.
        let header = table.buttons[title]
        _ = try XCTUnwrap(header.waitForExistence(timeout: 5) ? header : nil, file: file, line: line)
        let nestedScroll = table.scrollViews.firstMatch
        let viewport = nestedScroll.exists ? nestedScroll : app.scrollViews.containing(.any, identifier: "inventory.table").firstMatch
        _ = try XCTUnwrap(viewport.exists ? viewport : nil, "Resolve the actual table viewport", file: file, line: line)
        let frame = header.frame
        let bounds = [window.frame, table.frame, viewport.frame]
        let coordinate = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let point = coordinate.screenPoint
        // macOS 26.6.2/Xcode 26.5 reports Source false despite successful actual
        // pointer sorting. Record this value; never catch/retry a failed click.
        let diagnostic = XCTAttachment(string: "phase=\(phase) header=\(title) exists=\(header.exists) " +
            "hittable=\(header.isHittable) state=\(app.state.rawValue) frame=\(frame) " +
            "window/table/viewport=\(bounds) element-relative point=\(point)")
        diagnostic.name = phase + " — native header mouse geometry"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        _ = try XCTUnwrap(app.state == .runningForeground && frame.width > 0 && frame.height > 0 &&
            point.x.isFinite && point.y.isFinite && frame.contains(point) &&
            bounds.allSatisfy { $0.contains(frame) && $0.contains(point) } ? header : nil,
            "The header and its element-relative click point must be inside the foreground window, inventory and viewport",
            file: file, line: line)
        coordinate.click()
        clicked = true
    }

    private func assertInventoryOrder(_ expected: [String], in app: XCUIApplication, phase: String,
                                      changedFrom previous: [String]? = nil,
                                      file: StaticString = #filePath, line: UInt = #line) throws {
        let table = inventoryTable(app)
        let rows = table.children(matching: .outlineRow)
        // Wait for both expected names at their actual row positions, rather
        // than accepting a first-row-only or comparator-derived ordering check.
        let ordered = expected.enumerated().map { index, name in
            XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"),
                                      object: rows.element(boundBy: index).staticTexts[name])
        }
        let result = XCTWaiter.wait(for: ordered, timeout: 5)
        if result != .completed { recordHeaderState(app, phase: phase + " — order wait failed") }
        _ = try XCTUnwrap(result == .completed ? table : nil,
                          "Wait for the complete expected native row order: \(expected)", file: file, line: line)
        let names = inventoryRowNames(table)
        let selected = rows.containing(.staticText, identifier: "Example App").firstMatch
        let appSelected = selected.exists && selected.isSelected
        let details = app.descendants(matching: .any).matching(identifier: "inventory.details").firstMatch
        let identifierPreserved = details.staticTexts["org.example.app"].exists
        let copyAvailable = app.buttons["Copy Identifier"].exists
        let changed = previous.map { names != $0 } ?? true
        let outcome = XCTAttachment(string: "phase=\(phase) expected=\(expected) actual=\(names) " +
            "previous=\(String(describing: previous)) rowCount=\(rows.count) " +
            "Example App selected=\(appSelected) Details identity=\(identifierPreserved) Copy Identifier=\(copyAvailable)")
        outcome.name = phase + " — native row order and selection"
        outcome.lifetime = .keepAlways
        add(outcome)
        if rows.count != 2 || names != expected || !changed || !appSelected || !identifierPreserved || !copyAvailable {
            recordHeaderState(app, phase: phase + " — sorting or selection assertion failed")
        }
        XCTAssertEqual(rows.count, 2, "Exactly two fictional inventory rows are required", file: file, line: line)
        XCTAssertEqual(names, expected, phase + " must match both independent expected row names", file: file, line: line)
        if let previous { XCTAssertNotEqual(names, previous, phase + " must visibly change row order", file: file, line: line) }
        XCTAssertTrue(appSelected, "Example App's actual inventory row must remain selected", file: file, line: line)
        XCTAssertTrue(identifierPreserved, "Details must retain org.example.app", file: file, line: line)
        XCTAssertTrue(copyAvailable, "Copy Identifier must remain available", file: file, line: line)
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

    private func launch(headerSorting: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if headerSorting { app.launchArguments.append("--ui-testing-header-sorts") }
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
        inventoryTable(app).staticTexts["Example App"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["management.cancel"].click()
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }
    func testNativeRowPrimaryActionAndProtectedPreview() throws {
        let app = launch()
        let row = inventoryTable(app).staticTexts["Example App"].firstMatch
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
        inventoryTable(app).staticTexts["example-tool"].firstMatch.doubleClick()
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
        try clickVisible(app.buttons["inventory.settings"])
        app.checkBoxes["Show system applications"].click()
        closeSettings(app, save: true)
        XCTAssertTrue(app.buttons["inventory.refresh"].waitForExistence(timeout: 12))
        inventoryTable(app).staticTexts["Example System Component"].firstMatch.doubleClick()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
    }

    func testRunningContextForceQuitOnlyHasSingleOKAndReopens() {
        let app = launch()
        let row = inventoryTable(app).staticTexts["Running Example"].firstMatch
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
        XCTAssertTrue(inventoryTable(app).staticTexts["Example App"].firstMatch.exists)
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
        let app = launch(headerSorting: true)
        let table = inventoryTable(app)
        recordHeaderState(app, phase: "before selection")
        table.staticTexts["Example App"].firstMatch.click()
        XCTAssertTrue(app.buttons["Copy Identifier"].waitForExistence(timeout: 3))
        recordHeaderState(app, phase: "after selection and Details")
        let appThenTool = ["Example App", "example-tool"]
        let toolThenApp = ["example-tool", "Example App"]
        // Independent fixture expectations: never ask the production comparator
        // to calculate this test's expected result.
        let cases: [(String, [String], [String])] = [
            ("Name", appThenTool, toolThenApp),
            ("Version", toolThenApp, appThenTool),
            ("Source", appThenTool, toolThenApp),
            ("Size", toolThenApp, appThenTool),
            ("Installed", appThenTool, toolThenApp),
            ("Last Opened", toolThenApp, appThenTool)
        ]
        try assertInventoryOrder(appThenTool, in: app, phase: "initial name order")
        for (title, ascending, descending) in cases {
            // The anchor is a different column with the opposite ascending
            // order. In this sequence it is either inactive or was last left
            // descending, so one real click establishes its ascending order.
            let anchor = ascending == appThenTool ? "Version" : "Source"
            try clickNativeHeader(anchor, in: app, phase: title + " opposite-order setup")
            try assertInventoryOrder(descending, in: app, phase: title + " opposite-order setup")
            let before = inventoryRowNames(table)
            try clickNativeHeader(title, in: app, phase: title + " ascending")
            try assertInventoryOrder(ascending, in: app, phase: title + " ascending", changedFrom: before)
            let afterAscending = inventoryRowNames(table)
            try clickNativeHeader(title, in: app, phase: title + " descending")
            try assertInventoryOrder(descending, in: app, phase: title + " descending", changedFrom: afterAscending)
        }
        let search = app.searchFields.firstMatch
        search.click(); search.typeText("Example")
        XCTAssertEqual(search.value as? String, "Example")
        try clickNativeHeader("Source", in: app, phase: "post-search opposite-order setup")
        try assertInventoryOrder(appThenTool, in: app, phase: "post-search opposite-order setup")
        let beforeSearchSort = inventoryRowNames(table)
        try clickNativeHeader("Size", in: app, phase: "post-search Size ascending")
        try assertInventoryOrder(toolThenApp, in: app, phase: "post-search Size ascending", changedFrom: beforeSearchSort)
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
        app.launchArguments = ["--ui-testing", "--ui-testing-header-sorts"]
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

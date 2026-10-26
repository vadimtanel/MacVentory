#!/usr/bin/env python3
"""Verify real synthetic GUI execution; JSON evidence on stdout, errors on stderr."""
import argparse
import json
from pathlib import Path
import re
import sys

# Explicit coverage contract: never derive expected coverage from the tests that
# happen to remain in the source. The first 16 are the original primary cases.
ORIGINAL_CASES = (
    'testAllNativeHeaderSortsPreserveSelection',
    'testCancelDiscardsDraftAcrossPages',
    'testColumnVisibilityMenu',
    'testDetailsActionsStayVisibleAcrossLayoutsAndLongMetadata',
    'testExplicitExecutionLevelsAndInteractiveVerification',
    'testInstallationHealthOrphanPreviewAndSimulatedResult',
    'testKeyboardRefreshAndSettings',
    'testLeftoverCleanupRemovesOnlyResolvedSyntheticGroupAndRestoresInteraction',
    'testLeftoverFooterSettingsOpensAndReturnsToSamePage',
    'testNativeRowPrimaryActionAndProtectedPreview',
    'testRefreshCancelAndFilters',
    'testRunningContextForceQuitOnlyHasSingleOKAndReopens',
    'testSearchAndEmptyState',
    'testSettingsPagesThresholdInputAndAboutLinks',
    'testStartupSidebarSelectionAndDetails',
    'testUninstallConfirmationSimulationAndCancel',
)
SELECTION_CASE = 'testSearchSelectionAndDetailsContract'
TARGET = 'testExplicitExecutionLevelsAndInteractiveVerification'
FOCUSED = {
    'isolated': [TARGET, SELECTION_CASE],
    'paths': ['testAWithoutSearch', 'testBSearchThenOneClick', 'testCSearchThenTabThenOneClick',
              'testDSearchThenOneClickWithoutExtraActivation', 'testESearchThenNativeKeyboardSelection'],
    'after-layout': ['testDetailsActionsStayVisibleAcrossLayoutsAndLongMetadata', TARGET],
    'after-headers': ['testAllNativeHeaderSortsPreserveSelection', TARGET],
}

def inspect_log(scenario, text):
    case_class = 'MacventorySelectionPathDiagnostics' if scenario == 'paths' else 'MacventoryUITests'
    prefix = r"^Test Case '-\[MacventoryUITests\." + case_class + r" (\w+)\]' "
    events = re.findall(prefix + r'(started|passed|failed|skipped)\b', text, re.M)
    names = lambda status: [name for name, kind in events if kind == status]
    started, passed, failed, skipped = [names(status) for status in ('started', 'passed', 'failed', 'skipped')]
    terminal = re.findall(r'^\*\* TEST (?:EXECUTE )?(SUCCEEDED|FAILED) \*\*$', text, re.M)
    required = list(ORIGINAL_CASES) + [SELECTION_CASE] if scenario == 'full' else FOCUSED[scenario]
    errors = []
    if len(started) != len(required) or set(started) != set(required):
        errors.append('Required GUI coverage is missing, repeated or unexpected')
    if scenario != 'full' and started != required:
        errors.append('Actual order differs from the requested predecessor scenario')
    if passed != started or failed or skipped:
        errors.append('GUI cases failed, skipped, repeated or did not complete')
    if terminal != ['SUCCEEDED']:
        errors.append('Expected exactly one successful Xcode terminal result with no failure marker')
    return {
        'scenario': scenario, 'required': required, 'actual_order': started,
        'passed': passed, 'failed': failed, 'skipped': skipped,
        'counts': dict(started=len(started), passed=len(passed), failed=len(failed), skipped=len(skipped)),
        'not_completed': [name for name in started if name not in passed + failed + skipped],
        'terminal_results': terminal, 'errors': errors,
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scenario', choices=['full', *FOCUSED])
    parser.add_argument('log', type=Path)
    parser.add_argument('--expected-sha')
    parser.add_argument('--tested-head', type=Path)
    parser.add_argument('--recorded-scenario', type=Path)
    args = parser.parse_args()
    result = inspect_log(args.scenario, args.log.read_text()) if args.log.exists() else {
        'scenario': args.scenario, 'errors': ['Primary Xcode log is missing'],
    }
    errors = result['errors']
    if args.expected_sha:
        actual = args.tested_head.read_text().strip() if args.tested_head and args.tested_head.exists() else None
        result.update(expected_sha=args.expected_sha, tested_sha=actual)
        if not re.fullmatch(r'[0-9a-f]{40}', args.expected_sha) or actual != args.expected_sha:
            errors.append('Tested SHA does not match the requested candidate')
    if args.recorded_scenario:
        actual = args.recorded_scenario.read_text().strip() if args.recorded_scenario.exists() else None
        result['recorded_scenario'] = actual
        if actual != args.scenario:
            errors.append('Recorded scenario does not match the requested scenario')
    source = (Path(__file__).resolve().parent.parent / 'UITests/MacventoryUITests.swift').read_text()
    primary = source.split('final class MacventoryUITests: XCTestCase {', 1)[1].split('final class MacventorySelectionPathDiagnostics:', 1)[0]
    methods = re.findall(r'func (test\w+)\(', primary)
    if len(methods) != 17 or set(methods) != set(ORIGINAL_CASES) | {SELECTION_CASE}:
        errors.append('Primary source no longer contains all 16 original cases plus the selection regression')
    print(json.dumps(result, indent=2))
    for error in errors:
        print(error, file=sys.stderr)
    return int(bool(errors))

if __name__ == '__main__':
    sys.exit(main())

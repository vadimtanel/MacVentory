#!/usr/bin/env python3
"""Require actual synthetic GUI execution; no dispatch, retries or outcome substitution."""
import json
from pathlib import Path
import re
import sys

def require(condition, message):
    if not condition:
        raise SystemExit(message)

scenario, log = sys.argv[1:]
text = Path(log).read_text()
case_class = 'MacventorySelectionPathDiagnostics' if scenario == 'paths' else 'MacventoryUITests'
prefix = r"Test Case '-\[MacventoryUITests\." + case_class + r" (\w+)\]' "
started = re.findall(prefix + 'started', text)
passed = re.findall(prefix + 'passed', text)
failed = re.findall(prefix + 'failed', text)
skipped = re.findall(prefix + 'skipped', text)
target = 'testExplicitExecutionLevelsAndInteractiveVerification'
expected = {
    'isolated': [target],
    'paths': ['testAWithoutSearch', 'testBSearchThenOneClick', 'testCSearchThenTabThenOneClick',
              'testDSearchThenOneClickWithoutExtraActivation', 'testESearchThenNativeKeyboardSelection'],
    'after-layout': ['testDetailsActionsStayVisibleAcrossLayoutsAndLongMetadata', target],
    'after-headers': ['testAllNativeHeaderSortsPreserveSelection', target],
}
print(json.dumps({'scenario': scenario, 'actual_order': started, 'passed': passed, 'failed': failed, 'skipped': skipped,
                  'counts': {'started': len(started), 'passed': len(passed), 'failed': len(failed), 'skipped': len(skipped)},
                  'not_completed': [name for name in started if name not in passed + failed + skipped]}, indent=2))
if scenario == 'full':
    source = (Path(__file__).resolve().parent.parent / 'UITests/MacventoryUITests.swift').read_text()
    primary = source.split('final class MacventoryUITests: XCTestCase {', 1)[1].split('final class MacventorySelectionPathDiagnostics:', 1)[0]
    required = re.findall(r'func (test\w+)\(', primary)
    require(len(required) == 16 and len(started) == 16 and set(started) == set(required), 'Primary suite incomplete or changed')
else:
    require(started == expected[scenario], 'Actual order differs from the requested predecessor scenario')
require(passed == started and not failed and not skipped, 'GUI cases failed, skipped, repeated or did not complete')
require(re.search(r'^\*\* TEST (?:EXECUTE )?SUCCEEDED \*\*$', text, re.M), 'No successful Xcode terminal result')

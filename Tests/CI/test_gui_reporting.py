"""Synthetic log/process regressions; never starts Xcode or an application."""
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('gui_verifier', ROOT / 'scripts/verify-ui-selection-run.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)
SHA = 'a' * 40

def log(names, outcome='passed', terminal='SUCCEEDED', case_class='MacventoryUITests'):
    return '\n'.join(
        f"Test Case '-[MacventoryUITests.{case_class} {name}]' {kind}."
        for name in names for kind in ['started', outcome]
    ) + f'\n** TEST {terminal} **\n'

class CaseEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.names = list(verifier.ORIGINAL_CASES) + [verifier.SELECTION_CASE]

    def test_all_original_cases_and_added_regression_are_required(self):
        self.assertFalse(verifier.inspect_log('full', log(self.names))['errors'])
        for name in self.names:
            with self.subTest(missing=name):
                self.assertTrue(verifier.inspect_log('full', log([n for n in self.names if n != name]))['errors'])

    def test_failed_skipped_duplicate_incomplete_and_mixed_terminal_rejected(self):
        samples = [log(self.names, 'failed', 'FAILED'), log(self.names, 'skipped'),
                   log(self.names + self.names[:1]), log([]),
                   log(self.names).replace("' passed.", "' unfinished."),
                   log(self.names) + '** TEST FAILED **\n', log(self.names).replace('** TEST SUCCEEDED **', '')]
        for sample in samples:
            with self.subTest(sample=sample[-100:]):
                self.assertTrue(verifier.inspect_log('full', sample)['errors'])

    def test_isolated_requires_original_case_and_selection_contract_in_order(self):
        required = verifier.FOCUSED['isolated']
        self.assertFalse(verifier.inspect_log('isolated', log(required))['errors'])
        self.assertTrue(verifier.inspect_log('isolated', log(required[::-1]))['errors'])
        self.assertTrue(verifier.inspect_log('isolated', log(required[:1]))['errors'])

    def test_execute_terminal_supported_without_ignoring_failures(self):
        self.assertFalse(verifier.inspect_log('full', log(self.names, terminal='EXECUTE SUCCEEDED'))['errors'])
        self.assertTrue(verifier.inspect_log('full', log(self.names, terminal='EXECUTE FAILED'))['errors'])

    def test_startup_requires_one_explicit_cold_arm_and_cannot_claim_selection_coverage(self):
        for arm, name in verifier.STARTUP_ARMS.items():
            with self.subTest(arm=arm):
                text = log([name], case_class='MacventoryStartupDiagnostics')
                self.assertFalse(verifier.inspect_log('startup', text, arm)['errors'])
                self.assertTrue(verifier.inspect_log('startup', text)['errors'])
                self.assertTrue(verifier.inspect_log('isolated', text)['errors'])
                self.assertTrue(verifier.inspect_log('full', text)['errors'])
                predecessor = log(['testUnrelatedPredecessor'])
                self.assertTrue(verifier.inspect_log('startup', predecessor + text, arm)['errors'])
                self.assertTrue(verifier.inspect_log('startup', log([name], 'failed', 'FAILED', 'MacventoryStartupDiagnostics'), arm)['errors'])
        sequential = log(list(verifier.STARTUP_ARMS.values()), case_class='MacventoryStartupDiagnostics')
        self.assertTrue(verifier.inspect_log('startup', sequential, 'original')['errors'])

class PrimaryProcessTests(unittest.TestCase):
    def run_primary(self, mode, scenario='isolated', expected_sha=SHA, startup_arm='suite'):
        with tempfile.TemporaryDirectory(prefix='macventory-ci-fixture-') as directory:
            root = Path(directory)
            (root/'scripts').mkdir()
            (root/'UITests').mkdir()
            shutil.copy(ROOT/'scripts/verify-ui-selection-run.py', root/'scripts')
            shutil.copy(ROOT/'UITests/MacventoryUITests.swift', root/'UITests')
            bin_dir = root/'bin'
            bin_dir.mkdir()
            fake_git = bin_dir/'git'
            fake_git.write_text('#!/bin/bash\nprintf "%s\\n" ' + SHA + '\n')
            fake_git.chmod(0o700)
            fake_xcode = bin_dir/'xcodebuild'
            fake_xcode.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
pathlib.Path('arguments.json').write_text(json.dumps(args))
mode = os.environ['FIXTURE_MODE']
if mode != 'no-result':
    result = pathlib.Path(args[args.index('-resultBundlePath')+1])
    result.mkdir(parents=True)
    (result/'Info.plist').write_text('synthetic fixture')
names = json.loads(os.environ['FIXTURE_CASES'])
if mode == 'missing': names = names[:-1]
if mode == 'zero': names = []
case_class = 'MacventoryStartupDiagnostics' if os.environ['SELECTION_SCENARIO'] == 'startup' else 'MacventoryUITests'
for name in names:
    print("Test Case '-[MacventoryUITests." + case_class + " " + name + "]' started.")
    outcome = 'failed' if mode in ['failed', 'false-success'] else 'skipped' if mode == 'skipped' else 'passed'
    print("Test Case '-[MacventoryUITests." + case_class + " " + name + "]' " + outcome + '. (1 seconds).')
if mode != 'interrupted': print('** TEST ' + ('FAILED' if mode in ['failed', 'false-success'] else 'SUCCEEDED') + ' **')
sys.exit(65 if mode == 'failed' else 143 if mode == 'interrupted' else 0)
''')
            fake_xcode.chmod(0o700)
            if mode == 'tee-failed':
                fake_tee = bin_dir/'tee'
                fake_tee.write_text('#!/bin/bash\n/usr/bin/tee "$@"\nexit 23\n')
                fake_tee.chmod(0o700)
            names = list(verifier.ORIGINAL_CASES) + [verifier.SELECTION_CASE] if scenario == 'full' else verifier.FOCUSED[scenario]
            if scenario == 'startup' and startup_arm in verifier.STARTUP_ARMS:
                names = [verifier.STARTUP_ARMS[startup_arm]]
            env = dict(os.environ, PATH=str(bin_dir)+':'+os.environ['PATH'], FIXTURE_MODE=mode,
                       FIXTURE_CASES=json.dumps(names), SELECTION_SCENARIO=scenario,
                       STARTUP_ARM=startup_arm,
                       TESTED_SHA=expected_sha, GITHUB_OUTPUT=str(root/'outputs.txt'))
            result = subprocess.run(['bash', str(ROOT/'scripts/run-ui-tests.sh')], cwd=root, env=env,
                                    capture_output=True, text=True)
            output = (root/'outputs.txt').read_text() if (root/'outputs.txt').exists() else ''
            status_path = root/'build/verification/gui-exit-status.json'
            status = json.loads(status_path.read_text()) if status_path.exists() else None
            sequence_path = root/'build/verification/gui-sequence.json'
            sequence = json.loads(sequence_path.read_text()) if sequence_path.exists() else None
            arguments = json.loads((root/'arguments.json').read_text()) if (root/'arguments.json').exists() else []
            return result.returncode, output, status, sequence, arguments

    def test_primary_preserves_failure_and_does_not_trust_zero_exit_alone(self):
        for mode, code in [('passed', 0), ('failed', 65), ('false-success', 1), ('missing', 1),
                           ('skipped', 1), ('zero', 1), ('interrupted', 143), ('tee-failed', 23)]:
            with self.subTest(mode=mode):
                actual, output, status, sequence, _ = self.run_primary(mode)
                self.assertEqual(actual, code)
                self.assertEqual('primary_finished=true' in output, mode != 'interrupted')
                self.assertEqual(sequence['tested_sha'], SHA)
                self.assertEqual(status['xcode_exit'], 65 if mode == 'failed' else 143 if mode == 'interrupted' else 0)

    def test_full_keeps_entire_primary_class_and_correct_result_bundle(self):
        code, _, _, sequence, args = self.run_primary('passed', scenario='full')
        self.assertEqual(code, 0)
        self.assertEqual(sequence['counts']['passed'], 17)
        self.assertIn('-only-testing:MacventoryUITests/MacventoryUITests', args)
        self.assertEqual(args[args.index('-resultBundlePath')+1], 'build/verification/UITests.xcresult')

    def test_missing_bundle_does_not_authorize_another_desktop_diagnostic(self):
        code, output, _, _, _ = self.run_primary('no-result')
        self.assertNotEqual(code, 0)
        self.assertNotIn('primary_finished=true', output)

    def test_startup_executes_only_one_explicit_arm_and_reports_real_failures(self):
        for arm, method in verifier.STARTUP_ARMS.items():
            for mode, expected in [('passed', 0), ('failed', 65)]:
                with self.subTest(arm=arm, mode=mode):
                    code, output, status, sequence, args = self.run_primary(mode, scenario='startup', startup_arm=arm)
                    self.assertEqual(code, expected)
                    self.assertEqual(status['xcode_exit'], expected)
                    self.assertIn('primary_finished=true', output)
                    self.assertEqual(sequence['counts']['started'], 1)
                    self.assertEqual(sequence['startup_arm'], arm)
                    self.assertEqual(sequence['recorded_startup_arm'], arm)
                    self.assertEqual([a for a in args if a.startswith('-only-testing:')],
                                     ['-only-testing:MacventoryUITests/MacventoryStartupDiagnostics/' + method])
        code, output, status, sequence, args = self.run_primary('passed', scenario='startup')
        self.assertNotEqual(code, 0)
        self.assertEqual(args, [], 'No implicit sequential startup suite may launch Xcode')

    def test_wrong_checkout_stops_before_xcode(self):
        code, output, status, _, args = self.run_primary('passed', expected_sha='b'*40)
        self.assertNotEqual(code, 0)
        self.assertFalse(output)
        self.assertIsNone(status)
        self.assertEqual(args, [])

    def test_recorded_scenario_and_sha_mismatch_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix='macventory-metadata-') as directory:
            root = Path(directory)
            (root/'xcode.log').write_text(log(verifier.FOCUSED['isolated']))
            (root/'head').write_text('b'*40)
            (root/'scenario').write_text('full')
            result = subprocess.run(['python3', str(ROOT/'scripts/verify-ui-selection-run.py'), 'isolated',
                                     str(root/'xcode.log'), '--expected-sha', SHA, '--tested-head', str(root/'head'),
                                     '--recorded-scenario', str(root/'scenario')], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(len(json.loads(result.stdout)['errors']), 2)

    def test_startup_artifact_from_another_arm_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='macventory-arm-metadata-') as directory:
            root = Path(directory)
            (root/'xcode.log').write_text(log([verifier.STARTUP_ARMS['original']], case_class='MacventoryStartupDiagnostics'))
            (root/'arm.txt').write_text('selection-disabled\n')
            result = subprocess.run(['python3', str(ROOT/'scripts/verify-ui-selection-run.py'), 'startup',
                                     str(root/'xcode.log'), '--startup-arm', 'original',
                                     '--recorded-startup-arm', str(root/'arm.txt')], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(json.loads(result.stdout)['errors'], ['Recorded startup arm does not match the requested arm'])

    def test_workflow_failure_and_evidence_policy(self):
        workflow = (ROOT/'.github/workflows/ci.yml').read_text()
        primary = workflow.split('      - name: XCUITest\n', 1)[1].split('      - name:', 1)[0]
        self.assertNotIn('continue-on-error:', primary)
        self.assertIn('run: bash scripts/run-ui-tests.sh', primary)
        self.assertIn('if: always()', workflow.split('- name: Export primary xcresult evidence', 1)[1].split('- name:', 1)[0])
        self.assertIn('::error::XCUITest did not validate', workflow)
        triggers = workflow.split('permissions:', 1)[0]
        self.assertIn('    branches-ignore:\n      - release/v1.1.0-stabilization', triggers)
        # A stabilization PR push must exercise the focused contract once, at
        # the candidate SHA rather than an unreported synthetic merge revision.
        self.assertIn("github.head_ref == 'release/v1.1.0-stabilization' && 'isolated' || 'full'", workflow)
        self.assertEqual(workflow.count('ref: ${{ github.event.pull_request.head.sha || github.sha }}'), 2)
        self.assertIn('TESTED_SHA: ${{ github.event.pull_request.head.sha || github.sha }}', workflow)

    def test_startup_runs_only_original_cold_case_and_retains_its_artifacts(self):
        workflow = (ROOT/'.github/workflows/ci.yml').read_text()
        ui = workflow.split('  ui:\n', 1)[1]
        expression = next(line for line in ui.splitlines() if 'startup_arm: ${{ fromJSON(' in line)
        arrays = [json.loads(v) for v in re.findall(r"'(\[.*?\])'", expression)]
        self.assertEqual(arrays, [['original'], ['suite']])
        self.assertIn('fail-fast: false', ui)
        self.assertIn('STARTUP_ARM: ${{ matrix.startup_arm }}', ui)
        self.assertIn("format('-startup-{0}', matrix.startup_arm)", ui)
        self.assertNotIn('actions/cache', ui)

    def test_final_job_report_requires_every_required_outcome(self):
        workflow = (ROOT/'.github/workflows/ci.yml').read_text()
        report = workflow.split('      - name: Report actual GUI test outcome', 1)[1].split('      - uses:', 1)[0]
        shell = textwrap.dedent(report.split('        run: |\n', 1)[1])
        initial = dict(GUI_OUTCOME='success', PRIMARY_FINISHED='true', SEQUENCE_OUTCOME='success',
                       EVIDENCE_OUTCOME='success', HEADER_OUTCOME='success', POINTER_OUTCOME='success',
                       SELECTION_SCENARIO='full')
        failures = [dict(), *[{key: 'failure'} for key in ['GUI_OUTCOME', 'SEQUENCE_OUTCOME',
                     'EVIDENCE_OUTCOME', 'HEADER_OUTCOME', 'POINTER_OUTCOME']], {'PRIMARY_FINISHED': ''},
                     {'POINTER_OUTCOME': 'skipped'}]
        with tempfile.TemporaryDirectory(prefix='macventory-report-') as directory:
            for change in failures:
                with self.subTest(change=change):
                    env = dict(os.environ, **initial)
                    env.update(change, GITHUB_STEP_SUMMARY=str(Path(directory)/'summary'))
                    result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', shell], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, not bool(change))
                    if change:
                        self.assertIn('::error::', result.stdout)
                        self.assertIn('did NOT validate', result.stdout)

    def test_failed_activity_export_retains_attachments_but_fails_the_arm(self):
        workflow = (ROOT/'.github/workflows/ci.yml').read_text()
        evidence = workflow.split('      - name: Export primary xcresult evidence', 1)[1].split('      - name:', 1)[0]
        shell = textwrap.dedent(evidence.split('        run: |\n', 1)[1])
        with tempfile.TemporaryDirectory(prefix='macventory-export-fixture-') as directory:
            root = Path(directory)
            (root/'build/verification').mkdir(parents=True)
            (root/'scripts').mkdir()
            shutil.copy(ROOT/'scripts/verify-ui-selection-run.py', root/'scripts')
            bin_dir = root/'bin'
            bin_dir.mkdir()
            fake = bin_dir/'xcrun'
            fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
with pathlib.Path(os.environ['EXPORT_CALLS']).open('a') as out: out.write(json.dumps(sys.argv[1:])+'\\n')
print('{}')
sys.exit(1 if any('testAOriginalActivation' in arg for arg in sys.argv) else 0)
''')
            fake.chmod(0o700)
            env = dict(os.environ, PATH=str(bin_dir)+':'+os.environ['PATH'], SELECTION_SCENARIO='startup',
                       STARTUP_ARM='original',
                       EXPORT_CALLS=str(root/'calls.jsonl'))
            result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', shell], cwd=root, env=env,
                                    capture_output=True, text=True)
            calls = [json.loads(line) for line in (root/'calls.jsonl').read_text().splitlines()]
            self.assertEqual(result.returncode, 1)
            self.assertEqual(len([c for c in calls if 'activities' in c]), 1)
            self.assertTrue(any(c[:3] == ['xcresulttool', 'export', 'attachments'] for c in calls))

if __name__ == '__main__':
    unittest.main()

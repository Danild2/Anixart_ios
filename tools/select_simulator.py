"""Create iPhone 17 with an actually compatible runtime; record exact coverage."""
import json
import os
import pathlib
import subprocess


def version(value):
    return tuple(map(int, value.split('.')))


def select():
    runtimes = json.loads(pathlib.Path('Artifacts/runtimes.json').read_text())['runtimes']
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], text=True).strip()
    candidates = sorted((r for r in runtimes if r.get('isAvailable') and 'iOS' in r['name']
                         and (27, 0) <= version(r['version']) <= version(sdk)),
                        key=lambda r: version(r['version']), reverse=True)
    failures = []
    for runtime in candidates:
        result = subprocess.run(['xcrun', 'simctl', 'create', 'Anixart-CI',
                                 'com.apple.CoreSimulator.SimDeviceType.iPhone-17', runtime['identifier']],
                                capture_output=True, text=True)
        if result.returncode:
            failures.append({'runtime': runtime['version'], 'error': result.stderr.strip()})
            continue
        identifier = result.stdout.strip()
        record = {'device': 'iPhone 17', 'runtime': runtime['version'], 'sdk': sdk,
                  'id': identifier, 'incompatible_candidates': failures,
                  'target_device_test': 'iPhone 17 / iOS 27.1 still requires physical device'}
        pathlib.Path('Artifacts/simulator-coverage.json').write_text(json.dumps(record, indent=2))
        print(json.dumps(record, indent=2))
        with open(os.environ['GITHUB_ENV'], 'a') as output:
            output.write('SIMULATOR_ID=' + identifier + '\n')
        return
    raise RuntimeError('No installed runtime supports iPhone 17: ' + json.dumps(failures))


if __name__ == '__main__': select()

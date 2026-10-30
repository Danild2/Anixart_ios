"""Portable preflight; not a substitute for Swift compilation or an iPhone test."""
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def check():
    sources = list((ROOT / 'Sources').rglob('*.swift'))
    assert len(sources) >= 15, 'Expected modular Swift sources'
    assert sum('@main' in p.read_text(encoding='utf-8') for p in sources) == 1
    inventory = json.loads((ROOT / 'docs/API_INVENTORY.json').read_text(encoding='utf-8'))
    assert len(inventory) == 300
    paths = {item['path'] for item in inventory}
    for route in ['auth/signIn', 'filter/{page}', 'search/releases/{page}', 'episode/target/{releaseId}/{sourceId}/{position}']:
        assert route in paths, f'Missing APK evidence for {route}'
    tracked = subprocess.run(['git', 'ls-files'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
    for path in tracked:
        assert not path.startswith('.private/'), 'Private APK analysis must not be published'
        assert not path.endswith(('.apk', '.p12', '.mobileprovision')), f'Forbidden publication: {path}'
    for path in sources:
        text = path.read_text(encoding='utf-8')
        assert not re.search(r'\b(print|debugPrint|NSLog)\s*\(', text), f'Unexpected runtime log in {path.name}'
    workflow = (ROOT / '.github/workflows/ios-ipa.yml').read_text(encoding='utf-8')
    assert 'runs-on: xcode-27' in workflow and 'set -euo pipefail' in workflow
    assert 'CODE_SIGNING_ALLOWED=NO' in workflow
    print(f'Portable source preflight passed: {len(sources)} Swift files, {len(inventory)} APK routes. Swift compilation not performed here.')


if __name__ == '__main__':
    check()

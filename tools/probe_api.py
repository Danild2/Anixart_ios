"""Bounded, guest-only probes of APK-confirmed routes. Never log media URLs/cookies."""
import datetime
import json
import pathlib
import urllib.error
import urllib.parse
import urllib.request

REPORT = {'time_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'authentication': 'guest only; no account credentials used', 'requests': []}


def request(base, path, body=None, version=None):
    headers = {'Accept': 'application/json', 'User-Agent': 'AnixartPort-ContractCheck/0.1'}
    if body is not None: headers['Content-Type'] = 'application/json'
    if version: headers['API-Version'] = version
    record = {'base': base, 'path': path, 'method': 'GET' if body is None else 'POST'}
    REPORT['requests'].append(record)
    try:
        req = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        with urllib.request.urlopen(req, timeout=15) as response:
            record['http'] = response.status
            record['content_type'] = response.headers.get('Content-Type', '')
            data = json.load(response)
        record['application_code'] = data.get('code')
        record['keys'] = sorted(data.keys())
        if data.get('code') != 0: return None
        return data
    except urllib.error.HTTPError as error:
        record['http'] = error.code
        record['server'] = error.headers.get('Server')
    except Exception as error:
        # Exception strings can include URLs. Record only the exception category.
        record['error_type'] = type(error).__name__
    return None


def probe():
    catalog = None
    base = None
    for candidate in ['https://api-s.anixsekai.com/', 'https://api.anixsekai.com/']:
        catalog = request(candidate, 'filter/0', {'sort': 0, 'genres': []})
        if catalog and catalog.get('content'):
            base = candidate
            break
    if not base:
        REPORT['result'] = 'blocked: no guest catalog returned; not an app integration pass'
        return
    release = catalog['content'][0]
    REPORT['catalog_sample'] = {'id': release['id'], 'title_ru': release.get('title_ru'), 'count': len(catalog['content']), 'keys': sorted(release.keys())}
    rid = int(release['id'])
    request(base, 'search/releases/0', {'query': release.get('title_ru') or str(rid), 'searchBy': 0}, 'v2')
    request(base, f'release/{rid}?extended_mode=true')
    types = request(base, f'episode/{rid}')
    if types and types.get('types'):
        translation = types['types'][0]
        tid = int(translation['id'])
        sources = request(base, f'episode/{rid}/{tid}')
        if sources and sources.get('sources'):
            source = sources['sources'][0]
            sid = int(source['id'])
            episodes = request(base, f'episode/{rid}/{tid}/{sid}?sort=0')
            if episodes and episodes.get('episodes'):
                episode = episodes['episodes'][0]
                position = int(episode['position'])
                target = request(base, f'episode/target/{rid}/{sid}/{position}')
                if target and target.get('episode'):
                    resolved = target['episode']
                    media = urllib.parse.urlsplit(resolved.get('url') or '')
                    REPORT['media_metadata'] = {'release_id': rid, 'type_id': tid, 'source_id': sid,
                        'position': position, 'iframe': resolved.get('iframe'), 'quality': resolved.get('quality'),
                        'scheme': media.scheme, 'host': media.hostname,
                        'extension': pathlib.PurePosixPath(media.path).suffix,
                        'playback': 'not tested; no stream download or DRM/access-control bypass'}
    REPORT['result'] = 'guest response inspection performed; see per-route results; authentication and playback unverified'


if __name__ == '__main__':
    try: probe()
    finally:
        destination = pathlib.Path('Artifacts/api-report.json')
        destination.parent.mkdir(exist_ok=True)
        destination.write_text(json.dumps(REPORT, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(REPORT, ensure_ascii=False, indent=2))

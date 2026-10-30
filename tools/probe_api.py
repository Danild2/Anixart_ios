"""Bounded, guest-only probes of APK-confirmed routes. Never log media URLs/cookies."""
import datetime
import json
import pathlib
import urllib.error
import urllib.parse
import urllib.request
import concurrent.futures
import time
import re

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
    inspect_media_and_profile(base, catalog)
    release = next((item for item in catalog['content'] if (item.get('episodes_released') or 0) > 0
                    and not item.get('is_play_disabled') and not item.get('is_view_blocked')), catalog['content'][0])
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
    # Additional bounded inspection for the provider that failed the iOS video test.
    # Record hosts/schema only; never publish the target's signed URL or HTML.
    provider_types = request(base, 'episode/20290')
    providers = []
    if provider_types:
        for translation in provider_types.get('types', [])[:4]:
            sources = request(base, f"episode/20290/{translation['id']}")
            for source in (sources or {}).get('sources', [])[:2]:
                target = request(base, f"episode/target/20290/{source['id']}/1")
                episode = (target or {}).get('episode', {})
                media = urllib.parse.urlsplit(episode.get('url') or '')
                providers.append({'type_id': translation['id'], 'source_id': source['id'],
                                  'source_name': source.get('name'), 'iframe': episode.get('iframe'),
                                  'host': media.hostname, 'extension': pathlib.PurePosixPath(media.path).suffix})
                if 'wrapper' not in REPORT and episode.get('iframe') and media.scheme == 'https':
                    wrapper = 'https://anixmirai.com/iframe?' + urllib.parse.urlencode({'url': episode['url']})
                    try:
                        with urllib.request.urlopen(wrapper, timeout=15) as response:
                            page = response.read(1_000_000).decode('utf-8', errors='replace')
                            REPORT['wrapper'] = {'http': response.status, 'has_iframe': '<iframe' in page.lower(),
                                                 'has_video': '<video' in page.lower(), 'bytes': len(page)}
                    except urllib.error.HTTPError as error:
                        REPORT['wrapper'] = {'http': error.code}
                    except Exception as error:
                        REPORT['wrapper'] = {'error_type': type(error).__name__}
    REPORT['providers'] = providers
    for path in ['feed/latest/all/0', 'channel/recommendations/0', 'schedule']:
        response = request(base, path)
        if response:
            sample = (response.get('content') or [{}])[0]
            REPORT.setdefault('additional_schemas', {})[path] = {
                'keys': sorted(response), 'content_count': len(response.get('content') or []),
                'sample_keys': sorted(sample),
                'block_types': sorted({block.get('type', '') for block in (sample.get('payload') or {}).get('blocks', [])})}


def inspect_media_and_profile(base, catalog):
    def inspect_image(item):
        raw = item.get('image')
        record = {'release_id': item['id'], 'image_present': bool(raw), 'poster_type': type(item.get('poster')).__name__}
        if not isinstance(raw, str): return record
        url = urllib.parse.urlsplit(raw)
        record.update(host=url.hostname, scheme=url.scheme, extension=pathlib.PurePosixPath(url.path).suffix)
        started = time.monotonic()
        try:
            req = urllib.request.Request(raw, headers={'User-Agent':'AnixartPort/0.1 (image diagnostics)', 'Accept':'image/*'})
            with urllib.request.urlopen(req, timeout=20) as response:
                data = response.read(6_000_001)
                record.update(http=response.status, content_type=response.headers.get('Content-Type'), bytes=len(data),
                              prefix_hex=data[:12].hex(), cache_control=response.headers.get('Cache-Control'))
        except urllib.error.HTTPError as error: record['http'] = error.code
        except Exception as error: record['error_type'] = type(error).__name__
        record['elapsed_ms'] = round((time.monotonic()-started)*1000)
        return record
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        REPORT['image_diagnostics'] = list(pool.map(inspect_image, catalog.get('content', [])[:12]))
    for path in ['config/toggles', 'config/urls']:
        response = request(base, path + '?version_code=26101718&is_beta=false&is_api_alt=false')
        if response:
            public = {}
            for key in ['iframeEmbedUrl','iframe_embed_url','staticDomain','static_domain','sibnetUserAgent','sibnet_user_agent','consentRequired','consent_required']:
                value = response.get(key)
                if value is not None:
                    if isinstance(value, str) and value.startswith('https://'):
                        parsed = urllib.parse.urlsplit(value)
                        public[key] = {'host': parsed.hostname, 'path': parsed.path, 'query_names': [x[0] for x in urllib.parse.parse_qsl(parsed.query,keep_blank_values=True)]}
                    elif key.lower().replace('_','') == 'staticdomain': public[key] = value
                    elif isinstance(value,bool): public[key] = value
            REPORT.setdefault('public_configuration', {})[path] = public
    profile = request(base, 'profile/1')
    if profile and isinstance(profile.get('profile'), dict):
        value = profile['profile']
        REPORT['profile_statistics_schema'] = {key: {'type':type(value.get(key)).__name__, 'count':len(value[key]) if isinstance(value.get(key),list) else None,
            'sample_keys':sorted(value[key][0]) if isinstance(value.get(key),list) and value[key] and isinstance(value[key][0],dict) else None}
            for key in ['watching_count','plan_count','completed_count','hold_on_count','dropped_count','watched_time','watched_episode_count','watch_dynamics','preferred_genres','preferred_audiences','preferred_themes','is_stats_hidden']}
    search = request(base, 'search/releases/0', {'query':'Инициал Ди', 'searchBy':0}, 'v2')
    matches = (search or {}).get('releases', [])
    sample = next((x for x in matches if 'первая' in (x.get('title_ru') or '').lower()), None)
    if not sample: return
    rid = int(sample['id']); REPORT['initial_d'] = {'release_id':rid,'providers':[]}
    types = request(base, f'episode/{rid}') or {}
    seen = set()
    for translation in types.get('types', [])[:12]:
        sources = request(base, f"episode/{rid}/{translation['id']}") or {}
        for source in sources.get('sources', [])[:4]:
            name = source.get('name','')
            if name in seen: continue
            seen.add(name)
            target = request(base, f"episode/target/{rid}/{source['id']}/1") or {}
            episode = target.get('episode', {}); raw = episode.get('url') or ''; parsed = urllib.parse.urlsplit(raw)
            result = {'type_id':translation['id'],'source_id':source['id'],'name':name,'iframe':episode.get('iframe'),'host':parsed.hostname}
            if parsed.scheme == 'https' and parsed.hostname in ['video.sibnet.ru','kodikplayer.com','kodik.cc','kodik.info','aniqit.com']:
                try:
                    with urllib.request.urlopen(raw,timeout=15) as response:
                        page = response.read(2_000_000).decode('utf-8',errors='replace')
                        result.update(http=response.status,bytes=len(page),has_media_source=bool(re.search(r'src\s*:\s*[\"\x27]',page)))
                except urllib.error.HTTPError as error:
                    body = error.read(10000).decode('utf-8',errors='replace')
                    code = re.search(r'Error code:\s*(\w+)',body)
                    result.update(http=error.code,provider_error=code.group(1) if code else None)
                except Exception as error: result['error_type'] = type(error).__name__
            REPORT['initial_d']['providers'].append(result)


if __name__ == '__main__':
    try: probe()
    finally:
        destination = pathlib.Path('Artifacts/api-report.json')
        destination.parent.mkdir(exist_ok=True)
        destination.write_text(json.dumps(REPORT, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(REPORT, ensure_ascii=False, indent=2))

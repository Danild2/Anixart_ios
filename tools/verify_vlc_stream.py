"""Decode every expected private capture; never print media URLs or native diagnostics."""
import argparse
import json
import os
import pathlib
import time
import urllib.parse


def read_capture(path):
    if path.stat().st_size > 32768:
        raise ValueError('Oversized capture')
    record = json.loads(path.read_text())
    key = tuple(record[name] for name in ('release_id', 'source_id', 'position'))
    if any(type(value) is not int or value <= 0 for value in key):
        raise ValueError('Invalid source identity')
    parsed = urllib.parse.urlsplit(record['url'])
    if parsed.scheme not in ('http', 'https') or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError('Capture is not an HTTP(S) media stream')
    return key, record


def decode(record, vlc):
    result = {name: record[name] for name in ('release_id', 'source_id', 'position')}
    instance = vlc.Instance('--intf=dummy', '--vout=dummy', '--aout=dummy', '--no-video-title-show', '--quiet')
    if instance is None:
        return dict(result, passed=False, failure='runtime initialization')
    player = instance.media_player_new()
    media = instance.media_new(record['url'])
    player.set_media(media)
    maximum_time = maximum_frames = maximum_audio = maximum_length = 0
    deadline = time.monotonic() + 150
    try:
        if player.play() >= 0:
            while time.monotonic() < deadline:
                stats = vlc.MediaStats()
                if media.get_stats(stats):
                    maximum_frames = max(maximum_frames, stats.decoded_video)
                    maximum_audio = max(maximum_audio, stats.decoded_audio)
                maximum_time = max(maximum_time, player.get_time())
                maximum_length = max(maximum_length, player.get_length())
                if maximum_frames >= 10 and maximum_audio > 0 and maximum_time >= 5000 and maximum_length >= 300000:
                    break
                if player.get_state() in (vlc.State.Error, vlc.State.Ended):
                    break
                time.sleep(0.5)
    finally:
        player.stop()
        player.release()
        media.release()
        instance.release()
    # These known full episodes exceed five minutes. A short advertising clip is not a pass.
    return dict(result, decoded_video_frames=maximum_frames, decoded_audio_blocks=maximum_audio,
                playback_ms=maximum_time, duration_ms=maximum_length,
                passed=maximum_frames >= 10 and maximum_audio > 0 and maximum_time >= 5000 and maximum_length >= 300000)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('captures', type=pathlib.Path)
    parser.add_argument('report', type=pathlib.Path)
    parser.add_argument('--expect', action='append', required=True, help='release:source:episode')
    args = parser.parse_args()
    expected = {tuple(map(int, value.split(':'))) for value in args.expect}
    if any(len(value) != 3 or min(value) <= 0 for value in expected):
        raise SystemExit('Invalid expected source identity')
    paths = sorted(args.captures.glob('*.json'))
    records = {}
    failures = []
    try:
        for path in paths:
            try:
                key, record = read_capture(path)
                if key in records:
                    raise ValueError('Duplicate source capture')
                records[key] = record
            except Exception:
                failures.append('Invalid or duplicate capture')
        # Providers can include signed URLs in native diagnostics; keep stderr private.
        sink = os.open(os.devnull, os.O_WRONLY)
        os.dup2(sink, 2)
        os.close(sink)
        import vlc
        results = []
        for key in sorted(expected):
            if key not in records:
                results.append(dict(zip(('release_id', 'source_id', 'position'), key), passed=False, failure='no media URL captured by iOS UI'))
                continue
            try:
                results.append(decode(records[key], vlc))
            except Exception:
                results.append(dict(zip(('release_id', 'source_id', 'position'), key), passed=False, failure='VLC verification error'))
        report = dict(providers=results, capture_errors=failures,
                      passed=not failures and all(result['passed'] for result in results))
        args.report.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))
        if not report['passed']:
            raise SystemExit('Not all required providers decoded video and audio in VLC')
    finally:
        for path in paths:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()

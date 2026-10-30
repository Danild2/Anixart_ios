"""Decode a private URL captured by the real iOS UI flow; never print its URL."""
import argparse
import json
import os
import pathlib
import time
import urllib.parse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=pathlib.Path)
    parser.add_argument('report', type=pathlib.Path)
    args = parser.parse_args()
    record = json.loads(args.capture.read_text())
    parsed = urllib.parse.urlsplit(record['url'])
    if parsed.scheme not in ('http', 'https') or not parsed.hostname or parsed.username:
        raise SystemExit('Capture is not an HTTP(S) media stream')
    # Redirect native VLC diagnostics too: providers can include signed URLs there.
    sink = os.open(os.devnull, os.O_WRONLY)
    os.dup2(sink, 2)
    os.close(sink)
    import vlc
    instance = vlc.Instance('--intf=dummy', '--vout=dummy', '--aout=dummy', '--no-video-title-show', '--quiet')
    player = instance.media_player_new()
    media = instance.media_new(record['url'])
    player.set_media(media)
    maximum_time = maximum_frames = 0
    deadline = time.monotonic() + 150
    try:
        if player.play() < 0:
            raise SystemExit('VLC rejected the real source')
        while time.monotonic() < deadline:
            stats = vlc.MediaStats()
            if media.get_stats(stats):
                maximum_frames = max(maximum_frames, stats.decoded_video)
            maximum_time = max(maximum_time, player.get_time())
            if maximum_frames >= 10 and maximum_time >= 5000:
                break
            if player.get_state() in (vlc.State.Error, vlc.State.Ended):
                break
            time.sleep(0.5)
    finally:
        player.stop()
        player.release()
        media.release()
        instance.release()
        args.capture.unlink(missing_ok=True)
    result = {name: record[name] for name in ('release_id', 'source_id', 'position')}
    result.update(decoded_video_frames=maximum_frames, playback_ms=maximum_time,
                  passed=maximum_frames >= 10 and maximum_time >= 5000)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    if not result['passed']:
        raise SystemExit('VLC did not decode the real Anixart stream')


if __name__ == '__main__':
    main()

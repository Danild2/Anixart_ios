import json
import pathlib
import tempfile
import unittest
from verify_vlc_stream import read_capture


class CaptureValidationTests(unittest.TestCase):
    def check_record(self, record):
        with tempfile.TemporaryDirectory() as directory:
            file = pathlib.Path(directory) / 'capture.json'
            file.write_text(json.dumps(record))
            return read_capture(file)

    def test_signed_query_and_source_identity_are_preserved(self):
        record = dict(url='https://cdn.example.test/a.m3u8?signed=a%2Bb%26c', release_id=841, source_id=8, position=1)
        key, actual = self.check_record(record)
        self.assertEqual(key, (841, 8, 1))
        self.assertEqual(actual['url'], record['url'])

    def test_invalid_urls_and_missing_source_identity_are_rejected(self):
        for url in ['file:///secret', 'https://user:pass@example.test/a.mp4', 'https:///a.mp4']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.check_record(dict(url=url, release_id=841, source_id=8, position=1))
        with self.assertRaises(ValueError):
            self.check_record(dict(url='https://cdn.example.test/a.mp4', release_id=841, source_id=True, position=1))

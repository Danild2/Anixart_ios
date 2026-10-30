import pathlib
import plistlib
import struct
import tempfile
import unittest
import zipfile
from verify_ipa import verify


class IPATests(unittest.TestCase):
    def archive(self, directory, *, binary=None, extra=None, bundle='local.anixartport.client'):
        path = pathlib.Path(directory) / 'test.ipa'
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('Payload/Test.app/Info.plist', plistlib.dumps({'CFBundleIdentifier': bundle, 'CFBundleExecutable': 'Test'}))
            executable = zipfile.ZipInfo('Payload/Test.app/Test')
            executable.external_attr = 0o100755 << 16
            archive.writestr(executable, binary if binary is not None else struct.pack('<II', 0xfeedfacf, 0x0100000c) + bytes(24))
            if extra:
                archive.writestr(extra, b'x')
        return path

    def test_arm64_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            verify(self.archive(directory))

    def test_rejects_simulator_or_non_macho(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError): verify(self.archive(directory, binary=b'not a device binary'))

    def test_rejects_wrong_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError): verify(self.archive(directory, bundle='changed.bundle'))

    def test_rejects_apk(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError): verify(self.archive(directory, extra='Payload/Test.app/original.apk'))

    def test_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError): verify(self.archive(directory, extra='../escape'))


if __name__ == '__main__': unittest.main()

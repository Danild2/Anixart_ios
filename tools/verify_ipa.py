"""Check an unsigned, ARM64 iOS app's ZIP structure without claiming installation."""
import pathlib
import plistlib
import struct
import sys
import zipfile


def verify(path):
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f'CRC failed: {bad}')
        names = archive.namelist()
        if any(n.startswith('/') or '..' in pathlib.PurePosixPath(n).parts for n in names):
            raise ValueError('Unsafe ZIP path')
        apps = {n.split('/')[1] for n in names if n.startswith('Payload/') and len(n.split('/')) > 2 and n.split('/')[1].endswith('.app')}
        if len(apps) != 1:
            raise ValueError('IPA must contain exactly one Payload/*.app')
        prefix = 'Payload/' + apps.pop() + '/'
        info = plistlib.loads(archive.read(prefix + 'Info.plist'))
        if info.get('CFBundleIdentifier') != 'local.anixartport.client':
            raise ValueError('Unexpected bundle ID')
        executable = info['CFBundleExecutable']
        if '/' in executable or executable in ('.', '..'):
            raise ValueError('Invalid executable name')
        binary = archive.read(prefix + executable)
        # Release device builds are expected to be a thin, little-endian ARM64 Mach-O.
        if len(binary) < 32 or struct.unpack_from('<II', binary) != (0xfeedfacf, 0x0100000c):
            raise ValueError('Executable is not a thin ARM64 Mach-O')
        if not archive.getinfo(prefix + executable).external_attr >> 16 & 0o111:
            raise ValueError('Executable permission bit missing')
        if any(n.endswith(('.apk', '.p12', '.mobileprovision')) for n in names):
            raise ValueError('Unexpected proprietary or signing material in unsigned IPA')
        print(f'IPA structure and ARM64 executable verified; minimum iOS {info.get("MinimumOSVersion")}. Device installation not tested.')


if __name__ == '__main__':
    verify(sys.argv[1])

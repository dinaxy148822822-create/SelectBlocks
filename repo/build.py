#!/usr/bin/env python3
"""Publish real release DEBs as three isolated, flat APT channels. Standard library only."""
import argparse
import base64
import bz2
import datetime
import email.utils
import gzip
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib

CHANNELS = {
    'rootless': {'path': '', 'arch': 'iphoneos-arm64', 'title': 'Rootless'},
    'rootful': {'path': 'rootful', 'arch': 'iphoneos-arm', 'title': 'Rootful'},
    'rootful-legacy': {'path': 'legacy', 'arch': 'iphoneos-arm', 'title': 'Rootful Legacy'},
}


def fields(text):
    result = {}
    key = None
    for line in text.splitlines():
        if line.startswith((' ', '\t')) and key:
            result[key] += '\n' + line
        elif ':' in line:
            key, value = line.split(':', 1)
            result[key] = value.lstrip()
    return result


def classify(name):
    if not re.fullmatch(r'SelectBlocks_[A-Za-z0-9.+~_-]+\.deb', name):
        raise ValueError('Unsafe or unrecognized asset name: ' + name)
    for variant in ('rootful-legacy', 'rootless', 'rootful'):
        if name.endswith('_' + variant + '.deb'):
            return variant
    raise ValueError('Unrecognized package variant: ' + name)


def validate_metadata(meta, variant):
    if meta.get('Package') != 'local.selectblocks':
        raise ValueError('Unexpected package identifier')
    if meta.get('Architecture') != CHANNELS[variant]['arch']:
        raise ValueError('Package architecture does not match its channel')
    if not re.fullmatch(r'[A-Za-z0-9.+:~_-]+', meta.get('Version', '')):
        raise ValueError('Invalid package version')
    if 'firmware' not in meta.get('Depends', ''):
        raise ValueError('Firmware requirements missing')


def validate_release_fields(text, expected_arch):
    # Matches the mandatory Release-field gates in Sileo RepoManager.swift.
    meta = fields(text)
    for key in ('Origin', 'Label', 'Architectures', 'Components', 'SHA256'):
        if not meta.get(key, '').strip():
            raise ValueError('Release missing mandatory field: ' + key)
    if expected_arch not in meta['Architectures'].split():
        raise ValueError('Release architecture does not match its channel')


def png_icon(size=128, use_custom=True):
    custom = Path(__file__).with_name('icon.png.b64')
    if use_custom and custom.exists():
        data = base64.b64decode(custom.read_text().strip(), validate=True)
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError('Custom repository icon is not PNG')
        return data
    def chunk(tag, data):
        return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xffffffff)
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            gx, gy = x * 128 // size, y * 128 // size
            tile = any(a <= gx < a + 25 and b <= gy < b + 25 for a, b in [(20, 36), (49, 36), (78, 36), (49, 65)])
            row.extend((112, 201, 221) if tile else (16, 23, 39))
        rows.append(b'\0' + row)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')


def write_channel(folder, variant, deb, meta, source_url, depiction_url=None):
    validate_metadata(meta, variant)
    folder.mkdir(parents=True, exist_ok=True)
    pool = folder / 'pool'
    pool.mkdir(exist_ok=True)
    destination = pool / deb.name
    shutil.copyfile(deb, destination)
    data = destination.read_bytes()
    icon_data = png_icon()
    icon_name = 'icon-' + hashlib.sha256(icon_data).hexdigest()[:12] + '.png'
    (folder / icon_name).write_bytes(icon_data)
    package_icon_data = png_icon(use_custom=False)
    package_icon_name = 'package-icon-' + hashlib.sha256(package_icon_data).hexdigest()[:12] + '.png'
    (folder / package_icon_name).write_bytes(package_icon_data)
    record = dict(meta)
    # These belong to the index; never trust stale values from DEB control data.
    for key in ('Filename', 'Size', 'MD5sum', 'SHA1', 'SHA256', 'SHA512', 'Depiction', 'SileoDepiction', 'Icon'):
        record.pop(key, None)
    record.update({
        'Filename': 'pool/' + deb.name,
        'Size': str(len(data)),
        'MD5sum': hashlib.md5(data).hexdigest(),
        'SHA256': hashlib.sha256(data).hexdigest(),
        'SHA512': hashlib.sha512(data).hexdigest(),
        'Depiction': depiction_url or source_url,
        'Icon': source_url + package_icon_name,
    })
    package_data = ('\n'.join(k + ': ' + v for k, v in record.items()) + '\n\n').encode()
    (folder / 'Packages').write_bytes(package_data)
    (folder / 'Packages.gz').write_bytes(gzip.compress(package_data, mtime=0))
    (folder / 'Packages.bz2').write_bytes(bz2.compress(package_data))
    release = [
        'Origin: sayadev',
        'Label: sayadev',
        'Suite: stable',
        'Codename: selectblocks-' + variant,
        'Version: ' + meta['Version'],
        'Date: ' + email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc), usegmt=True),
        'Architectures: ' + CHANNELS[variant]['arch'],
        'Components: main',
        'Icon: ' + source_url + icon_name,
        'Description: SelectBlocks ' + CHANNELS[variant]['title'] + ' packages; unsigned metadata over HTTPS',
    ]
    for label, algorithm in [('MD5Sum', 'md5'), ('SHA256', 'sha256'), ('SHA512', 'sha512')]:
        release.append(label + ':')
        for name in ('Packages', 'Packages.gz', 'Packages.bz2'):
            content = (folder / name).read_bytes()
            release.append(' ' + hashlib.new(algorithm, content).hexdigest() + ' ' + str(len(content)) + ' ' + name)
    release_text = '\n'.join(release) + '\n'
    validate_release_fields(release_text, CHANNELS[variant]['arch'])
    (folder / 'Release').write_text(release_text)
    for name in ('CydiaIcon.png', 'CydiaIcon@2x.png', 'CydiaIcon@3x.png'):
        (folder / name).write_bytes(icon_data)
    return {'variant': variant, 'url': source_url, 'version': meta['Version'], 'depends': meta['Depends'], 'file': source_url + 'pool/' + deb.name, 'icon': source_url + icon_name, 'package_icon': source_url + package_icon_name}


def make_page(config):
    template = (Path(__file__).parent / 'index.html').read_text()
    payload = json.dumps(config, ensure_ascii=False).replace('<', '\\u003c')
    return template.replace('/*REPOSITORY_DATA*/{}', payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', default=os.environ.get('GITHUB_REPOSITORY', 'dinaxy148822822-create/SelectBlocks'))
    parser.add_argument('--output', default='_site')
    parser.add_argument('--base-url', default=os.environ.get('APT_BASE_URL', ''))
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        result = unittest.main(argv=['repo/build.py'], exit=False).result
        if not result.wasSuccessful():
            raise SystemExit(1)
        return
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repository):
        raise ValueError('Invalid repository name')
    owner, repo = args.repository.split('/')
    base_url = (args.base_url or 'https://raw.githubusercontent.com/' + owner.lower() + '/' + repo.lower() + '/apt/').rstrip('/') + '/'
    web_url = 'https://' + owner.lower() + '.github.io/' + repo + '/'
    if not base_url.startswith('https://'):
        raise ValueError('The public APT URL must use HTTPS')
    release = json.loads(subprocess.check_output(['gh', 'api', 'repos/' + args.repository + '/releases/latest'], text=True))
    if release.get('draft') or release.get('prerelease'):
        raise ValueError('Only a published stable release can be indexed')
    assets = [a for a in release.get('assets', []) if a['name'].startswith('SelectBlocks_') and a['name'].endswith('.deb')]
    if not assets:
        raise ValueError('No published SelectBlocks DEBs. Refusing to deploy an empty repository.')
    out = Path(args.output).resolve()
    if out == Path.cwd().resolve() or out == Path('/') or out == Path(__file__).parent.resolve():
        raise ValueError('Unsafe output directory')
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    entries = []
    versions = set()
    seen = set()
    with tempfile.TemporaryDirectory() as temp:
        for asset in assets:
            name = asset['name']
            variant = classify(name)
            if variant in seen:
                raise ValueError('Duplicate release variant: ' + variant)
            seen.add(variant)
            subprocess.run(['gh', 'release', 'download', release['tag_name'], '--repo', args.repository, '--pattern', name, '--dir', temp], check=True)
            deb = Path(temp) / name
            data = deb.read_bytes()
            if len(data) != asset['size'] or len(data) > 50 * 1024 * 1024:
                raise ValueError('Downloaded asset size mismatch')
            digest = asset.get('digest')
            if digest and digest.startswith('sha256:') and hashlib.sha256(data).hexdigest() != digest.split(':', 1)[1]:
                raise ValueError('Published SHA256 digest mismatch')
            meta = fields(subprocess.check_output(['dpkg-deb', '--field', str(deb)], text=True))
            validate_metadata(meta, variant)
            versions.add(meta['Version'])
            subprocess.run(['dpkg-deb', '--contents', str(deb)], check=True, stdout=subprocess.DEVNULL)
            suffix = CHANNELS[variant]['path']
            source_url = base_url + (suffix + '/' if suffix else '')
            entries.append(write_channel(out / suffix, variant, deb, meta, source_url, web_url + (suffix + '/' if suffix else '')))
    if len(versions) != 1:
        raise ValueError('Refusing to mix different versions across release variants')
    from extra_packages import publish_pinned
    with tempfile.TemporaryDirectory() as temp:
        extra_entries = publish_pinned(out, base_url, entries, temp)
    config = {'repository': 'https://github.com/' + args.repository, 'release': release['html_url'], 'version': next(iter(versions)), 'base': base_url, 'entries': entries, 'signed': False, 'extra_packages': extra_entries}
    page = make_page(config)
    (out / 'index.html').write_text(page)
    for variant in ('rootful', 'rootful-legacy'):
        folder = out / CHANNELS[variant]['path']
        folder.mkdir(exist_ok=True)
        (folder / 'index.html').write_text(page)
    (out / '.nojekyll').touch()
    (out / 'repository.json').write_text(json.dumps(config, ensure_ascii=False, indent=2))
    print('Validated release', release['tag_name'], 'and published channels:', ', '.join(sorted(seen)))


class RepositoryTests(unittest.TestCase):
    def test_classification_and_traversal(self):
        for variant in CHANNELS:
            self.assertEqual(classify('SelectBlocks_1.1.0_' + variant + '.deb'), variant)
        for bad in ('../SelectBlocks_1_rootless.deb', 'other.deb', 'SelectBlocks_1_unknown.deb'):
            with self.assertRaises(ValueError):
                classify(bad)

    def test_architecture_rejection(self):
        with self.assertRaises(ValueError):
            validate_metadata({'Package': 'local.selectblocks', 'Architecture': 'iphoneos-arm', 'Version': '1', 'Depends': 'firmware'}, 'rootless')

    def test_three_isolated_indexes(self):
        # Byte fixtures are only hash/index unit-test inputs, NOT installable DEBs.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for variant in CHANNELS:
                fixture = root / ('SelectBlocks_0.0-test_' + variant + '.deb')
                fixture.write_bytes(b'UNIT TEST FIXTURE, NOT A DEBIAN PACKAGE\n' + variant.encode())
                meta = {'Package': 'local.selectblocks', 'Name': 'SelectBlocks', 'Architecture': CHANNELS[variant]['arch'], 'Version': '0.0-test', 'Depends': 'firmware (>= 15.0), mobilesubstrate', 'Description': 'Test\n continuation'}
                folder = root / 'site' / (CHANNELS[variant]['path'] or '.')
                entry = write_channel(folder, variant, fixture, meta, 'https://example.invalid/' + variant + '/')
                raw = (folder / 'Packages').read_bytes()
                self.assertEqual(gzip.decompress((folder / 'Packages.gz').read_bytes()), raw)
                self.assertEqual(bz2.decompress((folder / 'Packages.bz2').read_bytes()), raw)
                record = fields(raw.decode())
                self.assertEqual(record['SHA256'], hashlib.sha256(fixture.read_bytes()).hexdigest())
                self.assertEqual((folder / record['Filename']).read_bytes(), fixture.read_bytes())
                self.assertIn(hashlib.sha256(raw).hexdigest(), (folder / 'Release').read_text())
                self.assertEqual(entry['variant'], variant)
                release_meta = fields((folder / 'Release').read_text())
                self.assertEqual(release_meta['Origin'], 'sayadev')
                self.assertEqual(release_meta['Label'], 'sayadev')
                self.assertTrue((folder / 'CydiaIcon.png').read_bytes().startswith(b'\x89PNG'))

    def test_sileo_mandatory_release_components(self):
        valid = 'Origin: Test\nLabel: Test\nArchitectures: iphoneos-arm64\nComponents: main\nSHA256:\n abc 1 Packages\n'
        validate_release_fields(valid, 'iphoneos-arm64')
        with self.assertRaisesRegex(ValueError, 'Components'):
            validate_release_fields(valid.replace('Components: main\n', ''), 'iphoneos-arm64')
        with self.assertRaisesRegex(ValueError, 'architecture'):
            validate_release_fields(valid, 'iphoneos-arm')

    def test_package_and_repository_icons_are_independent(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            fixture = root / 'SelectBlocks_0.0-test_rootless.deb'
            fixture.write_bytes(b'UNIT TEST FIXTURE, NOT AN INSTALLABLE DEB')
            meta = {'Package': 'local.selectblocks', 'Name': 'SelectBlocks', 'Architecture': 'iphoneos-arm64', 'Version': '0.0-test', 'Depends': 'firmware (>= 15.0), mobilesubstrate'}
            folder = root / 'site'
            entry = write_channel(folder, 'rootless', fixture, meta, 'https://example.invalid/')
            package = fields((folder / 'Packages').read_text())
            release = fields((folder / 'Release').read_text())
            self.assertEqual(package['Icon'], entry['package_icon'])
            self.assertEqual(release['Icon'], entry['icon'])
            self.assertNotEqual(package['Icon'], release['Icon'])
            self.assertEqual((folder / entry['package_icon'].rsplit('/', 1)[1]).read_bytes(), png_icon(use_custom=False))
            self.assertEqual((folder / 'CydiaIcon.png').read_bytes(), png_icon())

    def test_extra_package_preserves_existing_source_and_hashes(self):
        from extra_packages import append_record
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            fixture = root / 'SelectBlocks_0.0-test_rootless.deb'
            fixture.write_bytes(b'UNIT TEST FIXTURE, NOT AN INSTALLABLE DEB')
            meta = {'Package': 'local.selectblocks', 'Name': 'SelectBlocks', 'Architecture': 'iphoneos-arm64', 'Version': '0.0-test', 'Depends': 'firmware (>= 15.0)'}
            folder = root / 'site'
            write_channel(folder, 'rootless', fixture, meta, 'https://example.invalid/')
            original = (folder / 'Packages').read_bytes()
            source_icon = (folder / 'CydiaIcon.png').read_bytes()
            old_release = fields((folder / 'Release').read_text())
            extra = {'Package': 'local.wifipilot', 'Name': 'WiFiPilot (Experimental)', 'Architecture': 'iphoneos-arm64', 'Version': '0.1.0', 'Depends': 'firmware (>= 16.0), firmware (<< 17.0)', 'Icon': 'https://example.invalid/wifi.png'}
            append_record(folder, extra)
            raw = (folder / 'Packages').read_bytes()
            self.assertTrue(raw.startswith(original))
            self.assertEqual(len([x for x in raw.decode().split('\n\n') if x.strip()]), 2)
            self.assertIn(b'Package: local.wifipilot', raw)
            self.assertEqual(gzip.decompress((folder / 'Packages.gz').read_bytes()), raw)
            self.assertEqual(bz2.decompress((folder / 'Packages.bz2').read_bytes()), raw)
            new_release = fields((folder / 'Release').read_text())
            for key in ('Origin', 'Label', 'Icon', 'Components', 'Architectures'):
                self.assertEqual(new_release[key], old_release[key])
            self.assertIn(hashlib.sha256(raw).hexdigest(), new_release['SHA256'])
            self.assertEqual((folder / 'CydiaIcon.png').read_bytes(), source_icon)
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                append_record(folder, extra)

    def test_html_payload_escaping(self):
        page = make_page({'version': '</script><script>bad</script>'})
        self.assertNotIn('/*REPOSITORY_DATA*/', page)
        self.assertIn('\\u003c/script>', page)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Publish real release DEBs as three isolated, flat APT channels. Standard library only."""
import argparse
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


def png_icon(size=128):
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
        'Icon': source_url + 'CydiaIcon.png',
    })
    package_data = ('\n'.join(k + ': ' + v for k, v in record.items()) + '\n\n').encode()
    (folder / 'Packages').write_bytes(package_data)
    (folder / 'Packages.gz').write_bytes(gzip.compress(package_data, mtime=0))
    (folder / 'Packages.bz2').write_bytes(bz2.compress(package_data))
    release = [
        'Origin: SelectBlocks',
        'Label: SelectBlocks ' + CHANNELS[variant]['title'],
        'Suite: stable',
        'Codename: selectblocks-' + variant,
        'Version: ' + meta['Version'],
        'Date: ' + email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc), usegmt=True),
        'Architectures: ' + CHANNELS[variant]['arch'],
        'Description: SelectBlocks ' + CHANNELS[variant]['title'] + ' packages; unsigned metadata over HTTPS',
    ]
    for label, algorithm in [('MD5Sum', 'md5'), ('SHA256', 'sha256'), ('SHA512', 'sha512')]:
        release.append(label + ':')
        for name in ('Packages', 'Packages.gz', 'Packages.bz2'):
            content = (folder / name).read_bytes()
            release.append(' ' + hashlib.new(algorithm, content).hexdigest() + ' ' + str(len(content)) + ' ' + name)
    (folder / 'Release').write_text('\n'.join(release) + '\n')
    (folder / 'CydiaIcon.png').write_bytes(png_icon())
    return {'variant': variant, 'url': source_url, 'version': meta['Version'], 'depends': meta['Depends'], 'file': source_url + 'pool/' + deb.name}


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
    config = {'repository': 'https://github.com/' + args.repository, 'release': release['html_url'], 'version': next(iter(versions)), 'base': base_url, 'entries': entries, 'signed': False}
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
                self.assertTrue((folder / 'CydiaIcon.png').read_bytes().startswith(b'\x89PNG'))

    def test_html_payload_escaping(self):
        page = make_page({'version': '</script><script>bad</script>'})
        self.assertNotIn('/*REPOSITORY_DATA*/', page)
        self.assertIn('\\u003c/script>', page)


if __name__ == '__main__':
    main()

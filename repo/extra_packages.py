"""Explicitly pinned additional packages; never auto-promote arbitrary prereleases."""
import bz2
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile


def append_record(folder, record):
    """Preserve existing stanzas and source branding; refresh every index checksum."""
    folder = Path(folder)
    current = (folder / 'Packages').read_bytes()
    existing = [part for part in current.decode().split('\n\n') if part.strip()]
    if any(('Package: ' + record['Package']) in part.splitlines() for part in existing):
        raise ValueError('Duplicate package ID')
    data = current.rstrip(b'\n') + b'\n\n' + ('\n'.join(k + ': ' + v for k, v in record.items()) + '\n\n').encode()
    (folder / 'Packages').write_bytes(data)
    (folder / 'Packages.gz').write_bytes(gzip.compress(data, mtime=0))
    (folder / 'Packages.bz2').write_bytes(bz2.compress(data))
    release = (folder / 'Release').read_text().split('MD5Sum:\n', 1)[0].rstrip('\n')
    release += '\n'
    for label, algorithm in [('MD5Sum', 'md5'), ('SHA256', 'sha256'), ('SHA512', 'sha512')]:
        release += label + ':\n'
        for name in ('Packages', 'Packages.gz', 'Packages.bz2'):
            content = (folder / name).read_bytes()
            release += ' ' + hashlib.new(algorithm, content).hexdigest() + ' ' + str(len(content)) + ' ' + name + '\n'
    (folder / 'Release').write_text(release)


def publish_pinned(out, base_url, entries, workdir):
    # User-approved experimental release. Updating it requires a deliberate code change.
    repository = 'dinaxy148822822-create/WiFiPilot'
    tag = 'v0.2.0'
    name = 'WiFiPilot_0.2.0_rootless.deb'
    expected_hash = 'cb0c31329839713fd81d25643d8440b8e8c95532c9dad6f218dac1fe339fedf8'
    release = json.loads(subprocess.check_output(['gh', 'api', 'repos/' + repository + '/releases/tags/' + tag], text=True))
    if release.get('draft') or release.get('tag_name') != tag:
        raise ValueError('Pinned WiFiPilot release unavailable')
    assets = [a for a in release.get('assets', []) if a['name'] == name]
    if len(assets) != 1:
        raise ValueError('Pinned WiFiPilot DEB missing or duplicated')
    subprocess.run(['gh', 'release', 'download', tag, '--repo', repository, '--pattern', name, '--dir', str(workdir)], check=True)
    deb = Path(workdir) / name
    data = deb.read_bytes()
    if len(data) != assets[0]['size'] or hashlib.sha256(data).hexdigest() != expected_hash:
        raise ValueError('Pinned WiFiPilot bytes do not match approved release')
    text = subprocess.check_output(['dpkg-deb', '--field', str(deb)], text=True)
    # Import lazily so build.py can import this helper without a circular import.
    from build import fields, validate_release_fields
    meta = fields(text)
    if meta.get('Package') != 'local.wifipilot' or meta.get('Architecture') != 'iphoneos-arm64' or meta.get('Version') != '0.2.0':
        raise ValueError('Unexpected WiFiPilot package metadata')
    if 'firmware (>= 16.0)' not in meta.get('Depends', '') or 'firmware (<< 17.0)' not in meta.get('Depends', ''):
        raise ValueError('WiFiPilot iOS-16-only dependency bounds missing')
    archive = subprocess.check_output(['dpkg-deb', '--fsys-tarfile', str(deb)])
    icon_path = 'var/jb/Applications/WiFiPilot.app/Icon60@2x.png'
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
        member = next(m for m in tar.getmembers() if m.name.lstrip('./') == icon_path)
        if not member.isfile() or member.size > 1024 * 1024:
            raise ValueError('Unsafe icon entry')
        icon = tar.extractfile(member).read()
    if not icon.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('WiFiPilot icon is not PNG')
    icon_name = 'wifipilot-icon-' + hashlib.sha256(icon).hexdigest()[:12] + '.png'
    (out / icon_name).write_bytes(icon)
    shutil.copyfile(deb, out / 'pool' / name)
    for key in ('Filename', 'Size', 'MD5sum', 'SHA1', 'SHA256', 'SHA512', 'Depiction', 'SileoDepiction', 'Icon'):
        meta.pop(key, None)
    meta.update({'Filename': 'pool/' + name, 'Size': str(len(data)), 'MD5sum': hashlib.md5(data).hexdigest(), 'SHA256': expected_hash, 'SHA512': hashlib.sha512(data).hexdigest(), 'Icon': base_url + icon_name, 'Depiction': release['html_url']})
    append_record(out, meta)
    validate_release_fields((out / 'Release').read_text(), 'iphoneos-arm64')
    rootless = next(e for e in entries if e['variant'] == 'rootless')
    return [{'package': 'local.wifipilot', 'experimental': True, 'release': release['html_url'], 'variant': 'rootless', 'url': base_url, 'version': meta['Version'], 'depends': meta['Depends'], 'file': base_url + 'pool/' + name, 'icon': rootless['icon'], 'package_icon': base_url + icon_name}]

"""Explicitly pinned additional packages; never auto-promote arbitrary prereleases."""
import bz2
import gzip
import hashlib
from pathlib import Path


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
    # No additional packages are approved for this source.
    return []

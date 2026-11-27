#!/usr/bin/env python3
"""Mirror the generated APT site to a dedicated branch and verify live HTTP bytes."""
from concurrent.futures import ThreadPoolExecutor
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.request
from build import CHANNELS, fields, validate_release_fields

site = Path(sys.argv[1]).resolve()
repository = os.environ['GITHUB_REPOSITORY']
config = json.loads((site / 'repository.json').read_text())
subprocess.run(['gh', 'auth', 'setup-git'], check=True)

with tempfile.TemporaryDirectory(prefix='selectblocks-apt-') as temp:
    root = Path(temp)
    def git(*args, capture=False):
        result = subprocess.run(['git', '-C', str(root), *args], check=True, text=True, stdout=subprocess.PIPE if capture else None)
        return result.stdout or ''
    git('init', '-q')
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    git('remote', 'add', 'origin', 'https://github.com/' + repository + '.git')
    if git('ls-remote', '--heads', 'origin', 'refs/heads/apt', capture=True).strip():
        git('fetch', '--depth=1', 'origin', 'apt')
        git('checkout', '-B', 'apt', 'FETCH_HEAD')
    else:
        git('checkout', '--orphan', 'apt')
    # Keep this dedicated branch in sync without force pushes or rewriting history.
    for existing in list(root.iterdir()):
        if existing.name == '.git':
            continue
        import shutil
        if existing.is_dir():
            shutil.rmtree(existing)
        else:
            existing.unlink()
    import shutil
    shutil.copytree(site, root, dirs_exist_ok=True)
    git('add', '--all')
    if subprocess.run(['git', '-C', str(root), 'diff', '--cached', '--quiet']).returncode:
        git('commit', '-m', 'Publish SelectBlocks APT ' + config['version'])
        git('push', 'origin', 'HEAD:refs/heads/apt')

    requests = []
    for entry in config['entries'] + config.get('extra_packages', []):
        folder = site / CHANNELS[entry['variant']]['path']
        package_name = entry['file'].rsplit('/', 1)[1]
        icon_name = entry['icon'].rsplit('/', 1)[1]
        package_icon_name = entry['package_icon'].rsplit('/', 1)[1]
        for name in ('Release', 'Packages', 'Packages.gz', 'pool/' + package_name, icon_name, package_icon_name):
            requests.append((entry['url'] + name, (folder / name).read_bytes()))

    def verify(item):
        url, expected = item
        error = ''
        for attempt in range(12):
            try:
                request = urllib.request.Request(url, headers={'User-Agent': 'Sileo/2.5 APT-HTTP/1.3', 'Cache-Control': 'no-cache'})
                with urllib.request.urlopen(request, timeout=8) as response:
                    status = response.status
                    actual = response.read(50 * 1024 * 1024)
                if status != 200:
                    raise ValueError('HTTP ' + str(status))
                if url.endswith('/Release'):
                    observed = fields(actual.decode('utf-8'))
                    wanted = fields(expected.decode('utf-8'))
                    validate_release_fields(actual.decode('utf-8'), wanted['Architectures'])
                    # A CDN may retain a previous Date for the SAME package indexes.
                    # Still require the correct version, architecture and exact hash tables.
                    for key in ('Origin', 'Label', 'Version', 'Components', 'SHA256', 'SHA512'):
                        if observed.get(key) != wanted.get(key):
                            raise ValueError('Release mismatch: ' + key)
                    return True, '| 200 · Sileo fields and index hashes verified | ' + url + ' |'
                if actual != expected:
                    raise ValueError('HTTP 200: payload differs from validated artifact')
                return True, '| 200 · SHA256 verified | ' + url + ' |'
            except Exception as exc:
                error = str(exc).replace('|', '/')
                if attempt < 11:
                    time.sleep(10)
        return False, '| FAILED: ' + error + ' | ' + url + ' |'

    requests = list(dict(requests).items())
    results = list(ThreadPoolExecutor(max_workers=8).map(verify, requests))
    report = '# Live APT verification\n\nChecked: ' + datetime.datetime.now(datetime.timezone.utc).isoformat() + '\n\nUser-Agent: Sileo/2.5 APT-HTTP/1.3\n\n| Result | URL |\n| --- | --- |\n' + '\n'.join(row for ok, row in results) + '\n'
    (root / 'repository-health.md').write_text(report)
    git('add', 'repository-health.md')
    git('commit', '-m', 'Record live HTTP and package-byte verification')
    git('push', 'origin', 'HEAD:refs/heads/apt')
    print(report)
    if not all(ok for ok, row in results):
        raise SystemExit('Live APT checks failed; see apt branch repository-health.md')

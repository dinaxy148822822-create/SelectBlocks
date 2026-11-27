from pathlib import Path
import subprocess
import sys
import tempfile
variant, filename = sys.argv[1:]
expected_arch = 'iphoneos-arm64' if variant == 'rootless' else 'iphoneos-arm'
def field(name):
 return subprocess.check_output(['dpkg-deb', '-f', filename, name], text=True).strip()
assert field('Architecture') == expected_arch, 'Wrong package architecture'
control = (Path(__file__).resolve().parents[1] / 'control').read_text()
expected_version = next(line.split(':', 1)[1].strip() for line in control.splitlines() if line.startswith('Version:'))
assert field('Version') == expected_version, 'Wrong package version'
with tempfile.TemporaryDirectory() as directory:
 subprocess.run(['dpkg-deb', '-x', filename, directory], check=True)
 relative = 'Library/MobileSubstrate/DynamicLibraries/SelectBlocks.dylib'
 if variant == 'rootless':
  relative = 'var/jb/' + relative
 dylib = Path(directory) / relative
 assert dylib.is_file(), 'Wrong installation prefix or missing binary'
 archs = set(subprocess.check_output(['lipo', '-archs', str(dylib)], text=True).split())
 required = {'arm64'} if variant == 'rootful-legacy' else {'arm64', 'arm64e'}
 assert archs == required, (archs, required)
 print('PASS:', variant, field('Architecture'), ', '.join(sorted(archs)), relative)

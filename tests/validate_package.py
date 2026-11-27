from pathlib import Path
import subprocess
import sys
import tempfile
variant, filename = sys.argv[1:]
expected_arch = 'iphoneos-arm64' if variant == 'rootless' else 'iphoneos-arm'
def field(name):
 return subprocess.check_output(['dpkg-deb', '-f', filename, name], text=True).strip()
assert field('Architecture') == expected_arch, 'Wrong package architecture'
assert field('Version') == '1.1.0', 'Wrong package version'
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

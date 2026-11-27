from pathlib import Path
root = Path(__file__).resolve().parents[1]
configs = {
 'rootless': ('iphoneos-arm64', 'firmware (>= 15.0)'),
 'rootful': ('iphoneos-arm', 'firmware (>= 14.0)'),
 'rootful-legacy': ('iphoneos-arm', 'firmware (>= 12.0), firmware (<< 14.0)'),
}
for variant, (arch, dependency) in configs.items():
 text = (root / 'packaging' / (variant + '.control')).read_text()
 props = dict(line.split(': ', 1) for line in text.splitlines() if ': ' in line)
 assert props['Architecture'] == arch, variant
 assert dependency in props['Depends'], variant
 assert props['Package'] == 'local.selectblocks', variant
 assert props['Version'] == '1.2.0', variant
 assert 'mobilesubstrate' in props['Depends'], variant
source = (root / 'Tweak.xm').read_text()
assert 'majorVersion!=16' not in source
assert 'majorVersion<12' in source
assert '[UIAction actionWithHandler:' not in source
assert 'if(@available(iOS 13.0,*))' in source
assert 'initWithFrame:origin.screen.bounds' in source
makefile = (root / 'Makefile').read_text()
assert 'TARGET = iphone:clang:latest:12.0' in makefile
assert 'TARGET = iphone:clang:latest:14.0' in makefile
assert 'TARGET = iphone:clang:latest:15.0' in makefile
print('PASS: three package variants, firmware ranges, classic callbacks, window and color fallbacks.')

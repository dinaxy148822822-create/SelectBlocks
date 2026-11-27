from pathlib import Path
root=Path(__file__).resolve().parents[1];source=(root/'Tweak.xm').read_text()
assert 'NSStringEnumerationByComposedCharacterSequences' in source
assert 'SBIntroColorAt(letter++,elapsed)' in source
assert 'if(UIAccessibilityIsReduceMotionEnabled())return;' in source
assert '- (void)tick {[self updateIntroColors];' in source
assert '- (void)background:(NSNotification *)n{[self finishEntry];' in source
assert '_closing=YES;[self finishEntry];' in source
assert 'self.introLogoOriginal=nil;self.introWordOriginal=nil;' in source
assert source.count('timerWithTimeInterval:')==1
assert 'animationRepeatCount' not in source
print('PASS: grapheme coloring, reduced-motion opt-out, shared timer and cleanup on close/background')

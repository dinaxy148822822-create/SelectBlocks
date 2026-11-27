const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const aliases = JSON.parse(fs.readFileSync(path.join(__dirname, '../TriggerWords.json'), 'utf8'));
const normalize = s => s.normalize('NFKC').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f\u064b-\u065f\u0640\u0670\u061c\u200e\u200f\u200b\u2066-\u2069]/g, '').trim();
const names = [...new Set(aliases.map(normalize))];
const source = fs.readFileSync(path.join(__dirname, 'selection-template.js'), 'utf8').replace('%@', JSON.stringify(names));
function evaluate(text, ranges = 1) {
  const node = { nodeType: 1 };
  return vm.runInNewContext(source, {
    window: { getSelection: () => ({ rangeCount: ranges, toString: () => text,
      getRangeAt: () => ({ startContainer: node, getBoundingClientRect: () => ({ x: 32, y: 280, width: 75, height: 22 }) }) }),
      visualViewport: { offsetLeft: 0, offsetTop: 0, width: 375 } },
    getComputedStyle: () => ({ fontSize: '17px' }), innerWidth: 375
  });
}
let count = 0;
for (const text of [...aliases, ' TETRIS\n', 'ТЕТРИС', 'ＴＥＴＲＩＳ', 'Tétris', 'تَتْرِيس', '\u200fتتريس\u200f', 'تـتـريـس']) {
  const result = evaluate(text); assert.ok(result, text); assert.equal(result.text, text);
  assert.equal(result.geometry.length, 8); assert.equal(result.geometry[0], 32); count++;
}
for (const text of ['', 'not tetris', 'tetris!', 'тетрис игра', 'password', 'tetri', 'a'.repeat(100)]) { assert.equal(evaluate(text), null, text); count++; }
assert.equal(evaluate('tetris', 0), null); count++;
console.log(`PASS: ${count} web-selection cases, ${aliases.length} spellings, exact matches and local geometry.`);

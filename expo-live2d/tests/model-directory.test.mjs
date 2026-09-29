import test from 'node:test';
import assert from 'node:assert/strict';
import { scanModelDirectory } from '../modelDirectory.ts';

test('finds nested outfits, loose model files and imported UUID wrappers', async () => {
  const wrapper = '12345678-1234-1234-1234-123456789abc';
  const tree = {
    '': [{ name: 'sakiko', directory: true }, { name: 'loose.MODEL3.JSON', directory: false }, { name: wrapper, directory: true }, { name: '.hidden', directory: true }],
    sakiko: [{ name: '服装 #1', directory: true }],
    'sakiko/服装 #1': [{ name: '春.model3.json', directory: false }, { name: 'texture.png', directory: false }],
    [wrapper]: [{ name: '角色', directory: true }],
    [wrapper + '/角色']: [{ name: '衣服.model3.json', directory: false }],
  };
  const result = await scanModelDirectory(async path => { assert.ok(path in tree); return tree[path]; });
  assert.equal(result.errors.length, 0);
  assert.equal(result.models.length, 3);
  assert.equal(result.models.find(m => m.outfit === '春').character, 'sakiko');
  assert.equal(result.models.find(m => m.outfit === '衣服').character, '角色');
  assert.equal(result.models.find(m => m.outfit === 'loose').character, 'loose');
});

test('reports unreadable directories, skips unsafe entries and reflects removals', async () => {
  const result = await scanModelDirectory(async path => {
    if (path === 'bad') throw new Error('permission denied');
    return [{ name: 'bad', directory: true }, { name: '../outside', directory: true }, { name: 'ok.model3.json', directory: false }];
  });
  assert.equal(result.models.length, 1);
  assert.match(result.errors[0], /bad.*permission denied/);
  assert.deepEqual((await scanModelDirectory(async () => [])).models, []);
});

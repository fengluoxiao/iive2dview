import test from 'node:test';
import assert from 'node:assert/strict';
import { directionIndex, defaultFace, faceControls, displayName } from '../studio.ts';

test('direction follows model names regardless of entry order', () => {
  const entries = [{ Name: 'smile_R' }, { Name: 'smile_C' }, { Name: 'smile_L' }];
  assert.equal(directionIndex(entries, 'C'), 1);
  assert.equal(directionIndex(entries, 'L'), 2);
  assert.equal(directionIndex(entries, 'R'), 0);
});
test('motions without names use their file names; missing directions fall back', () => {
  const entries = [{ File: 'motions/idle_01_C.motion3.json' }, { File: 'motions/idle_01_R.motion3.json' }];
  assert.equal(directionIndex(entries, 'R'), 1);
  assert.equal(directionIndex(entries, 'L'), 0);
});
test('all nine original face controls have valid defaults and paired eye/brow IDs', () => {
  assert.equal(faceControls.length, 9);
  for (const control of faceControls) {
    assert.ok(defaultFace[control.key] >= control.min && defaultFace[control.key] <= control.max);
  }
  assert.equal(defaultFace.eyeOpen, 1);
  assert.deepEqual(faceControls.find(c => c.key === 'eyeOpen').ids, ['ParamEyeLOpen', 'ParamEyeROpen']);
  assert.deepEqual(faceControls.find(c => c.key === 'brow').ids, ['ParamBrowLForm', 'ParamBrowRForm']);
});
test('character labels preserve the original underscore formatting', () => {
  assert.equal(displayName('sakiko_school'), 'Sakiko School');
});

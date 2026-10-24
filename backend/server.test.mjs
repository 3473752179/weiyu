import assert from 'node:assert/strict';
import test from 'node:test';
import { findPrompt, generateAfterglow } from './server.mjs';

test('custom friend and regret map to a relevant prompt', () => {
  const result = findPrompt({
    recipientLabel: '高中时最好的朋友',
    recipientPreset: 'custom',
    emotionLabel: '说不清的失落',
    emotionPreset: 'other',
    excludePromptId: ''
  });
  assert.equal(result.recipientCategory, 'friend');
  assert.equal(result.emotionCategory, 'sad');
  assert.notEqual(result.matchedBy, 'fallback');
});

test('unknown custom values always receive a safe fallback', () => {
  const result = findPrompt({
    recipientLabel: '云朵',
    recipientPreset: 'custom',
    emotionLabel: '一种没有名字的感觉',
    emotionPreset: 'other',
    excludePromptId: ''
  });
  assert.ok(result.prompt.length > 0);
  assert.equal(result.matchedBy, 'fallback');
});

test('afterglow uses the rule template engine without model configuration', () => {
  const result = generateAfterglow({
    recipient: '写给高中时最好的朋友',
    recipientPreset: 'custom',
    emotion: '说不清的遗憾',
    emotionPreset: 'other',
    title: '没有说完的话',
    variationSeed: 'first'
  });
  assert.equal(result.engine, 'template-v1');
  assert.equal(result.candidates.length, 3);
  assert.ok(result.candidates.every(item => item.length > 0));
  assert.ok(result.keywords.includes('余光'));
});

test('afterglow variation seed rotates candidates', () => {
  const common = {
    recipient: '写给自己',
    recipientPreset: 'self',
    emotion: '迷茫',
    emotionPreset: 'confused',
    title: ''
  };
  const first = generateAfterglow({ ...common, variationSeed: '1' });
  const second = generateAfterglow({ ...common, variationSeed: '2' });
  assert.notDeepEqual(first.candidates, second.candidates);
});

test('writing prompts avoid the recent history before repeating', () => {
  const recent = [];
  const shown = [];
  for (let index = 0; index < 6; index += 1) {
    const result = findPrompt({
      recipientLabel: '高中时最好的朋友',
      recipientPreset: 'custom',
      emotionLabel: '说不清的遗憾',
      emotionPreset: 'other',
      excludePromptIds: recent,
      variationSeed: `round-${index}`
    });
    shown.push(result.id);
    recent.push(result.id);
  }
  assert.equal(new Set(shown).size, 6);
});

test('afterglow excludes the currently visible three candidates', () => {
  const common = {
    recipient: '写给自己',
    recipientPreset: 'self',
    emotion: '迷茫',
    emotionPreset: 'confused',
    title: '',
    variationSeed: 'first'
  };
  const first = generateAfterglow({ ...common, excludeCandidates: [] });
  const second = generateAfterglow({ ...common, variationSeed: 'second', excludeCandidates: first.candidates });
  assert.equal(second.candidates.filter(item => first.candidates.includes(item)).length, 0);
});

import http from 'node:http';

const PORT = Number(process.env.PORT || 8787);
const MAX_BODY_BYTES = 32 * 1024;

const PROMPTS = [
  { id: 'future_happy_01', recipients: ['future_self'], emotions: ['happy'], text: '你希望未来的自己还记得今天的哪一个瞬间？', priority: 12 },
  { id: 'future_happy_02', recipients: ['future_self'], emotions: ['happy'], text: '今天的哪份快乐，值得交给未来的你继续珍藏？', priority: 11 },
  { id: 'future_happy_03', recipients: ['future_self'], emotions: ['happy'], text: '如果未来的你读到这里，你希望他看见怎样的今天？', priority: 10 },
  { id: 'future_confused_01', recipients: ['future_self'], emotions: ['confused', 'sad'], text: '关于现在还没有答案的事，你想给未来的自己留下什么线索？', priority: 11 },
  { id: 'future_confused_02', recipients: ['future_self'], emotions: ['confused', 'sad'], text: '此刻最困住你的问题，想请未来的自己怎样回答？', priority: 10 },
  { id: 'future_regret_01', recipients: ['future_self'], emotions: ['regret'], text: '你希望未来的自己如何理解今天这份放不下？', priority: 11 },
  { id: 'friend_regret_01', recipients: ['friend', 'specific_person'], emotions: ['regret', 'sad'], text: '如果不需要解释你们为什么走远，你最想让对方知道什么？', priority: 12 },
  { id: 'friend_regret_02', recipients: ['friend', 'specific_person'], emotions: ['regret', 'sad'], text: '你们之间哪一个没有说完的瞬间，至今还留在心里？', priority: 11 },
  { id: 'friend_regret_03', recipients: ['friend', 'specific_person'], emotions: ['regret', 'sad'], text: '如果只保留一段共同记忆，你最舍不得忘记哪一段？', priority: 10 },
  { id: 'friend_angry_01', recipients: ['friend', 'specific_person'], emotions: ['angry'], text: '抛开体面和解释，你真正希望对方听懂的边界是什么？', priority: 12 },
  { id: 'friend_happy_01', recipients: ['friend', 'specific_person'], emotions: ['happy'], text: '最近哪件小事，让你第一时间想把快乐告诉这个人？', priority: 11 },
  { id: 'family_sad_01', recipients: ['family'], emotions: ['sad', 'regret'], text: '在这段关系里，哪一种感受一直没有被好好说出来？', priority: 10 },
  { id: 'family_sad_02', recipients: ['family'], emotions: ['sad', 'regret'], text: '如果暂时放下“应该”，你最希望家人理解你的哪一面？', priority: 11 },
  { id: 'family_angry_01', recipients: ['family'], emotions: ['angry'], text: '哪一次被忽略的感受，让你直到现在仍想认真说出来？', priority: 11 },
  { id: 'family_happy_01', recipients: ['family'], emotions: ['happy'], text: '有哪些平常没说出口的感谢，今天想写给家人？', priority: 10 },
  { id: 'unreachable_01', recipients: ['unreachable', 'past_relationship'], emotions: ['any'], text: '如果这封信不需要寄出，你最想把哪句话写完整？', priority: 11 },
  { id: 'unreachable_02', recipients: ['unreachable', 'past_relationship'], emotions: ['any'], text: '如果风真的能替你转交一句话，你希望它带走什么？', priority: 10 },
  { id: 'unreachable_03', recipients: ['unreachable', 'past_relationship'], emotions: ['any'], text: '不考虑回应，你想如何讲完这个一直停在心里的故事？', priority: 9 },
  { id: 'unreachable_04', recipients: ['unreachable', 'past_relationship'], emotions: ['any'], text: '你想把哪段记忆好好放回过去，又保留其中的什么？', priority: 8 },
  { id: 'self_calm_01', recipients: ['self'], emotions: ['calm', 'happy'], text: '今天发生了什么，让你想把这一刻留给自己？', priority: 10 },
  { id: 'self_calm_02', recipients: ['self'], emotions: ['calm', 'happy'], text: '此刻的你最想感谢自己坚持完成了什么？', priority: 9 },
  { id: 'self_happy_01', recipients: ['self'], emotions: ['happy'], text: '今天的你有哪些细小却真实的闪光，值得被记住？', priority: 11 },
  { id: 'self_heavy_01', recipients: ['self'], emotions: ['sad', 'angry', 'regret', 'confused'], text: '如果不需要向任何人解释，你现在最想承认的感受是什么？', priority: 12 },
  { id: 'self_heavy_02', recipients: ['self'], emotions: ['sad', 'angry', 'regret', 'confused'], text: '今天最消耗你的事情是什么，你希望怎样接住自己？', priority: 11 },
  { id: 'self_heavy_03', recipients: ['self'], emotions: ['sad', 'angry', 'regret', 'confused'], text: '如果可以对刚才的自己说一句话，你最想说什么？', priority: 10 },
  { id: 'emotion_regret_01', recipients: ['any'], emotions: ['regret'], text: '如果可以把那一刻重新说一遍，你最想补上哪句话？', priority: 8 },
  { id: 'emotion_regret_02', recipients: ['any'], emotions: ['regret'], text: '这份遗憾里，有什么其实不是你的错？', priority: 7 },
  { id: 'emotion_regret_03', recipients: ['any'], emotions: ['regret'], text: '你舍不得的是那个人、那件事，还是当时的自己？', priority: 7 },
  { id: 'emotion_angry_01', recipients: ['any'], emotions: ['angry'], text: '先不急着原谅或理解，真正让你难受的是什么？', priority: 8 },
  { id: 'emotion_angry_02', recipients: ['any'], emotions: ['angry'], text: '这份生气正在替你守住什么重要的东西？', priority: 7 },
  { id: 'emotion_angry_03', recipients: ['any'], emotions: ['angry'], text: '如果不用压住情绪，你想把哪条界限说清楚？', priority: 7 },
  { id: 'emotion_sad_01', recipients: ['any'], emotions: ['sad'], text: '此刻最希望被理解的那部分，是什么？', priority: 8 },
  { id: 'emotion_sad_02', recipients: ['any'], emotions: ['sad'], text: '这份难过从什么时候开始，又最需要怎样的陪伴？', priority: 7 },
  { id: 'emotion_sad_03', recipients: ['any'], emotions: ['sad'], text: '如果情绪能够说话，它此刻最想替你表达什么？', priority: 7 },
  { id: 'emotion_happy_01', recipients: ['any'], emotions: ['happy'], text: '如果要替今天保存一个画面，你会留下哪一幕？', priority: 8 },
  { id: 'emotion_happy_02', recipients: ['any'], emotions: ['happy'], text: '这份开心因为什么而来，你想把它分享给谁？', priority: 7 },
  { id: 'emotion_happy_03', recipients: ['any'], emotions: ['happy'], text: '今天有什么小小的幸运，让普通的一天变得不同？', priority: 7 },
  { id: 'emotion_confused_01', recipients: ['any'], emotions: ['confused'], text: '不必现在找到答案，先写下最让你犹豫的那件事。', priority: 8 },
  { id: 'emotion_confused_02', recipients: ['any'], emotions: ['confused'], text: '如果暂时不考虑结果，你真正想选择的方向是什么？', priority: 7 },
  { id: 'emotion_confused_03', recipients: ['any'], emotions: ['confused'], text: '现在有哪些声音混在一起，哪一个更像你自己的想法？', priority: 7 },
  { id: 'universal_01', recipients: ['any'], emotions: ['any'], text: '如果这封信不会被评价，你现在最想诚实写下什么？', priority: 1 },
  { id: 'universal_02', recipients: ['any'], emotions: ['any'], text: '不需要把故事讲完整，先写下最靠近此刻的一句话。', priority: 1 },
  { id: 'universal_03', recipients: ['any'], emotions: ['any'], text: '从“其实我一直想说”开始，把后面的句子交给自己。', priority: 1 },
  { id: 'universal_04', recipients: ['any'], emotions: ['any'], text: '如果只写三句话，你想留下事实、感受，还是愿望？', priority: 1 },
  { id: 'universal_05', recipients: ['any'], emotions: ['any'], text: '此刻反复出现在脑海里的画面，正在提醒你什么？', priority: 1 }
];

const RECIPIENT_RULES = [
  ['future_self', ['未来', '以后', '明年', '多年后', '五年后', '三年后']],
  ['self', ['自己', '此刻的我', '现在的我', '小时候的我']],
  ['family', ['妈妈', '母亲', '爸爸', '父亲', '家人', '姐姐', '哥哥', '弟弟', '妹妹', '爷爷', '奶奶']],
  ['friend', ['朋友', '同学', '室友', '闺蜜', '伙伴']],
  ['past_relationship', ['前任', '曾经喜欢', '走散', '没有告别', '离开的人']],
  ['unreachable', ['不会收到', '已故', '不在的人', '风', '过去']],
  ['specific_person', ['某个人', '那个人', 'ta']]
];

const EMOTION_RULES = [
  ['happy', ['开心', '快乐', '期待', '幸福', '轻松', '雀跃']],
  ['sad', ['伤心', '难过', '失落', '低落', '委屈', '想哭', '空空']],
  ['regret', ['遗憾', '后悔', '可惜', '放不下', '错过', '舍不得']],
  ['angry', ['生气', '愤怒', '烦躁', '不甘心', '恼火']],
  ['confused', ['迷茫', '困惑', '说不清', '复杂', '犹豫', '不知道']],
  ['calm', ['平静', '释然', '安稳', '放松']]
];

function cleanText(value, maxLength) {
  return String(value ?? '').replace(/[\u0000-\u001f]/g, ' ').trim().slice(0, maxLength);
}

function categoryFromPreset(preset, type) {
  if (type === 'recipient') {
    return ({ self: 'self', someone: 'specific_person', future: 'future_self', unknown: 'unreachable' })[preset] || '';
  }
  return ({ sad: 'sad', regret: 'regret', angry: 'angry', happy: 'happy', confused: 'confused' })[preset] || '';
}

function matchCategory(label, preset, rules, type) {
  const presetCategory = categoryFromPreset(preset, type);
  if (presetCategory) return { category: presetCategory, matchedBy: 'exact' };
  const normalized = cleanText(label, 80).toLowerCase();
  for (const [category, words] of rules) {
    if (words.some(word => normalized.includes(word))) {
      return { category, matchedBy: 'alias' };
    }
  }
  return { category: 'any', matchedBy: 'fallback' };
}

export function findPrompt(payload) {
  const recipient = matchCategory(payload.recipientLabel, payload.recipientPreset, RECIPIENT_RULES, 'recipient');
  const emotion = matchCategory(payload.emotionLabel, payload.emotionPreset, EMOTION_RULES, 'emotion');
  const excludedIds = new Set([
    ...(Array.isArray(payload.excludePromptIds) ? payload.excludePromptIds : []),
    payload.excludePromptId
  ].map(item => cleanText(item, 80)).filter(Boolean));
  const scored = PROMPTS
    .map(item => {
      const recipientExact = recipient.category !== 'any' && item.recipients.includes(recipient.category);
      const emotionExact = emotion.category !== 'any' && item.emotions.includes(emotion.category);
      const recipientAny = item.recipients.includes('any');
      const emotionAny = item.emotions.includes('any');
      const eligible = (recipientExact || recipientAny) && (emotionExact || emotionAny);
      const score = eligible ? item.priority + (recipientExact ? 20 : 0) + (emotionExact ? 20 : 0) : -1;
      return { item, score, recipientExact, emotionExact };
    })
    .filter(entry => entry.score >= 0)
    .sort((a, b) => b.score - a.score || a.item.id.localeCompare(b.item.id));

  const highestScore = scored.length > 0 ? scored[0].score : 0;
  const relevant = scored.filter(entry => entry.score >= highestScore - 6);
  const notRecentlyShown = relevant.filter(entry => !excludedIds.has(entry.item.id));
  const expandedFresh = scored.filter(entry => !excludedIds.has(entry.item.id));
  const expandedHighestScore = expandedFresh.length > 0 ? expandedFresh[0].score : 0;
  const nextRelevantTier = expandedFresh.filter(entry => entry.score >= expandedHighestScore - 6);
  const selectable = notRecentlyShown.length > 0
    ? notRecentlyShown
    : nextRelevantTier.length > 0 ? nextRelevantTier : relevant;
  const seedText = `${payload.recipientLabel}|${payload.emotionLabel}|${payload.variationSeed}|${excludedIds.size}`;
  const chosen = selectable.length > 0
    ? selectable[stableNumber(seedText) % selectable.length]
    : { item: PROMPTS[PROMPTS.length - 1], recipientExact: false, emotionExact: false };
  let matchedBy = 'fallback';
  if (chosen.recipientExact && chosen.emotionExact) matchedBy = recipient.matchedBy === 'exact' && emotion.matchedBy === 'exact' ? 'exact' : 'category';
  else if (chosen.recipientExact) matchedBy = 'recipient_only';
  else if (chosen.emotionExact) matchedBy = 'emotion_only';

  return {
    id: chosen.item.id,
    prompt: chosen.item.text,
    matchedBy,
    recipientCategory: recipient.category,
    emotionCategory: emotion.category
  };
}

const AFTERGLOW_TEMPLATES = {
  sad: [
    '这份难过被我看见了，也可以在这里慢慢变轻。',
    '我不再催自己振作，先陪这一刻安静地待一会儿。',
    '没有说完的委屈留在这里，我会继续照顾自己。',
    '今天的眼泪不是软弱，只是心在认真告别。',
    '我允许自己难过，也允许明天出现一点新的光。',
    '这阵雨落过心里，但不会带走完整的我。',
    '我先抱住没有力气的自己，不急着给出答案。',
    '被忽略的感受终于有了名字，也有了安放的位置。',
    '今夜可以慢一点，心会找到自己的呼吸。',
    '我把难过留成一束微光，而不是一道伤口。'
  ],
  regret: [
    '有些话没能抵达，但我的认真曾经真实存在。',
    '我记得那段同行，也接受故事停在这里。',
    '这份遗憾曾经很重，现在可以被轻轻放下。',
    '错过不需要被抹去，它会成为我走过的一段路。',
    '不能重来的那一刻，就让它在这里得到安放。',
    '没有抵达的愿望，也曾照亮过真实的我。',
    '我不再追问如果，只珍惜当时付出的真心。',
    '遗憾仍在，但我愿意把余下的路还给自己。',
    '那扇门已经关上，我会带着学会的事继续走。',
    '有些结局无法改写，却可以换一种方式被记得。'
  ],
  angry: [
    '我承认这份生气，也把属于别人的重量还回去。',
    '我的边界值得被听见，不必用沉默换取平静。',
    '这次我先站在自己身边，再决定要不要原谅。',
    '情绪可以停在这里，选择仍然握在我手中。',
    '我不否认受过的伤，也不让它定义以后的我。',
    '我把该说的边界写清楚，不再责怪自己的敏感。',
    '这份愤怒提醒我，有些委屈不必继续忍受。',
    '我可以不立刻和解，也可以先让自己安全。',
    '真正需要被保护的，是我没有说出口的感受。',
    '我让情绪经过，而不是让它替我做所有决定。'
  ],
  happy: [
    '这一刻值得被记住，往后想起时仍会有微光。',
    '我把今天的快乐收好，也把感谢留给此刻。',
    '原来平凡的一天，也可以拥有这样柔软的亮色。',
    '愿这份轻盈留在心里，陪我走过普通的日子。',
    '今天有一束光落在我身上，我认真地接住了它。',
    '我愿意相信，快乐不必宏大也值得被收藏。',
    '这一点小小的满足，足够让今天变得特别。',
    '我把笑意留在这里，等某个疲惫的日子再打开。',
    '此刻的温暖没有喧哗，却真实地照亮了我。',
    '我为今天的自己高兴，也期待下一次相遇。'
  ],
  confused: [
    '答案还没有出现，但我不必在今天把一切想明白。',
    '说不清也没有关系，我已经听见内心的犹豫。',
    '先把问题留在这里，方向会在行走中慢慢显现。',
    '我允许自己停一停，再选择真正想去的地方。',
    '迷雾还在，但我已经愿意为自己多等一会儿。',
    '还没想清楚，不代表我没有认真生活。',
    '我先听见自己的声音，再回应外界的期待。',
    '每一次犹豫，都在替我辨认真正重视的事。',
    '看不见远方时，我只走好眼前这一小步。',
    '我把未知留给时间，把此刻留给呼吸。'
  ],
  calm: [
    '这一页已经安静下来，我也可以轻轻向前。',
    '不用急着忘记，能够平静想起已经是一种抵达。',
    '我把故事放回过去，把此刻留给自己。',
    '心里的潮水慢慢退去，留下可以呼吸的岸。',
    '这件事仍然存在，却不再占据我的全部。',
    '我不再用力推开过去，只让它慢慢走远。',
    '能够平静地写下这些，已经是新的开始。',
    '心里空出了一点位置，可以放进新的日常。',
    '我与这段故事和解，也重新靠近真实的自己。',
    '此刻没有波澜，却有一种踏实的清醒。'
  ],
  any: [
    '这一刻被我认真看见，也可以被温柔地放下。',
    '有些答案来得很慢，我先把自己照顾好。',
    '故事留在这里，往后的路仍然可以慢慢走。',
    '不必把一切解释清楚，我已经听见自己的感受。',
    '我把这句话留作余光，提醒自己曾认真生活。',
    '今天的心事有了位置，我也多了一点空间。',
    '我允许故事暂时没有结尾，也允许自己先离开。',
    '这句话不替我下结论，只陪我看见当下。',
    '我把不能带走的留在这里，把能走的路留给明天。',
    '有些心情无需命名，也值得被温柔收下。'
  ]
};

const AFTERGLOW_ECHOES = {
  sad: '你没有否认难过，只是开始把自己接回身边。',
  regret: '遗憾被好好安放以后，也会成为走过的证明。',
  angry: '你听见了自己的边界，也保留了重新选择的力量。',
  happy: '你接住了这一刻的明亮，让它成为日后的回声。',
  confused: '没有答案也能继续生活，停顿本身也是一种整理。',
  calm: '故事没有消失，只是不再需要反复证明什么。',
  any: '你认真看见了这一刻，也给自己留出了继续前行的位置。'
};

function stableNumber(value) {
  let total = 0;
  for (const character of String(value ?? '')) total = (total * 31 + character.codePointAt(0)) >>> 0;
  return total;
}

export function generateAfterglow(payload) {
  const recipient = matchCategory(payload.recipient, payload.recipientPreset, RECIPIENT_RULES, 'recipient');
  const emotion = matchCategory(payload.emotion, payload.emotionPreset, EMOTION_RULES, 'emotion');
  const emotionCategory = emotion.category === 'any' ? 'any' : emotion.category;
  const pool = AFTERGLOW_TEMPLATES[emotionCategory] || AFTERGLOW_TEMPLATES.any;
  const excludedCandidates = new Set(
    (Array.isArray(payload.excludeCandidates) ? payload.excludeCandidates : [])
      .map(item => cleanText(item, 50))
      .filter(Boolean)
  );
  const freshPool = pool.filter(item => !excludedCandidates.has(item));
  const selectablePool = freshPool.length >= 3 ? freshPool : pool;
  const seedText = `${payload.recipient}|${payload.emotion}|${payload.title}|${payload.variationSeed}`;
  const offset = stableNumber(seedText) % selectablePool.length;
  const candidates = [
    selectablePool[offset],
    selectablePool[(offset + 1) % selectablePool.length],
    selectablePool[(offset + 2) % selectablePool.length]
  ];
  const emotionLabel = cleanText(payload.emotion, 6) || '此刻';
  const recipientKeyword = recipient.category === 'future_self' ? '未来'
    : recipient.category === 'friend' ? '同行'
      : recipient.category === 'family' ? '家人'
        : recipient.category === 'self' ? '自己' : '心事';
  return {
    requestId: `rule_${Date.now()}_${offset}`,
    candidates,
    keywords: [...new Set([emotionLabel, recipientKeyword, '余光'])].slice(0, 4),
    echo: AFTERGLOW_ECHOES[emotionCategory] || AFTERGLOW_ECHOES.any,
    engine: 'template-v1'
  };
}

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
  });
  response.end(body);
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw Object.assign(new Error('BODY_TOO_LARGE'), { statusCode: 413 });
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

export function createServer() {
  return http.createServer(async (request, response) => {
    try {
      if (request.method === 'OPTIONS') return sendJson(response, 204, {});
      if (request.method === 'GET' && request.url === '/health') {
        return sendJson(response, 200, { success: true, data: { status: 'ok', afterglowEngine: 'template-v1' } });
      }
      if (request.method === 'POST' && request.url === '/api/v1/prompts/match') {
        const payload = await readJson(request);
        return sendJson(response, 200, { success: true, data: findPrompt(payload) });
      }
      if (request.method === 'POST' && request.url === '/api/v1/afterglow') {
        const payload = await readJson(request);
        const data = await generateAfterglow(payload);
        return sendJson(response, 200, { success: true, data });
      }
      return sendJson(response, 404, { success: false, message: 'NOT_FOUND' });
    } catch (error) {
      const status = Number(error?.statusCode || (error instanceof SyntaxError ? 400 : 500));
      const message = status >= 500 ? (error?.message || 'SERVER_ERROR') : error.message;
      return sendJson(response, status, { success: false, message });
    }
  });
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replaceAll('\\', '/'))) {
  createServer().listen(PORT, '0.0.0.0', () => {
    console.log(`weiyu remote writing service listening on http://0.0.0.0:${PORT}`);
  });
}

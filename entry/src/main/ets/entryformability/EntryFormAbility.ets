import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import BuildProfile from 'BuildProfile';

interface CardLetterRecord {
  id: number;
  title?: string;
  date: string;
  emotion: string;
  ritual: string;
  content: string;
  echoLine?: string;
  afterglow?: string;
  unlockAt?: number;
  driftStartedAt?: number;
  driftTideAt?: number;
}

interface CardStoredLetterState {
  echoCards?: Array<CardLetterRecord>;
  futureLetters?: Array<CardLetterRecord>;
  driftLetters?: Array<CardLetterRecord>;
  collectedSparkIds?: Array<number>;
}

interface LetterCardData {
  hasLetter: boolean;
  date: string;
  emotionAndRitual: string;
  eyebrow: string;
  headline: string;
  content: string;
  actionLabel: string;
  target: string;
}

export default class EntryFormAbility extends FormExtensionAbility {
  private readonly storeName: string = 'weiyu_letter_store';
  private readonly storeKey: string = 'letters_payload';
  private readonly formIdsKey: string = 'letter_form_ids';
  private readonly previewSceneKey: string = 'service_card_preview_scene';
  private readonly dayDuration: number = 24 * 60 * 60 * 1000;

  private getStore(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context, { name: this.storeName });
  }

  private compactText(value: string | undefined, fallback: string, limit: number): string {
    const source: string = (value ?? '').replace(/\s+/g, ' ').trim();
    const text: string = source.length > 0 ? source : fallback;
    return text.length > limit ? `${text.slice(0, limit)}…` : text;
  }

  private getRecordTimestamp(record: CardLetterRecord): number {
    const parts: Array<string> = record.date.split('.');
    if (parts.length !== 3) {
      return 0;
    }
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])).getTime();
  }

  private getTodayLabel(): string {
    const now: Date = new Date();
    return `${now.getMonth() + 1}月${now.getDate()}日`;
  }

  private createWritingPrompt(): LetterCardData {
    const hour: number = new Date().getHours();
    if (hour < 11) {
      return {
        hasLetter: false,
        date: this.getTodayLabel(),
        emotionAndRitual: '晨间片刻',
        eyebrow: '早安，今天也慢慢来',
        headline: '给今天留一句话',
        content: '不必写得完整，从醒来后的第一个感受开始。',
        actionLabel: '写下此刻',
        target: 'write'
      };
    }
    if (hour < 18) {
      return {
        hasLetter: false,
        date: this.getTodayLabel(),
        emotionAndRitual: '片刻停靠',
        eyebrow: '给忙碌按一次暂停',
        headline: '现在的你，还好吗？',
        content: '用一句话，把此刻从忙碌里轻轻取出来。',
        actionLabel: '写下此刻',
        target: 'write'
      };
    }
    return {
      hasLetter: false,
      date: this.getTodayLabel(),
      emotionAndRitual: '夜晚留白',
      eyebrow: '今晚，留一点空白',
      headline: '有些话，写下来就会轻一点',
      content: '不用急着想明白，先写下最想说的那一句。',
      actionLabel: '写下此刻',
      target: 'write'
    };
  }

  private createPreviewCard(scene: string): LetterCardData {
    if (scene === 'morning') {
      return {
        hasLetter: false, date: '今天', emotionAndRitual: '晨间片刻', eyebrow: '早安，今天也慢慢来',
        headline: '给今天留一句话', content: '不必写得完整，从醒来后的第一个感受开始。',
        actionLabel: '写下此刻', target: 'cardPreview'
      };
    }
    if (scene === 'evening') {
      return {
        hasLetter: false, date: '今晚', emotionAndRitual: '夜晚留白', eyebrow: '今晚，留一点空白',
        headline: '有些话，写下来就会轻一点', content: '不用急着想明白，先写下最想说的那一句。',
        actionLabel: '写下此刻', target: 'cardPreview'
      };
    }
    if (scene === 'future') {
      return {
        hasLetter: true, date: '刚刚', emotionAndRitual: '平静 · 未来信', eyebrow: '未来信刚刚抵达',
        headline: '未来的你，有一封信到了', content: '那天留给未来的话，现在可以打开了。',
        actionLabel: '现在打开', target: 'cardPreview'
      };
    }
    if (scene === 'driftReturned') {
      return {
        hasLetter: true, date: '今天', emotionAndRitual: '释然 · 近岸轻漂', eyebrow: '海风把它送回岸边',
        headline: '那封漂流的信，想回来见你', content: '它已经靠岸，等你决定要不要重新打开。',
        actionLabel: '去岸边看看', target: 'cardPreview'
      };
    }
    if (scene === 'sparkPending') {
      return {
        hasLetter: true, date: '昨夜', emotionAndRitual: '遗憾 · 微光', eyebrow: '有一束光还没被收下',
        headline: '把这点微光，留给往后的自己', content: '愿那些没有说完的话，也能被温柔照亮。',
        actionLabel: '收下这束光', target: 'cardPreview'
      };
    }
    if (scene === 'driftFollowup') {
      return {
        hasLetter: true, date: '漂流第 2 天', emotionAndRitual: '迷茫 · 漂流中', eyebrow: '海风仍在替你保管',
        headline: '写完以后，现在好一点了吗？', content: '那件心事还在慢慢漂流，你可以靠近看看。',
        actionLabel: '靠近看看', target: 'cardPreview'
      };
    }
    if (scene === 'letterFollowup') {
      return {
        hasLetter: true, date: '3 天前', emotionAndRitual: '难过 · 温柔回访', eyebrow: '给那天的自己一声回应',
        headline: '写完那封信以后，现在怎么样？', content: '难过的那一天，已经过去了一点时间。',
        actionLabel: '回去看看', target: 'cardPreview'
      };
    }
    return {
      hasLetter: false, date: '今天', emotionAndRitual: '片刻停靠', eyebrow: '给忙碌按一次暂停',
      headline: '现在的你，还好吗？', content: '用一句话，把此刻从忙碌里轻轻取出来。',
      actionLabel: '写下此刻', target: 'cardPreview'
    };
  }

  private createRecommendedCard(state: CardStoredLetterState): LetterCardData {
    const now: number = Date.now();
    const futureLetters: Array<CardLetterRecord> = state.futureLetters ?? [];
    const driftLetters: Array<CardLetterRecord> = state.driftLetters ?? [];
    const echoCards: Array<CardLetterRecord> = state.echoCards ?? [];
    const collectedSparkIds: Array<number> = state.collectedSparkIds ?? [];

    let unlockedFuture: CardLetterRecord | undefined = undefined;
    let index: number = 0;
    while (index < futureLetters.length) {
      const letter: CardLetterRecord = futureLetters[index];
      const unlockAt: number = letter.unlockAt ?? 0;
      if (unlockAt > 0 && unlockAt <= now && now - unlockAt <= this.dayDuration * 3 &&
        (unlockedFuture === undefined || unlockAt > (unlockedFuture.unlockAt ?? 0))) {
        unlockedFuture = letter;
      }
      index += 1;
    }
    if (unlockedFuture !== undefined) {
      return {
        hasLetter: true,
        date: unlockedFuture.date,
        emotionAndRitual: `${unlockedFuture.emotion} · 未来信`,
        eyebrow: '未来信刚刚抵达',
        headline: '未来的你，有一封信到了',
        content: this.compactText(unlockedFuture.title, '那天留给未来的话，现在可以打开了。', 42),
        actionLabel: '现在打开',
        target: `letter:${unlockedFuture.id}`
      };
    }

    let returnedDrift: CardLetterRecord | undefined = undefined;
    index = 0;
    while (index < driftLetters.length) {
      const letter: CardLetterRecord = driftLetters[index];
      const tideAt: number = letter.driftTideAt ?? 0;
      if (tideAt > 0 && tideAt <= now &&
        (returnedDrift === undefined || tideAt > (returnedDrift.driftTideAt ?? 0))) {
        returnedDrift = letter;
      }
      index += 1;
    }
    if (returnedDrift !== undefined) {
      return {
        hasLetter: true,
        date: returnedDrift.date,
        emotionAndRitual: `${returnedDrift.emotion} · 近岸轻漂`,
        eyebrow: '海风把它送回岸边',
        headline: '那封漂流的信，想回来见你',
        content: '它已经靠岸，等你决定要不要重新打开。',
        actionLabel: '去岸边看看',
        target: `letter:${returnedDrift.id}`
      };
    }

    let pendingSpark: CardLetterRecord | undefined = undefined;
    index = 0;
    while (index < echoCards.length) {
      const letter: CardLetterRecord = echoCards[index];
      if (letter.ritual === '燃成光点' && collectedSparkIds.indexOf(letter.id) === -1) {
        pendingSpark = letter;
        break;
      }
      index += 1;
    }
    if (pendingSpark !== undefined) {
      return {
        hasLetter: true,
        date: pendingSpark.date,
        emotionAndRitual: `${pendingSpark.emotion} · 微光`,
        eyebrow: '有一束光还没被收下',
        headline: '把这点微光，留给往后的自己',
        content: this.compactText(pendingSpark.afterglow,
          this.compactText(pendingSpark.echoLine, '这一刻的心情，已经化作一束光。', 42), 42),
        actionLabel: '收下这束光',
        target: `letter:${pendingSpark.id}`
      };
    }

    let driftingLetter: CardLetterRecord | undefined = undefined;
    index = 0;
    while (index < driftLetters.length) {
      const letter: CardLetterRecord = driftLetters[index];
      const startedAt: number = letter.driftStartedAt ?? 0;
      if (startedAt > 0 && now - startedAt >= this.dayDuration &&
        (driftingLetter === undefined || startedAt > (driftingLetter.driftStartedAt ?? 0))) {
        driftingLetter = letter;
      }
      index += 1;
    }
    if (driftingLetter !== undefined) {
      return {
        hasLetter: true,
        date: driftingLetter.date,
        emotionAndRitual: `${driftingLetter.emotion} · 漂流中`,
        eyebrow: '海风仍在替你保管',
        headline: '写完以后，现在好一点了吗？',
        content: '那件心事还在慢慢漂流，你可以靠近看看。',
        actionLabel: '靠近看看',
        target: `letter:${driftingLetter.id}`
      };
    }

    let recentLetter: CardLetterRecord | undefined = undefined;
    let recentTimestamp: number = 0;
    index = 0;
    while (index < echoCards.length) {
      const letter: CardLetterRecord = echoCards[index];
      const timestamp: number = this.getRecordTimestamp(letter);
      if (timestamp > 0 && now - timestamp >= this.dayDuration && now - timestamp <= this.dayDuration * 7 &&
        timestamp > recentTimestamp) {
        recentLetter = letter;
        recentTimestamp = timestamp;
      }
      index += 1;
    }
    if (recentLetter !== undefined) {
      return {
        hasLetter: true,
        date: recentLetter.date,
        emotionAndRitual: `${recentLetter.emotion} · 温柔回访`,
        eyebrow: '给那天的自己一声回应',
        headline: '写完那封信以后，现在怎么样？',
        content: this.compactText(recentLetter.title, `${recentLetter.emotion}的那一天，已经过去了一点时间。`, 42),
        actionLabel: '回去看看',
        target: `letter:${recentLetter.id}`
      };
    }

    return this.createWritingPrompt();
  }

  private createCardData(): LetterCardData {
    const store: preferences.Preferences = this.getStore();
    if (BuildProfile.DEBUG) {
      const previewScene: string = store.getSync(this.previewSceneKey, 'auto') as string;
      if (previewScene !== 'auto') {
        return this.createPreviewCard(previewScene);
      }
    }
    const rawValue: string = store.getSync(this.storeKey, '') as string;
    if (rawValue.length > 0) {
      try {
        const state: CardStoredLetterState = JSON.parse(rawValue) as CardStoredLetterState;
        return this.createRecommendedCard(state);
      } catch (_err) {
      }
    }
    return this.createWritingPrompt();
  }

  private saveFormId(formId: string): void {
    const store: preferences.Preferences = this.getStore();
    const rawIds: string = store.getSync(this.formIdsKey, '[]') as string;
    let ids: Array<string> = [];
    try {
      ids = JSON.parse(rawIds) as Array<string>;
    } catch (_err) {
    }
    if (!ids.includes(formId)) {
      ids.push(formId);
      store.putSync(this.formIdsKey, JSON.stringify(ids));
      store.flush().catch((_err: BusinessError) => {
      });
    }
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = `${want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? ''}`;
    if (formId.length > 0) {
      this.saveFormId(formId);
    }
    return formBindingData.createFormBindingData(this.createCardData());
  }

  onUpdateForm(formId: string): void {
    const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(this.createCardData());
    formProvider.updateForm(formId, data).catch((_err: BusinessError) => {
    });
  }

  onRemoveForm(formId: string): void {
    const store: preferences.Preferences = this.getStore();
    const rawIds: string = store.getSync(this.formIdsKey, '[]') as string;
    let ids: Array<string> = [];
    try {
      ids = JSON.parse(rawIds) as Array<string>;
    } catch (_err) {
    }
    ids = ids.filter((id: string) => id !== formId);
    store.putSync(this.formIdsKey, JSON.stringify(ids));
    store.flush().catch((_err: BusinessError) => {
    });
  }
}

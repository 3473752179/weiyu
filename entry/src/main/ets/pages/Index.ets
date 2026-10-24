import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { WeiyuTheme } from '../theme/WeiyuTheme';

interface SelectItem {
  id: string;
  title: string;
  subtitle: string;
  emoji: string;
  color: string;
}

interface LetterRecord {
  id: number;
  title: string;
  date: string;
  weekday: string;
  recipient: string;
  recipientHint: string;
  emotion: string;
  emotionHint: string;
  ritual: string;
  ritualHint: string;
  content: string;
  keywords: Array<string>;
  echoLine: string;
  afterglow?: string;
  moodTag: string;
  anonymous: boolean;
  unlockDate: string;
  unlockAt: number;
  reminderId: number;
  photoUris: Array<string>;
  driftStartedAt: number;
  driftTideAt?: number;
  driftMoodNow?: string;
}

interface StoredLetterState {
  drafts: Array<LetterRecord>;
  sealedLetters: Array<LetterRecord>;
  futureLetters: Array<LetterRecord>;
  driftLetters: Array<LetterRecord>;
  echoCards: Array<LetterRecord>;
  nextId: number;
  activeEchoId: number;
  collectedSparkIds: Array<number>;
}

interface ServiceCardData {
  hasLetter: boolean;
  date: string;
  emotionAndRitual: string;
  content: string;
  target: string;
}

@Entry
@Component
struct Index {
  private readonly recipientOptions: Array<SelectItem> = [
    { id: 'self', title: '写给自己', subtitle: '给此刻的自己一点温柔', emoji: '🪞', color: '#F4EEE5' },
    { id: 'someone', title: '写给某个人', subtitle: '给那个TA，说说心里话', emoji: '💌', color: '#F7F1E6' },
    { id: 'future', title: '写给未来的自己', subtitle: '给未来的自己一句话', emoji: '📅', color: '#F5EFE7' },
    { id: 'unknown', title: '写给不会收到的人', subtitle: '有些话，只想说给风听', emoji: '·', color: '#EEF3F7' },
    { id: 'custom', title: '写给自定义对象', subtitle: '想写给谁，都可以由你自己定义', emoji: '✍️', color: '#F3ECE6' }
  ];

  private readonly emotionOptions: Array<SelectItem> = [
    { id: 'sad', title: '伤心', subtitle: '眼眶有点酸酸的', emoji: '☁️', color: '#DDE6F2' },
    { id: 'regret', title: '遗憾', subtitle: '有些错过，还是记得', emoji: '🌙', color: '#E6E1F0' },
    { id: 'angry', title: '生气', subtitle: '一时的情绪，需要出口', emoji: '🌤', color: '#F7DAD4' },
    { id: 'happy', title: '开心', subtitle: '想把快乐偷偷记下来', emoji: '✨', color: '#F7E7C9' },
    { id: 'confused', title: '迷茫', subtitle: '有点乱，也有点不确定', emoji: '🍃', color: '#E8E8EA' },
    { id: 'other', title: '其他', subtitle: '说不清，也可以慢慢写', emoji: '🌿', color: '#E5EEE5' }
  ];

  private readonly ritualOptions: Array<SelectItem> = [
    { id: 'seal', title: '封存', subtitle: '把信放进时光盒，让它暂时被照顾', emoji: '📦', color: '#F4EDE4' },
    { id: 'spark', title: '燃成光点', subtitle: '让文字化成星光，轻轻照亮情绪', emoji: '✨', color: '#F9ECD8' },
    { id: 'drift', title: '漂流', subtitle: '把信交给海风，想看时随时捞起', emoji: '🌊', color: '#EAF0F6' },
    { id: 'future', title: '寄给未来', subtitle: '把愿望留给未来的自己开启', emoji: '🗓', color: '#F4EEE4' }
  ];
  private readonly letterStoreName: string = 'weiyu_letter_store';
  private readonly letterStoreKey: string = 'letters_payload';
  private readonly futureReminderHour: number = 9;
  private readonly appBundleName: string = 'com.example.weiyu';

  @State private currentPage: string = 'home';
  @StorageLink('cardTarget') @Watch('onCardTargetChanged') private cardTarget: string = '';
  @State private homeTab: number = 0;
  @State private echoTimeFilter: string = 'all';
  @State private archiveKind: string = 'draft';
  @State private archiveReturnPage: string = 'home';
  @State private selectedRecipientIndex: number = -1;
  @State private selectedEmotionIndex: number = -1;
  @State private customRecipient: string = '';
  @State private customEmotion: string = '';
  @State private emotionConfirmLabel: string = '是什么呢';
  @State private letterTitle: string = '';
  @State private letterContent: string = '';
  @State private sparkAfterglow: string = '';
  @State private photoUris: Array<string> = [];
  @State private moodTag: string = '私语';
  @State private isAnonymous: boolean = false;
  @State private statusText: string = '把想说的话，先留在这里。';
  @State private initialized: boolean = false;
  @State private nextId: number = 3;
  @State private drafts: Array<LetterRecord> = [];
  @State private sealedLetters: Array<LetterRecord> = [];
  @State private futureLetters: Array<LetterRecord> = [];
  @State private driftLetters: Array<LetterRecord> = [];
  @State private echoCards: Array<LetterRecord> = [];
  @State private activeEchoId: number = 2;
  @State private collectedSparkIds: Array<number> = [];
  @State private selectedSparkId: number = -1;
  @State private selectedSparkGlowScale: number = 1;
  @State private selectedSparkGlowOpacity: number = 0.44;
  @State private collectingSpark: boolean = false;
  @State private sparkScale: number = 1;
  @State private sparkOpacity: number = 1;
  @State private driftPeek: boolean = false;
  @State private driftMoodIndex: number = -1;
  @State private driftCustomMood: string = '';
  @State private driftDetailEntryOffset: number = 18;
  @State private driftDetailEntryOpacity: number = 0;
  @State private initialDriftReceipt: boolean = false;
  @State private contentReturnPage: string = 'home';
  @State private driftLaunching: boolean = false;
  @State private driftBottleOffset: number = 0;
  @State private driftBottleScale: number = 1;
  @State private driftBottleOpacity: number = 1;
  @State private driftReflection: string = '';
  @State private writingReturnPage: string = 'emotion';
  private recalledDriftOrigin: LetterRecord | undefined = undefined;
  @State private driftFloatY: number = 4;
  @State private driftFloatAngle: number = 2;
  private driftMotionTimer: number = -1;
  @State private driftHedgehogFrameIndex: number = 0;
  private driftHedgehogFrameTimer: number = -1;
  @State private openedMenuId: number = -1;
  @State private homeEntryOffset: number = 18;
  @State private homeEntryOpacity: number = 0;
  @State private recentEntryOffset: number = 18;
  @State private recentEntryOpacity: number = 0;
  @State private recipientPageOffset: number = 480;
  private recipientPageLeaving: boolean = false;
  private recipientEntryFromHome: boolean = false;
  @State private emotionEntryOffset: number = 18;
  @State private emotionEntryOpacity: number = 0;
  @State private ritualEntryOffset: number = 18;
  @State private ritualEntryOpacity: number = 0;
  @State private confusedEmotionFrameIndex: number = 0;
  private confusedEmotionTimer: number = -1;
  @State private regretEmotionFrameIndex: number = 0;
  private regretEmotionTimer: number = -1;
  @State private angryEmotionFrameIndex: number = 0;
  private angryEmotionTimer: number = -1;
  @State private sadEmotionFrameIndex: number = 0;
  private sadEmotionTimer: number = -1;
  @State private happyEmotionFrameIndex: number = 0;
  private happyEmotionTimer: number = -1;
  @State private futureReminderDate: Date = new Date(Date.now() + 24 * 60 * 60 * 1000);
  @State private futureNotificationEnabled: boolean = false;
  @State private unlockWatcherNow: number = Date.now();
  private unlockWatcherTimer: number = -1;

  aboutToAppear(): void {
    this.startUnlockWatcher();
    this.refreshNotificationPermissionStatus();
    if (this.initialized) {
      this.handleCardTarget();
      return;
    }

    if (this.restoreStoredLetters()) {
      this.initialized = true;
      this.handleCardTarget();
      return;
    }

    const draft: LetterRecord = {
      id: 1,
      title: '给今天的自己',
      date: '2026.07.18',
      weekday: '星期六',
      recipient: '写给自己',
      recipientHint: '给此刻的自己一点温柔',
      emotion: '开心',
      emotionHint: '想把快乐偷偷记下来',
      ritual: '草稿',
      ritualHint: '暂时留在这里，等你准备好再继续',
      content: '谢谢那个没有放弃自己的我，今天也比昨天更勇敢了一点。',
      keywords: ['感谢', '勇敢', '今天'],
      echoLine: '先把这段话温柔地留给自己。',
      moodTag: '心语',
      anonymous: false,
      unlockDate: '',
      unlockAt: 0,
      reminderId: 0,
      photoUris: [],
      driftStartedAt: 0
    };
    const echo: LetterRecord = {
      id: 2,
      title: '没有寄出的想念',
      date: '2026.07.19',
      weekday: '星期日',
      recipient: '写给不会收到的人',
      recipientHint: '有些话，只想轻轻地说',
      emotion: '遗憾',
      emotionHint: '有些错过，还是记得',
      ritual: '封存',
      ritualHint: '把信放进时光盒，让它暂时被照顾',
      content: '我没有打扰你，但我认真想过你。',
      keywords: ['想念', '晚风', '拥抱'],
      echoLine: '这句话已经被好好收下了。',
      moodTag: '想念',
      anonymous: true,
      unlockDate: '',
      unlockAt: 0,
      reminderId: 0,
      photoUris: [],
      driftStartedAt: 0
    };

    this.drafts = [draft];
    this.sealedLetters = [echo];
    this.echoCards = [echo];
    this.activeEchoId = echo.id;
    this.persistLetters();
    this.initialized = true;
    this.handleCardTarget();
  }

  aboutToDisappear(): void {
    this.stopAllEmotionAnimations();
    this.stopUnlockWatcher();
    this.stopDriftMotion();
    this.stopDriftHedgehogAnimation();
  }

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private getLetterStore(): preferences.Preferences | null {
    try {
      return preferences.getPreferencesSync(this.getAbilityContext(), { name: this.letterStoreName });
    } catch (_err) {
      return null;
    }
  }

  private normalizeRecord(record: LetterRecord): LetterRecord {
    return {
      id: record.id,
      title: record.title ?? '',
      date: record.date,
      weekday: record.weekday,
      recipient: record.recipient,
      recipientHint: record.recipientHint,
      emotion: record.emotion,
      emotionHint: record.emotionHint,
      ritual: record.ritual,
      ritualHint: record.ritualHint,
      content: record.content,
      keywords: record.keywords,
      echoLine: record.echoLine,
      afterglow: record.afterglow ?? '',
      moodTag: record.moodTag,
      anonymous: record.anonymous,
      unlockDate: record.unlockDate ?? '',
      unlockAt: record.unlockAt ?? 0,
      reminderId: record.reminderId ?? 0,
      photoUris: record.photoUris ?? [],
      driftStartedAt: record.driftStartedAt ?? 0,
      driftTideAt: record.driftTideAt ?? ((record.driftStartedAt ?? 0) + 7 * 24 * 60 * 60 * 1000),
      driftMoodNow: record.driftMoodNow ?? ''
    };
  }

  private restoreStoredLetters(): boolean {
    const store: preferences.Preferences | null = this.getLetterStore();
    if (store === null) {
      return false;
    }
    const rawValue: string = store.getSync(this.letterStoreKey, '') as string;
    if (rawValue.length === 0) {
      return false;
    }
    try {
      const saved: StoredLetterState = JSON.parse(rawValue) as StoredLetterState;
      this.drafts = (saved.drafts ?? []).map((item: LetterRecord) => this.normalizeRecord(item));
      this.sealedLetters = (saved.sealedLetters ?? []).map((item: LetterRecord) => this.normalizeRecord(item));
      this.futureLetters = (saved.futureLetters ?? []).map((item: LetterRecord) => this.normalizeRecord(item));
      this.driftLetters = (saved.driftLetters ?? []).map((item: LetterRecord) => this.normalizeRecord(item));
      this.echoCards = (saved.echoCards ?? []).map((item: LetterRecord) => this.normalizeRecord(item));
      this.collectedSparkIds = saved.collectedSparkIds ?? [];
      this.nextId = saved.nextId > 0 ? saved.nextId : this.getComputedNextId();
      if (this.echoCards.length > 0) {
        this.activeEchoId = this.containsRecordId(this.echoCards, saved.activeEchoId) ? saved.activeEchoId : this.echoCards[0].id;
      } else {
        this.activeEchoId = -1;
      }
      return true;
    } catch (_err) {
      return false;
    }
  }

  private persistLetters(): void {
    const store: preferences.Preferences | null = this.getLetterStore();
    if (store === null) {
      return;
    }
    const snapshot: StoredLetterState = {
      drafts: this.drafts,
      sealedLetters: this.sealedLetters,
      futureLetters: this.futureLetters,
      driftLetters: this.driftLetters,
      echoCards: this.echoCards,
      nextId: this.nextId,
      activeEchoId: this.activeEchoId,
      collectedSparkIds: this.collectedSparkIds
    };
    store.putSync(this.letterStoreKey, JSON.stringify(snapshot));
    store.flush()
      .then(() => {
        this.refreshServiceCards();
      })
      .catch((_err: BusinessError) => {
      });
  }

  private refreshServiceCards(): void {
    const store: preferences.Preferences | null = this.getLetterStore();
    if (store === null) {
      return;
    }
    const rawIds: string = store.getSync('letter_form_ids', '[]') as string;
    let formIds: Array<string> = [];
    try {
      formIds = JSON.parse(rawIds) as Array<string>;
    } catch (_err) {
      return;
    }
    if (formIds.length === 0) {
      return;
    }

    let data: ServiceCardData = {
      hasLetter: false,
      date: '微语',
      emotionAndRitual: '给此刻留一点空间',
      content: '最近，有没有什么想写下来的？',
      target: 'write'
    };
    if (this.echoCards.length > 0) {
      const letter: LetterRecord = this.echoCards[0];
      data = {
        hasLetter: true,
        date: letter.date,
        emotionAndRitual: `${letter.emotion} · ${letter.ritual}`,
        content: letter.ritual === '漂流' ? this.getDriftSafeLine(letter) : (letter.ritual === '燃成光点' ? letter.echoLine : this.createSoftExcerpt(letter.content, 46)),
        target: `letter:${letter.id}`
      };
    }
    const cardData: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
    formIds.forEach((formId: string) => {
      formProvider.updateForm(formId, cardData).catch((_err: BusinessError) => {
      });
    });
  }

  private onCardTargetChanged(): void {
    this.handleCardTarget();
  }

  private handleCardTarget(): void {
    if (!this.initialized || this.cardTarget.length === 0) {
      return;
    }
    const target: string = this.cardTarget;
    this.cardTarget = '';
    if (target === 'write') {
      this.openComposer();
      return;
    }
    if (target.startsWith('letter:')) {
      const targetId: number = Number(target.slice(7));
      let index: number = 0;
      while (index < this.echoCards.length) {
        if (this.echoCards[index].id === targetId) {
          this.enterEcho(this.echoCards[index]);
          return;
        }
        index += 1;
      }
      this.currentPage = 'home';
      this.homeTab = 0;
    }
  }

  private containsRecordId(items: Array<LetterRecord>, targetId: number): boolean {
    let index: number = 0;
    while (index < items.length) {
      if (items[index].id === targetId) {
        return true;
      }
      index += 1;
    }
    return false;
  }

  private getComputedNextId(): number {
    let maxId: number = 0;
    const sources: Array<Array<LetterRecord>> = [this.drafts, this.sealedLetters, this.futureLetters, this.driftLetters, this.echoCards];
    sources.forEach((items: Array<LetterRecord>) => {
      items.forEach((item: LetterRecord) => {
        if (item.id > maxId) {
          maxId = item.id;
        }
      });
    });
    return maxId + 1;
  }

  private getSelectedRecipient(): SelectItem {
    if (this.selectedRecipientIndex < 0) {
      return this.recipientOptions[0];
    }
    if (this.recipientOptions[this.selectedRecipientIndex].id === 'custom' && this.customRecipient.trim().length > 0) {
      return {
        id: 'custom',
        title: `写给${this.customRecipient.trim()}`,
        subtitle: '这是你亲手写下的收信人',
        emoji: '✍️',
        color: '#F3ECE6'
      };
    }
    return this.recipientOptions[this.selectedRecipientIndex];
  }

  private getSelectedEmotion(): SelectItem {
    if (this.selectedEmotionIndex < 0) {
      return this.emotionOptions[0];
    }
    if (this.emotionOptions[this.selectedEmotionIndex].id === 'other' && this.customEmotion.trim().length > 0) {
      return {
        id: 'other',
        title: this.customEmotion.trim(),
        subtitle: '这是你为此刻亲手写下的心情',
        emoji: '🌿',
        color: '#E5EEE5'
      };
    }
    return this.emotionOptions[this.selectedEmotionIndex];
  }

  private getActiveEcho(): LetterRecord {
    let index: number = 0;
    while (index < this.echoCards.length) {
      if (this.echoCards[index].id === this.activeEchoId) {
        return this.echoCards[index];
      }
      index += 1;
    }
    if (this.recalledDriftOrigin && this.recalledDriftOrigin.id === this.activeEchoId) {
      return this.recalledDriftOrigin;
    }
    return this.echoCards[0];
  }

  private getEmotionCover(emotion: string): Resource {
    switch (emotion) {
      case '开心':
        return $r('app.media.emotion_cover_happy');
      case '迷茫':
        return $r('app.media.emotion_cover_confused');
      case '伤心':
        return $r('app.media.emotion_cover_sad');
      case '生气':
        return $r('app.media.emotion_cover_angry');
      case '遗憾':
        return $r('app.media.emotion_cover_regret');
      default:
        return $r('app.media.emotion_cover_normal');
    }
  }

  private stopAllEmotionAnimations(): void {
    this.stopConfusedEmotionAnimation();
    this.stopRegretEmotionAnimation();
    this.stopAngryEmotionAnimation();
    this.stopSadEmotionAnimation();
    this.stopHappyEmotionAnimation();
  }

  private startUnlockWatcher(): void {
    this.unlockWatcherNow = Date.now();
    if (this.unlockWatcherTimer !== -1) {
      return;
    }
    this.unlockWatcherTimer = setInterval(() => {
      this.unlockWatcherNow = Date.now();
    }, 30000) as number;
  }

  private stopUnlockWatcher(): void {
    if (this.unlockWatcherTimer !== -1) {
      clearInterval(this.unlockWatcherTimer);
      this.unlockWatcherTimer = -1;
    }
  }

  private startDriftMotion(): void {
    if (this.driftMotionTimer !== -1) {
      return;
    }
    let lifted: boolean = false;
    const move: () => void = () => {
      lifted = !lifted;
      this.getUIContext().animateTo({ duration: 2600, curve: Curve.EaseInOut }, () => {
        this.driftFloatY = lifted ? -4 : 5;
        this.driftFloatAngle = lifted ? -1.4 : 1.6;
      });
    };
    move();
    this.driftMotionTimer = setInterval(move, 2700) as number;
  }

  private stopDriftMotion(): void {
    if (this.driftMotionTimer !== -1) {
      clearInterval(this.driftMotionTimer);
      this.driftMotionTimer = -1;
    }
  }

  private startDriftHedgehogAnimation(): void {
    if (this.driftHedgehogFrameTimer !== -1) {
      return;
    }
    this.driftHedgehogFrameTimer = setInterval(() => {
      this.driftHedgehogFrameIndex = (this.driftHedgehogFrameIndex + 1) % 5;
    }, 220) as number;
  }

  private stopDriftHedgehogAnimation(): void {
    if (this.driftHedgehogFrameTimer !== -1) {
      clearInterval(this.driftHedgehogFrameTimer);
      this.driftHedgehogFrameTimer = -1;
    }
  }

  private getDriftHedgehogFrame(): Resource {
    switch (this.driftHedgehogFrameIndex) {
      case 1:
        return $r('app.media.drift_hedgehog_frame_2');
      case 2:
        return $r('app.media.drift_hedgehog_frame_3');
      case 3:
        return $r('app.media.drift_hedgehog_frame_4');
      case 4:
        return $r('app.media.drift_hedgehog_frame_5');
      default:
        return $r('app.media.drift_hedgehog_frame_1');
    }
  }

  private async refreshNotificationPermissionStatus(): Promise<void> {
    try {
      this.futureNotificationEnabled = await notificationManager.isNotificationEnabled();
    } catch (_err) {
      this.futureNotificationEnabled = false;
    }
  }

  private async openFutureReminderSettings(): Promise<void> {
    try {
      await notificationManager.openNotificationSettings(this.getAbilityContext());
      this.statusText = '已经帮你打开通知设置了，打开后未来信才能按时提醒。';
    } catch (_err) {
      this.statusText = '通知设置没有成功打开，稍后再试一次。';
    }
  }

  private startSelectedEmotionAnimation(index: number): void {
    this.stopAllEmotionAnimations();
    const emotionId: string = this.emotionOptions[index].id;
    if (emotionId === 'confused') {
      this.startConfusedEmotionAnimation();
    } else if (emotionId === 'regret') {
      this.startRegretEmotionAnimation();
    } else if (emotionId === 'angry') {
      this.startAngryEmotionAnimation();
    } else if (emotionId === 'sad') {
      this.startSadEmotionAnimation();
    } else if (emotionId === 'happy') {
      this.startHappyEmotionAnimation();
    }
  }

  private playHomeEntryAnimation(): void {
    this.homeEntryOpacity = 0;
    this.homeEntryOffset = 18;
    setTimeout(() => {
      animateTo({
        duration: 480,
        curve: Curve.EaseOut
      }, () => {
        this.homeEntryOpacity = 1;
        this.homeEntryOffset = 0;
      });
    }, 60);
  }

  private playRecentEntryAnimation(): void {
    this.recentEntryOpacity = 0;
    this.recentEntryOffset = 18;
    setTimeout(() => {
      animateTo({
        duration: 480,
        curve: Curve.EaseOut
      }, () => {
        this.recentEntryOpacity = 1;
        this.recentEntryOffset = 0;
      });
    }, 150);
  }

  private playRecipientEntryAnimation(): void {
    this.recipientPageLeaving = false;
    this.recipientPageOffset = 480;
    setTimeout(() => {
      animateTo({
        duration: 360,
        curve: Curve.EaseOut
      }, () => {
        this.recipientPageOffset = 0;
      });
    }, 20);
  }

  private playRecipientExitAnimation(): void {
    if (this.recipientPageLeaving) {
      return;
    }
    this.recipientPageLeaving = true;
    animateTo({
      duration: 300,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.currentPage = 'home';
        this.homeTab = 0;
        this.recipientPageOffset = 480;
        this.recipientPageLeaving = false;
      }
    }, () => {
      this.recipientPageOffset = 480;
    });
  }

  private playEmotionEntryAnimation(): void {
    this.emotionEntryOpacity = 0;
    this.emotionEntryOffset = 18;
    setTimeout(() => {
      animateTo({
        duration: 480,
        curve: Curve.EaseOut
      }, () => {
        this.emotionEntryOpacity = 1;
        this.emotionEntryOffset = 0;
      });
    }, 60);
  }

  private playDriftDetailEntryAnimation(): void {
    this.driftDetailEntryOpacity = 0;
    this.driftDetailEntryOffset = 18;
    setTimeout(() => {
      animateTo({
        duration: 480,
        curve: Curve.EaseOut
      }, () => {
        this.driftDetailEntryOpacity = 1;
        this.driftDetailEntryOffset = 0;
      });
    }, 60);
  }

  private startConfusedEmotionAnimation(): void {
    if (this.confusedEmotionTimer !== -1) {
      return;
    }

    this.confusedEmotionFrameIndex = 0;
    this.confusedEmotionTimer = setInterval(() => {
      this.confusedEmotionFrameIndex = (this.confusedEmotionFrameIndex + 1) % 6;
    }, 170) as number;
  }

  private stopConfusedEmotionAnimation(): void {
    if (this.confusedEmotionTimer !== -1) {
      clearInterval(this.confusedEmotionTimer);
      this.confusedEmotionTimer = -1;
    }
    this.confusedEmotionFrameIndex = 0;
  }

  private getConfusedEmotionFrame(): Resource {
    switch (this.confusedEmotionFrameIndex) {
      case 1:
        return $r('app.media.emotion_confused_02');
      case 2:
        return $r('app.media.emotion_confused_03');
      case 3:
        return $r('app.media.emotion_confused_04');
      case 4:
        return $r('app.media.emotion_confused_05');
      case 5:
        return $r('app.media.emotion_confused_06');
      default:
        return $r('app.media.emotion_confused_01');
    }
  }

  private startRegretEmotionAnimation(): void {
    if (this.regretEmotionTimer !== -1) {
      return;
    }

    this.regretEmotionFrameIndex = 0;
    this.regretEmotionTimer = setInterval(() => {
      this.regretEmotionFrameIndex = (this.regretEmotionFrameIndex + 1) % 6;
    }, 155) as number;
  }

  private stopRegretEmotionAnimation(): void {
    if (this.regretEmotionTimer !== -1) {
      clearInterval(this.regretEmotionTimer);
      this.regretEmotionTimer = -1;
    }
    this.regretEmotionFrameIndex = 0;
  }

  private getRegretEmotionFrame(): Resource {
    switch (this.regretEmotionFrameIndex) {
      case 1:
        return $r('app.media.emotion_regret_02');
      case 2:
        return $r('app.media.emotion_regret_03');
      case 3:
        return $r('app.media.emotion_regret_04');
      case 4:
        return $r('app.media.emotion_regret_05');
      case 5:
        return $r('app.media.emotion_regret_06');
      default:
        return $r('app.media.emotion_regret_01');
    }
  }

  private startAngryEmotionAnimation(): void {
    if (this.angryEmotionTimer !== -1) {
      return;
    }

    this.angryEmotionFrameIndex = 0;
    this.angryEmotionTimer = setInterval(() => {
      this.angryEmotionFrameIndex = (this.angryEmotionFrameIndex + 1) % 5;
    }, 150) as number;
  }

  private stopAngryEmotionAnimation(): void {
    if (this.angryEmotionTimer !== -1) {
      clearInterval(this.angryEmotionTimer);
      this.angryEmotionTimer = -1;
    }
    this.angryEmotionFrameIndex = 0;
  }

  private getAngryEmotionFrame(): Resource {
    switch (this.angryEmotionFrameIndex) {
      case 1:
        return $r('app.media.emotion_angry_02');
      case 2:
        return $r('app.media.emotion_angry_03');
      case 3:
        return $r('app.media.emotion_angry_04');
      case 4:
        return $r('app.media.emotion_angry_05');
      default:
        return $r('app.media.emotion_angry_01');
    }
  }

  private startSadEmotionAnimation(): void {
    if (this.sadEmotionTimer !== -1) {
      return;
    }

    this.sadEmotionFrameIndex = 0;
    this.sadEmotionTimer = setInterval(() => {
      this.sadEmotionFrameIndex = (this.sadEmotionFrameIndex + 1) % 6;
    }, 160) as number;
  }

  private stopSadEmotionAnimation(): void {
    if (this.sadEmotionTimer !== -1) {
      clearInterval(this.sadEmotionTimer);
      this.sadEmotionTimer = -1;
    }
    this.sadEmotionFrameIndex = 0;
  }

  private getSadEmotionFrame(): Resource {
    switch (this.sadEmotionFrameIndex) {
      case 1:
        return $r('app.media.emotion_sad_02');
      case 2:
        return $r('app.media.emotion_sad_03');
      case 3:
        return $r('app.media.emotion_sad_04');
      case 4:
        return $r('app.media.emotion_sad_05');
      case 5:
        return $r('app.media.emotion_sad_06');
      default:
        return $r('app.media.emotion_sad_01');
    }
  }

  private startHappyEmotionAnimation(): void {
    if (this.happyEmotionTimer !== -1) {
      return;
    }

    this.happyEmotionFrameIndex = 0;
    this.happyEmotionTimer = setInterval(() => {
      this.happyEmotionFrameIndex = (this.happyEmotionFrameIndex + 1) % 6;
    }, 140) as number;
  }

  private stopHappyEmotionAnimation(): void {
    if (this.happyEmotionTimer !== -1) {
      clearInterval(this.happyEmotionTimer);
      this.happyEmotionTimer = -1;
    }
    this.happyEmotionFrameIndex = 0;
  }

  private getHappyEmotionFrame(): Resource {
    switch (this.happyEmotionFrameIndex) {
      case 1:
        return $r('app.media.emotion_happy_02');
      case 2:
        return $r('app.media.emotion_happy_03');
      case 3:
        return $r('app.media.emotion_happy_04');
      case 4:
        return $r('app.media.emotion_happy_05');
      case 5:
        return $r('app.media.emotion_happy_06');
      default:
        return $r('app.media.emotion_happy_01');
    }
  }

  private playRitualEntryAnimation(): void {
    this.ritualEntryOpacity = 0;
    this.ritualEntryOffset = 18;
    setTimeout(() => {
      animateTo({
        duration: 480,
        curve: Curve.EaseOut
      }, () => {
        this.ritualEntryOpacity = 1;
        this.ritualEntryOffset = 0;
      });
    }, 60);
  }

  private openComposer(): void {
    this.homeTab = 0;
    this.resetComposer();
    this.recipientEntryFromHome = true;
    this.currentPage = 'recipient';
    this.statusText = '先决定，这封信想写给谁。';
  }

  private openArchive(kind: string): void {
    this.archiveReturnPage = this.currentPage;
    this.archiveKind = kind;
    this.selectedSparkId = -1;
    this.currentPage = kind === 'spark' ? 'sparkSky' : (kind === 'drift' ? 'driftSea' : 'archive');
  }

  private chooseRecipient(index: number): void {
    this.selectedRecipientIndex = index;
    this.selectedEmotionIndex = -1;
    this.customEmotion = '';
    this.emotionConfirmLabel = '是什么呢';
    this.futureReminderDate = this.getMinimumFutureDate();
    this.stopAllEmotionAnimations();
    if (this.recipientOptions[index].id === 'custom') {
      this.statusText = '写下你想把这封信交给谁。';
      return;
    }
    this.customRecipient = '';
    this.currentPage = 'emotion';
    this.statusText = '再选一张情绪信纸，把心情放上去。';
  }

  private confirmCustomRecipient(): void {
    if (this.customRecipient.trim().length === 0) {
      this.statusText = '先写下一个收信人，再继续。';
      return;
    }
    this.currentPage = 'emotion';
    this.statusText = '再选一张情绪信纸，把心情放上去。';
  }

  private chooseEmotion(index: number): void {
    this.selectedEmotionIndex = index;
    this.emotionConfirmLabel = `是${this.emotionOptions[index].title}啊`;
    if (this.emotionOptions[index].id === 'other') {
      this.stopAllEmotionAnimations();
      this.emotionConfirmLabel = '写下这个心情';
      this.statusText = '用自己的词，给此刻的心情起个名字。';
      return;
    }
    this.customEmotion = '';
    this.startSelectedEmotionAnimation(index);
    this.statusText = `原来现在是${this.emotionOptions[index].title}啊。`;
  }

  private confirmEmotionSelection(): void {
    if (this.selectedEmotionIndex < 0) {
      this.statusText = '先选一种此刻更接近的心情。';
      return;
    }
    if (this.emotionOptions[this.selectedEmotionIndex].id === 'other' && this.customEmotion.trim().length === 0) {
      this.statusText = '先写下此刻的心情，再继续。';
      return;
    }
    this.stopAllEmotionAnimations();
    this.currentPage = 'writing';
    this.statusText = '慢慢写，暂时不用急着发送。';
  }

  private async choosePhotos(): Promise<void> {
    try {
      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const options: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 9;
      const result: picker.PhotoSelectResult = await photoPicker.select(options);
      const selectedUris: Array<string> = result.photoUris as Array<string>;
      if (selectedUris.length > 0) {
        this.photoUris = this.photoUris.concat(selectedUris).slice(0, 9);
        this.statusText = `已添加 ${this.photoUris.length} 张照片。`;
      }
    } catch (_err) {
      this.statusText = '照片没有添加成功，可以稍后再试。';
    }
  }

  private removePhoto(index: number): void {
    this.photoUris = this.photoUris.filter((_uri: string, itemIndex: number) => itemIndex !== index);
  }

  private saveDraft(): void {
    const content: string = this.letterContent.trim();
    if (content.length === 0) {
      this.statusText = '信里还没有内容，先写下一句话也可以。';
      return;
    }

    const draft: LetterRecord = this.createRecord('草稿', '暂时留在这里，等你准备好再继续');
    this.drafts = [draft, ...this.drafts.filter((item: LetterRecord) => item.id !== draft.id)];
    this.persistLetters();
    this.statusText = '已经替你自动存进草稿箱了。';
  }

  private goToRitual(): void {
    if (this.letterContent.trim().length === 0) {
      this.statusText = '先写下一点内容，再决定如何安放。';
      return;
    }
    this.currentPage = 'ritual';
    this.statusText = '选一个属于这封信的数字仪式。';
  }

  private async ensureNotificationPermission(): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        this.futureNotificationEnabled = true;
        return true;
      }
      await notificationManager.requestEnableNotification(this.getAbilityContext());
      this.futureNotificationEnabled = true;
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      this.futureNotificationEnabled = false;
      if (error.code === 1600004) {
        this.statusText = '你还没有允许通知，先打开通知设置，未来信才能按时提醒。';
      } else {
        this.statusText = '通知权限申请没有成功，稍后再试一次。';
      }
      return false;
    }
  }

  private async scheduleFutureReminder(record: LetterRecord): Promise<number> {
    const unlockDate: Date = new Date(record.unlockAt);
    const reminderRequest: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: unlockDate.getFullYear(),
        month: unlockDate.getMonth() + 1,
        day: unlockDate.getDate(),
        hour: unlockDate.getHours(),
        minute: unlockDate.getMinutes(),
        second: unlockDate.getSeconds()
      },
      wantAgent: {
        pkgName: this.appBundleName,
        abilityName: 'EntryAbility'
      },
      title: '未来信到时间了',
      content: `你写给未来的信，现在可以打开了。`,
      slotType: notificationManager.SlotType.CONTENT_INFORMATION
    };

    try {
      return await reminderAgentManager.publishReminder(reminderRequest);
    } catch (_err) {
      return 0;
    }
  }

  private async confirmFutureDelivery(): Promise<void> {
    const unlockDate: Date = this.getFutureReminderMoment(this.futureReminderDate);
    if (unlockDate.getTime() <= Date.now()) {
      this.statusText = '换一个还没到的日期吧。';
      return;
    }

    const permissionGranted: boolean = await this.ensureNotificationPermission();
    if (!permissionGranted) {
      return;
    }

    const openDate: string = this.formatDateTime(unlockDate);
    const originalContent: string = this.letterContent.trim();
    let record: LetterRecord = this.createRecord('寄给未来', '把愿望留给未来的自己开启');
    record = {
      id: record.id,
      title: record.title,
      date: record.date,
      weekday: record.weekday,
      recipient: record.recipient,
      recipientHint: record.recipientHint,
      emotion: record.emotion,
      emotionHint: record.emotionHint,
      ritual: record.ritual,
      ritualHint: `会在 ${openDate} 重新交到你手里`,
      content: record.content,
      keywords: record.keywords,
      echoLine: `等到 ${openDate}，再由未来的你亲手打开。`,
      moodTag: record.moodTag,
      anonymous: record.anonymous,
      unlockDate: openDate,
      unlockAt: unlockDate.getTime(),
      reminderId: 0,
      photoUris: [...this.photoUris],
      driftStartedAt: 0
    };

    const reminderId: number = await this.scheduleFutureReminder(record);
    record = {
      id: record.id,
      title: record.title,
      date: record.date,
      weekday: record.weekday,
      recipient: record.recipient,
      recipientHint: record.recipientHint,
      emotion: record.emotion,
      emotionHint: record.emotionHint,
      ritual: record.ritual,
      ritualHint: record.ritualHint,
      content: record.content,
      keywords: record.keywords,
      echoLine: record.echoLine,
      moodTag: record.moodTag,
      anonymous: record.anonymous,
      unlockDate: record.unlockDate,
      unlockAt: record.unlockAt,
      reminderId: reminderId,
      photoUris: [...record.photoUris],
      driftStartedAt: record.driftStartedAt
    };

    this.futureLetters = [record, ...this.futureLetters];
    this.echoCards = [record, ...this.echoCards];
    this.activeEchoId = record.id;
    this.drafts = this.drafts.filter((item: LetterRecord) => item.content !== originalContent);
    this.persistLetters();
    this.enterEcho(record, 'ritual');
    this.statusText = reminderId > 0
      ? '它已经寄往未来，到时间系统会提醒你打开。'
      : '未来信已经保存好了，但当前设备暂时没有成功接管到点提醒。';
  }

  private cancelFutureReminder(reminderId: number): void {
    if (reminderId <= 0) {
      return;
    }
    reminderAgentManager.cancelReminder(reminderId).catch((_err: BusinessError) => {
    });
  }

  private applyRitual(index: number): void {
    const ritual: SelectItem = this.ritualOptions[index];
    if (ritual.id === 'spark') {
      this.currentPage = 'sparkConfirm';
      this.statusText = '燃成光点后，正文和照片将无法恢复。';
      return;
    }
    if (ritual.id === 'future') {
      this.refreshNotificationPermissionStatus();
      this.currentPage = 'futureSchedule';
      this.statusText = '选一个未来日期，到那天我再提醒你打开。';
      return;
    }
    this.completeRitual(index);
  }

  private confirmSparkRitual(): void {
    this.completeRitual(1);
  }

  private completeRitual(index: number): void {
    const ritual: SelectItem = this.ritualOptions[index];
    const originalContent: string = this.letterContent.trim();
    let record: LetterRecord = this.createRecord(ritual.title, ritual.subtitle);

    if (ritual.id === 'seal') {
      this.sealedLetters = [record, ...this.sealedLetters];
      this.statusText = '这封信已经被封存在时光盒里了。';
    } else if (ritual.id === 'drift') {
      record = {
        id: record.id,
        title: record.title,
        date: record.date,
        weekday: record.weekday,
        recipient: record.recipient,
        recipientHint: record.recipientHint,
        emotion: record.emotion,
        emotionHint: record.emotionHint,
        ritual: record.ritual,
        ritualHint: '正文和照片会收在瓶中。它会继续远行，但你随时可以捞起看看。',
        content: record.content,
        echoLine: '先让这段心事离岸，给自己一点距离。',
        keywords: [record.emotion, '漂流', '暂时放下'],
        moodTag: record.moodTag,
        anonymous: record.anonymous,
        unlockDate: record.unlockDate,
        unlockAt: record.unlockAt,
        reminderId: record.reminderId,
        photoUris: [...record.photoUris],
        driftStartedAt: Date.now(),
        driftTideAt: Date.now() + 7 * 24 * 60 * 60 * 1000,
        driftMoodNow: ''
      };
      this.driftLetters = [record, ...this.driftLetters];
      this.statusText = '漂流信已经离岸，小刺猬会陪它慢慢划远。';
    } else if (ritual.id === 'spark') {
      record = {
        id: record.id,
        title: record.title,
        date: record.date,
        weekday: record.weekday,
        recipient: record.recipient,
        recipientHint: record.recipientHint,
        emotion: record.emotion,
        emotionHint: record.emotionHint,
        ritual: record.ritual,
        ritualHint: '正文和照片已经化成光点，只留下这一刻的情绪与回声。',
        content: '',
        echoLine: this.sparkAfterglow.trim().length > 0
          ? this.sparkAfterglow.trim() : '这封信已经化成一颗光。',
        afterglow: this.sparkAfterglow.trim(),
        keywords: [record.emotion, '光点', '放下'],
        moodTag: record.moodTag,
        anonymous: record.anonymous,
        unlockDate: record.unlockDate,
        unlockAt: record.unlockAt,
        reminderId: record.reminderId,
        photoUris: [],
        driftStartedAt: 0
      };
      this.statusText = '这封信已经化成光点，只留下短短一束回声。';
    }

    this.echoCards = [record, ...this.echoCards];
    this.activeEchoId = record.id;
    this.drafts = this.drafts.filter((item: LetterRecord) => item.content !== originalContent);
    this.persistLetters();
    if (ritual.id === 'drift') {
      this.enterEcho(record, 'ritual');
      this.initialDriftReceipt = true;
    } else {
      this.enterEcho(record, 'ritual');
    }
  }

  private createRecord(ritual: string, ritualHint: string): LetterRecord {
    const recipient: SelectItem = this.getSelectedRecipient();
    const emotion: SelectItem = this.getSelectedEmotion();
    const now: Date = new Date();
    const record: LetterRecord = {
      id: this.nextId,
      title: this.letterTitle.trim(),
      date: this.formatDate(now),
      weekday: this.getWeekday(now.getDay()),
      recipient: recipient.title,
      recipientHint: recipient.subtitle,
      emotion: emotion.title,
      emotionHint: emotion.subtitle,
      ritual: ritual,
      ritualHint: ritualHint,
      content: this.letterContent.trim(),
      keywords: [emotion.title, this.moodTag, ritual],
      echoLine: this.getEchoLine(ritual),
      afterglow: '',
      moodTag: this.moodTag,
      anonymous: this.isAnonymous,
      unlockDate: '',
      unlockAt: 0,
      reminderId: 0,
      photoUris: [...this.photoUris],
      driftStartedAt: 0
    };
    this.nextId += 1;
    return record;
  }

  private createSoftExcerpt(content: string, maxLength: number): string {
    const trimmed: string = content.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return `${trimmed.slice(0, maxLength)}...`;
  }

  private createSparkExcerpt(content: string): string {
    const trimmed: string = content.trim();
    if (trimmed.length <= 12) {
      return trimmed;
    }
    return `${trimmed.slice(0, 12)}...`;
  }

  private getMinimumFutureDate(): Date {
    const nextDate: Date = new Date();
    nextDate.setDate(nextDate.getDate() + 1);
    nextDate.setHours(0, 0, 0, 0);
    return nextDate;
  }

  private getFutureReminderMoment(selectedDate: Date): Date {
    const reminderDate: Date = new Date(selectedDate.getTime());
    reminderDate.setHours(this.futureReminderHour, 0, 0, 0);
    return reminderDate;
  }

  private formatDateTime(date: Date): string {
    const hour: string = `${date.getHours()}`.padStart(2, '0');
    const minute: string = `${date.getMinutes()}`.padStart(2, '0');
    return `${this.formatDate(date)} ${hour}:${minute}`;
  }

  private isFutureUnlocked(record: LetterRecord): boolean {
    if (record.unlockAt <= 0) {
      return true;
    }
    return this.unlockWatcherNow >= record.unlockAt;
  }

  private getUnlockedFutureCount(): number {
    let count: number = 0;
    this.futureLetters.forEach((item: LetterRecord) => {
      if (this.isFutureUnlocked(item)) {
        count += 1;
      }
    });
    return count;
  }

  private getRecordStatusLabel(record: LetterRecord): string {
    if (record.ritual === '漂流') {
      return this.getDriftStage(record);
    }
    if (record.ritual === '寄给未来') {
      return this.isFutureUnlocked(record) ? '已开启' : '待开启';
    }
    return record.ritual;
  }

  private getRecordStatusBackground(record: LetterRecord): string {
    if (record.ritual === '寄给未来' && this.isFutureUnlocked(record)) {
      return '#E9F3EA';
    }
    if (record.ritual === '寄给未来') {
      return '#EDF1F7';
    }
    return '#F1E8DE';
  }

  private getFuturePermissionHint(): string {
    if (this.futureNotificationEnabled) {
      return '通知权限已开启，到时间会自动弹出系统提醒。';
    }
    return '通知权限还没打开，未来信依然会保存，但设备可能不会按时弹通知。';
  }

  private getEchoPageTitle(record: LetterRecord): string {
    if (record.ritual === '封存') {
      return '这封信已经被封存';
    }
    if (record.ritual === '燃成光点') {
      return '这封信已经化成光点';
    }
    if (record.ritual === '漂流') {
      return '这封信正在漂流';
    }
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return '这封信已经寄往未来';
    }
    if (record.ritual === '寄给未来') {
      return '这封来自过去的信到了';
    }
    return '这是一封未寄出的信';
  }

  private getEchoPageSubtitle(record: LetterRecord): string {
    if (record.ritual === '封存') {
      return '完整内容会被好好收着，等你想打开时再回来。';
    }
    if (record.ritual === '燃成光点') {
      return '正文和照片已经散去，只留下当时的情绪与这一束回声。';
    }
    if (record.ritual === '漂流') {
      return '完整内容仍在漂流信里，等你准备好时可以随时捞回来。';
    }
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return `它会在 ${record.unlockDate} 再次来到你面前。`;
    }
    if (record.ritual === '寄给未来') {
      return '现在可以打开它，看看过去的自己留下了什么。';
    }
    return '它已经被妥善安放。';
  }

  private getEchoContentLabel(record: LetterRecord): string {
    if (record.ritual === '燃成光点') {
      return '原文状态：';
    }
    if (record.ritual === '漂流') {
      return '漂流信中的原文：';
    }
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return '未来开启时间：';
    }
    return '留下的一句话：';
  }

  private getDisplayedContent(record: LetterRecord): string {
    if (record.ritual === '漂流') {
      return this.getDriftSafeLine(record);
    }
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return record.unlockDate;
    }
    if (record.ritual === '燃成光点') {
      return '正文和照片已被永久清除，无法恢复。';
    }
    return `“${record.content}”`;
  }

  private getArchiveDisplayText(record: LetterRecord): string {
    if (record.ritual === '漂流') {
      return this.getDriftSafeLine(record);
    }
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return `将于 ${record.unlockDate} 开启\n在那之前，这封信会先替你安静地留着。`;
    }
    if (record.ritual === '燃成光点') {
      return '原文与照片已化成光点，只留下当时的情绪。';
    }
    return `“${record.content}”`;
  }

  private getSparkLetters(): Array<LetterRecord> {
    return this.echoCards.filter((item: LetterRecord) => item.ritual === '燃成光点');
  }

  private isSparkCollected(id: number): boolean {
    return this.collectedSparkIds.indexOf(id) >= 0;
  }

  private getCollectedSparks(): Array<LetterRecord> {
    return this.getSparkLetters().filter((item: LetterRecord) => this.isSparkCollected(item.id));
  }

  private getPendingSparks(): Array<LetterRecord> {
    return this.getSparkLetters().filter((item: LetterRecord) => !this.isSparkCollected(item.id));
  }

  private getSparkColor(emotion: string): string {
    switch (emotion) {
      case '开心': return '#F2CE83';
      case '伤心': return '#A9CCE9';
      case '遗憾': return '#C9B8E8';
      case '生气': return '#EDA99A';
      case '迷茫': return '#B9D7C4';
      default: return '#E9DCC5';
    }
  }

  private getSparkVisualSize(index: number): number {
    const sizes: number[] = [12, 17, 14, 20, 13, 16];
    return sizes[index % sizes.length];
  }

  private getSparkVisualOpacity(index: number): number {
    const opacities: number[] = [0.68, 0.9, 0.76, 1, 0.72, 0.84];
    return opacities[index % opacities.length];
  }

  private getSparkVisualOffset(index: number): number {
    const offsets: number[] = [-8, 7, -2, 11, 3, -6];
    return offsets[index % offsets.length];
  }

  private glowSelectedSpark(id: number): void {
    this.selectedSparkId = id;
    this.selectedSparkGlowScale = 0.96;
    this.selectedSparkGlowOpacity = 0.34;
    animateTo({
      duration: 220,
      curve: Curve.EaseOut,
      onFinish: () => {
        animateTo({ duration: 520, curve: Curve.EaseInOut }, () => {
          this.selectedSparkGlowScale = 1;
          this.selectedSparkGlowOpacity = 0.44;
        });
      }
    }, () => {
      this.selectedSparkGlowScale = 1.18;
      this.selectedSparkGlowOpacity = 0.58;
    });
  }

  private collectActiveSpark(): void {
    if (this.collectingSpark) {
      return;
    }
    const id: number = this.getActiveEcho().id;
    if (this.contentReturnPage !== 'sparkSky') {
      this.archiveReturnPage = this.currentPage;
    }
    this.selectedSparkId = id;
    if (this.isSparkCollected(id)) {
      this.currentPage = 'sparkSky';
      return;
    }
    this.collectedSparkIds = [...this.collectedSparkIds, id];
    this.persistLetters();
    this.collectingSpark = true;
    this.getUIContext().animateTo({ duration: 650, curve: Curve.EaseInOut, onFinish: () => {
      this.collectingSpark = false;
      this.sparkScale = 1;
      this.sparkOpacity = 1;
      if (this.currentPage === 'echo' && this.activeEchoId === id) {
        this.currentPage = 'sparkSky';
      }
    } }, () => {
      this.sparkScale = 0.15;
      this.sparkOpacity = 0;
    });
  }

  private getDriftAgeLabel(record: LetterRecord): string {
    if (record.driftStartedAt <= 0) {
      return '已经漂流一段时间';
    }
    const elapsed: number = this.unlockWatcherNow - record.driftStartedAt;
    const days: number = Math.floor(elapsed / (24 * 60 * 60 * 1000));
    if (days <= 0) {
      return '刚刚开始漂流';
    }
    return `已漂流 ${days} 天`;
  }

  private getDriftTideAt(record: LetterRecord): number {
    return record.driftTideAt && record.driftTideAt > 0
      ? record.driftTideAt : record.driftStartedAt + 7 * 24 * 60 * 60 * 1000;
  }

  private isDriftReturned(record: LetterRecord): boolean {
    return this.unlockWatcherNow >= this.getDriftTideAt(record);
  }

  private getDriftStage(record: LetterRecord): string {
    if (this.isDriftReturned(record)) {
      return '随潮归来';
    }
    const cycleStart: number = this.getDriftTideAt(record) - 7 * 24 * 60 * 60 * 1000;
    const days: number = Math.floor((this.unlockWatcherNow - cycleStart) / (24 * 60 * 60 * 1000));
    if (days <= 0) {
      return '近岸轻漂';
    }
    if (days < 3) {
      return '驶向远海';
    }
    return days < 6 ? '远海漫游' : '循潮归来';
  }

  private getDriftSafeLine(record: LetterRecord): string {
    if (this.isDriftReturned(record)) {
      return '小刺猬顺着潮水划回岸边。它没有催你，只是在等你的决定。';
    }
    return '这封信正在海上旅行。你可以观察它，也可以随时把它捞回来。';
  }

  private getDriftRemainingLabel(record: LetterRecord): string {
    return this.isDriftReturned(record) ? '已经靠岸 · 随时可以打开' : '不必等到某一天 · 想看时就捞起它';
  }

  private getDriftJourneyLine(record: LetterRecord): string {
    if (this.isDriftReturned(record)) {
      return '它没有催你，只是安静地回到了岸边';
    }
    const days: number = Math.max(0, Math.floor((this.unlockWatcherNow - record.driftStartedAt) / (24 * 60 * 60 * 1000)));
    if (days <= 0) {
      return '海风刚刚接过这件心事';
    }
    if (days < 3) {
      return '离岸之后，那些声音正在变轻';
    }
    if (days < 6) {
      return '它漂到远处，而你仍在继续生活';
    }
    return '潮水正在把它慢慢送向你';
  }

  private getDriftMoodLabel(): string {
    const options: Array<string> = ['轻松些了', '仍有点难过', '平静了', '还说不清'];
    if (this.driftMoodIndex === 4) {
      return this.driftCustomMood.trim();
    }
    return this.driftMoodIndex >= 0 && this.driftMoodIndex < options.length ? options[this.driftMoodIndex] : '';
  }

  private hasCurrentDriftMood(): boolean {
    return this.driftMoodIndex >= 0 && (this.driftMoodIndex !== 4 || this.driftCustomMood.trim().length > 0);
  }

  private continueDrift(record: LetterRecord): void {
    const next: LetterRecord = this.normalizeRecord(record);
    next.driftTideAt = this.unlockWatcherNow + 7 * 24 * 60 * 60 * 1000;
    this.driftLetters = this.driftLetters.map((item: LetterRecord) => item.id === record.id ? next : item);
    this.echoCards = this.echoCards.map((item: LetterRecord) => item.id === record.id ? next : item);
    this.driftPeek = false;
    this.driftMoodIndex = -1;
    this.driftCustomMood = '';
    this.persistLetters();
    this.currentPage = 'driftSea';
    this.statusText = '小刺猬再次带着漂流信驶向远海。想看看时，随时回来。';
  }

  private convertDriftToSpark(record: LetterRecord): void {
    const spark: LetterRecord = this.normalizeRecord(record);
    spark.ritual = '燃成光点';
    spark.ritualHint = '正文和照片已经化成光点，只留下这一刻的情绪与回声。';
    spark.content = '';
    spark.photoUris = [];
    spark.echoLine = '曾经漂流的心事，终于化成了一点光。';
    spark.keywords = [record.emotion, '光点', '放下'];
    spark.driftStartedAt = 0;
    spark.driftTideAt = 0;
    this.driftLetters = this.driftLetters.filter((item: LetterRecord) => item.id !== record.id);
    this.echoCards = this.echoCards.map((item: LetterRecord) => item.id === record.id ? spark : item);
    this.persistLetters();
    this.currentPage = 'echo';
    this.statusText = '漂流信已经化成光点，原文和照片不再保留。';
  }

  private getEchoLine(ritual: string): string {
    if (ritual === '封存') {
      return '这句话已经被好好收下了。';
    }
    if (ritual === '燃成光点') {
      return '它会化成光，陪你走过这段情绪。';
    }
    if (ritual === '漂流') {
      return '它已经顺着风慢慢远去。';
    }
    if (ritual === '寄给未来') {
      return '未来的某天，它会再次来到你面前。';
    }
    return '先把这段话留在这里。';
  }

  private formatDate(date: Date): string {
    const year: number = date.getFullYear();
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
    const day: string = `${date.getDate()}`.padStart(2, '0');
    return `${year}.${month}.${day}`;
  }

  private getWeekday(day: number): string {
    const weeks: Array<string> = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    return weeks[day];
  }

  private resetComposer(): void {
    this.selectedRecipientIndex = -1;
    this.selectedEmotionIndex = -1;
    this.customRecipient = '';
    this.customEmotion = '';
    this.emotionConfirmLabel = '是什么呢';
    this.letterTitle = '';
    this.letterContent = '';
    this.sparkAfterglow = '';
    this.photoUris = [];
    this.isAnonymous = false;
    this.moodTag = '私语';
    this.futureReminderDate = this.getMinimumFutureDate();
    this.driftReflection = '';
    this.writingReturnPage = 'emotion';
    this.recalledDriftOrigin = undefined;
  }

  private continueDraft(record: LetterRecord, fromDrift: boolean = false): void {
    this.selectedRecipientIndex = this.findIndexByTitle(this.recipientOptions, record.recipient);
    this.selectedEmotionIndex = this.findIndexByTitle(this.emotionOptions, record.emotion);
    this.customRecipient = '';
    this.customEmotion = '';
    if (this.selectedRecipientIndex === 0 && record.recipient !== this.recipientOptions[0].title) {
      this.selectedRecipientIndex = this.recipientOptions.length - 1;
      this.customRecipient = record.recipient.replace('写给', '');
    }
    if (this.selectedEmotionIndex === 0 && record.emotion !== this.emotionOptions[0].title) {
      this.selectedEmotionIndex = this.emotionOptions.length - 1;
      this.customEmotion = record.emotion;
    }
    this.letterTitle = record.title ?? '';
    this.letterContent = record.content;
    this.photoUris = [...(record.photoUris ?? [])];
    this.moodTag = record.moodTag;
    this.isAnonymous = record.anonymous;
    this.futureReminderDate = this.getMinimumFutureDate();
    this.driftReflection = record.driftMoodNow && record.driftMoodNow.length > 0
      ? `漂流前：${record.emotion}  →  现在：${record.driftMoodNow}` : '';
    this.writingReturnPage = fromDrift ? 'driftDetail' : this.currentPage;
    if (!fromDrift) {
      this.recalledDriftOrigin = undefined;
    }
    this.currentPage = 'writing';
    this.statusText = '已经帮你把草稿重新铺开了。';
  }

  private recallDriftLetter(record: LetterRecord): void {
    const moodNow: string = this.getDriftMoodLabel();
    this.recalledDriftOrigin = this.normalizeRecord(record);
    const draft: LetterRecord = {
      id: record.id,
      title: record.title,
      date: record.date,
      weekday: record.weekday,
      recipient: record.recipient,
      recipientHint: record.recipientHint,
      emotion: record.emotion,
      emotionHint: record.emotionHint,
      ritual: '草稿',
      ritualHint: `漂流前：${record.emotion} · 现在：${moodNow || '还说不清'}`,
      content: record.content,
      keywords: [record.emotion, moodNow || '还说不清', '重新面对'],
      echoLine: `那时是${record.emotion}，现在${moodNow || '还说不清'}。你把它捡回来了。`,
      moodTag: record.moodTag,
      anonymous: record.anonymous,
      unlockDate: '',
      unlockAt: 0,
      reminderId: 0,
      photoUris: [...record.photoUris],
      driftStartedAt: 0,
      driftTideAt: 0,
      driftMoodNow: moodNow
    };
    this.driftLetters = this.driftLetters.filter((item: LetterRecord) => item.id !== record.id);
    this.echoCards = this.echoCards.filter((item: LetterRecord) => item.id !== record.id);
    this.drafts = [draft, ...this.drafts.filter((item: LetterRecord) => item.id !== record.id)];
    this.activeEchoId = record.id;
    this.persistLetters();
    this.continueDraft(draft, true);
    this.statusText = '漂流的信已经捡回，完整正文和照片都还在。';
  }

  private findIndexByTitle(items: Array<SelectItem>, title: string): number {
    let index: number = 0;
    while (index < items.length) {
      if (items[index].title === title) {
        return index;
      }
      index += 1;
    }
    return 0;
  }

  private enterEcho(record: LetterRecord, returnPage: string = ''): void {
    this.contentReturnPage = returnPage.length > 0 ? returnPage : this.currentPage;
    this.openedMenuId = -1;
    this.recalledDriftOrigin = undefined;
    this.writingReturnPage = 'emotion';
    this.initialDriftReceipt = false;
    this.activeEchoId = record.id;
    this.driftPeek = false;
    this.driftMoodIndex = -1;
    this.driftCustomMood = '';
    this.driftDetailEntryOpacity = 0;
    this.driftDetailEntryOffset = 18;
    this.currentPage = record.ritual === '漂流' ? 'driftDetail' : 'echo';
  }

  private toggleDeleteMenu(recordId: number): void {
    if (this.openedMenuId === recordId) {
      this.openedMenuId = -1;
      return;
    }
    this.openedMenuId = recordId;
  }

  private closeDeleteMenu(): void {
    this.openedMenuId = -1;
  }

  private deleteRecord(targetId: number): void {
    let reminderId: number = 0;
    this.futureLetters.forEach((item: LetterRecord) => {
      if (item.id === targetId) {
        reminderId = item.reminderId;
      }
    });
    this.cancelFutureReminder(reminderId);
    this.sealedLetters = this.sealedLetters.filter((item: LetterRecord) => item.id !== targetId);
    this.futureLetters = this.futureLetters.filter((item: LetterRecord) => item.id !== targetId);
    this.driftLetters = this.driftLetters.filter((item: LetterRecord) => item.id !== targetId);
    this.echoCards = this.echoCards.filter((item: LetterRecord) => item.id !== targetId);
    this.collectedSparkIds = this.collectedSparkIds.filter((id: number) => id !== targetId);

    if (this.activeEchoId === targetId) {
      if (this.echoCards.length > 0) {
        this.activeEchoId = this.echoCards[0].id;
      } else {
        this.activeEchoId = -1;
        if (this.currentPage === 'echo') {
          this.currentPage = 'home';
          this.homeTab = 1;
        }
      }
    }

    this.openedMenuId = -1;
    this.persistLetters();
    this.statusText = '这封信已经删除了。';
  }

  private getArchiveTitle(): string {
    if (this.archiveKind === 'draft') {
      return '草稿箱';
    }
    if (this.archiveKind === 'sealed') {
      return '封存的信';
    }
    if (this.archiveKind === 'future') {
      return '未来信';
    }
    if (this.archiveKind === 'drift') {
      return '漂流信';
    }
    if (this.archiveKind === 'spark') {
      return '光点星空';
    }
    return '情绪回声卡';
  }

  private getArchiveSubtitle(): string {
    if (this.archiveKind === 'draft') {
      return '先写到这里，等你准备好再继续。';
    }
    if (this.archiveKind === 'sealed') {
      return '这些话已经被好好收好了。';
    }
    if (this.archiveKind === 'future') {
      return '等未来的某天，再由你亲手打开。';
    }
    if (this.archiveKind === 'drift') {
      return '这里保留完整内容；等你准备好，可以把信捡回来继续写。';
    }
    if (this.archiveKind === 'spark') {
      return '原文已经散去，只留下写信日期、情绪与温柔回声。';
    }
    return '把每一次安放都留成一张回声卡。';
  }

  private getArchiveItems(): Array<LetterRecord> {
    if (this.archiveKind === 'draft') {
      return this.drafts;
    }
    if (this.archiveKind === 'sealed') {
      return this.sealedLetters;
    }
    if (this.archiveKind === 'future') {
      return this.futureLetters;
    }
    if (this.archiveKind === 'drift') {
      return this.driftLetters;
    }
    if (this.archiveKind === 'spark') {
      return this.getSparkLetters();
    }
    return this.echoCards;
  }

  private getRecentLetters(limit: number): Array<LetterRecord> {
    const merged: Array<LetterRecord> = [];
    const seenIds: Array<number> = [];
    const sources: Array<Array<LetterRecord>> = [this.drafts, this.sealedLetters, this.futureLetters, this.driftLetters, this.echoCards];

    sources.forEach((items: Array<LetterRecord>) => {
      items.forEach((item: LetterRecord) => {
        if (seenIds.indexOf(item.id) === -1) {
          seenIds.push(item.id);
          merged.push(item);
        }
      });
    });

    merged.sort((left: LetterRecord, right: LetterRecord) => {
      if (left.date === right.date) {
        return right.id - left.id;
      }
      return left.date < right.date ? 1 : -1;
    });

    return merged.slice(0, limit);
  }

  private getRecordTimestamp(record: LetterRecord): number {
    const parts: Array<string> = record.date.split('.');
    if (parts.length !== 3) {
      return 0;
    }
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])).getTime();
  }

  private getFilteredEchoCards(): Array<LetterRecord> {
    if (this.echoTimeFilter === 'all') {
      return this.echoCards;
    }
    const now: Date = new Date(this.unlockWatcherNow);
    if (this.echoTimeFilter === 'year') {
      return this.echoCards.filter((item: LetterRecord) => {
        const timestamp: number = this.getRecordTimestamp(item);
        return timestamp > 0 && new Date(timestamp).getFullYear() === now.getFullYear();
      });
    }
    const days: number = this.echoTimeFilter === '7d' ? 7 : 30;
    const cutoff: number = this.unlockWatcherNow - days * 24 * 60 * 60 * 1000;
    return this.echoCards.filter((item: LetterRecord) => this.getRecordTimestamp(item) >= cutoff);
  }

  private getDriftCardBackground(emotion: string): string {
    switch (emotion) {
      case '开心': return '#FBF3DE';
      case '伤心': return '#EAF2F5';
      case '遗憾': return '#F1ECF4';
      case '生气': return '#F7ECE8';
      case '迷茫': return '#EAF2ED';
      default: return '#F6F1EA';
    }
  }

  @Builder
  private buildRecipientIllustration(id: string) {
    if (id === 'self') {
      Image($r('app.media.recipient_self'))
        .width(92)
        .height(76)
        .objectFit(ImageFit.Contain)
    } else if (id === 'someone') {
      Image($r('app.media.recipient_someone'))
        .width(92)
        .height(76)
        .objectFit(ImageFit.Contain)
    } else if (id === 'future') {
      Image($r('app.media.recipient_future'))
        .width(98)
        .height(78)
        .objectFit(ImageFit.Contain)
    } else if (id === 'custom') {
      Column({ space: 6 }) {
        Text('✎')
          .fontSize(22)
          .fontColor('#9D9387')
        Text('自定义')
          .fontSize(12)
          .fontColor('#9D9387')
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width(86)
      .height(70)
      .backgroundColor('#F7F1EA')
      .borderRadius(18)
    } else {
      Image($r('app.media.recipient_unknown'))
        .width(84)
        .height(72)
        .objectFit(ImageFit.Contain)
    }
  }

  @Builder
  private buildRecipientCard(item: SelectItem, index: number) {
    Row() {
      Column({ space: 8 }) {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
        Text(item.subtitle)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.buildRecipientIllustration(item.id)
    }
    .width('100%')
    .padding({ left: 18, right: 14, top: 16, bottom: 16 })
    .backgroundColor(WeiyuTheme.COLOR_SURFACE)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
    .shadow({
      radius: 10,
      color: '#0A000000',
      offsetX: 0,
      offsetY: 3
    })
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(`${item.title}，${item.subtitle}`)
    .onClick(() => {
      this.chooseRecipient(index);
    })
  }

  @Builder
  private buildRitualIllustration(id: string) {
    if (id === 'seal') {
      Image($r('app.media.ritual_seal'))
        .width(96)
        .height(86)
        .objectFit(ImageFit.Contain)
    } else if (id === 'spark') {
      Image($r('app.media.ritual_spark'))
        .width(96)
        .height(86)
        .objectFit(ImageFit.Contain)
    } else if (id === 'drift') {
      Image($r('app.media.ritual_drift'))
        .width(96)
        .height(86)
        .objectFit(ImageFit.Contain)
    } else {
      Image($r('app.media.ritual_future'))
        .width(96)
        .height(86)
        .objectFit(ImageFit.Contain)
    }
  }

  @Builder
  private buildRitualCard(item: SelectItem, index: number) {
    Row() {
      Column({ space: 8 }) {
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
        Text(item.subtitle)
          .fontSize(12)
          .lineHeight(20)
          .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
      }
      .alignItems(HorizontalAlign.Start)
      .width('64%')

      Blank()

      this.buildRitualIllustration(item.id)
    }
    .width('100%')
    .padding({ left: 18, right: 14, top: 16, bottom: 16 })
    .backgroundColor(WeiyuTheme.COLOR_SURFACE)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
    .shadow({
      radius: 10,
      color: '#0A000000',
      offsetX: 0,
      offsetY: 3
    })
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(`${item.title}，${item.subtitle}`)
    .onClick(() => {
      this.applyRitual(index);
    })
  }

  @Builder
  private buildEmotionIllustration(id: string) {
    if (id === 'sad') {
      Image(this.getSadEmotionFrame())
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'regret') {
      Image(this.getRegretEmotionFrame())
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'angry') {
      Image(this.getAngryEmotionFrame())
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'happy') {
      Image(this.getHappyEmotionFrame())
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'confused') {
      Image(this.getConfusedEmotionFrame())
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else {
      Column({ space: 6 }) {
        Text('...')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#A0978B')
        Text('慢慢说')
          .fontSize(12)
          .fontColor('#A0978B')
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width(84)
      .height(68)
      .backgroundColor('#F7F2EB')
      .borderRadius(18)
    }
  }

  @Builder
  private buildEmotionCard(item: SelectItem, index: number) {
    Column({ space: 10 }) {
      Text(item.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
      Text(item.subtitle)
        .fontSize(12)
        .lineHeight(18)
        .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
      Blank()
      Row() {
        Blank()
        this.buildEmotionIllustration(item.id)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('48%')
    .height(172)
    .padding(18)
    .margin({ bottom: 12 })
    .backgroundColor(this.selectedEmotionIndex === index ? '#F6FAFA' : WeiyuTheme.COLOR_SURFACE)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: this.selectedEmotionIndex === index ? 1.5 : 1, color: this.selectedEmotionIndex === index ? WeiyuTheme.COLOR_ACCENT : WeiyuTheme.COLOR_BORDER })
    .shadow({
      radius: 8,
      color: '#08000000',
      offsetX: 0,
      offsetY: 3
    })
    .opacity(this.selectedEmotionIndex < 0 || this.selectedEmotionIndex === index ? 1 : 0.9)
    .scale(this.selectedEmotionIndex === index ? { x: 1.01, y: 1.01 } : { x: 1, y: 1 })
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(`${item.title}，${item.subtitle}`)
    .onClick(() => {
      this.chooseEmotion(index);
    })
  }

  @Builder
  private buildBackHeader(title: string, subtitle: string) {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
        .width(WeiyuTheme.TOUCH_TARGET)
        .height(WeiyuTheme.TOUCH_TARGET)
        .textAlign(TextAlign.Center)
        .borderRadius(24)
        .accessibilityText('返回')
        .onClick(() => {
          if (this.currentPage === 'recipient') {
            this.playRecipientExitAnimation();
          } else if (this.currentPage === 'emotion') {
            this.recipientEntryFromHome = false;
            this.currentPage = 'recipient';
          } else if (this.currentPage === 'writing') {
            if (this.writingReturnPage === 'driftDetail' && this.recalledDriftOrigin) {
              this.activeEchoId = this.recalledDriftOrigin.id;
              this.driftPeek = false;
              this.currentPage = 'driftDetail';
            } else {
              this.currentPage = this.writingReturnPage;
            }
          } else if (this.currentPage === 'futureSchedule') {
            this.currentPage = 'ritual';
          } else if (this.currentPage === 'sparkConfirm') {
            this.currentPage = 'ritual';
          } else if (this.currentPage === 'driftDetail') {
            this.currentPage = this.contentReturnPage;
            this.initialDriftReceipt = false;
            this.driftPeek = false;
          } else if (this.currentPage === 'driftSparkConfirm') {
            this.currentPage = 'driftDetail';
          } else if (this.currentPage === 'ritual') {
            this.currentPage = 'writing';
          } else if (this.currentPage === 'echo') {
            this.currentPage = this.contentReturnPage;
          } else if (this.currentPage === 'archive' ||
            this.currentPage === 'sparkSky' || this.currentPage === 'driftSea') {
            this.currentPage = this.archiveReturnPage;
          } else {
            this.currentPage = 'home';
          }
        })

      Column({ space: 4 }) {
        Text(title)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
        if (subtitle.length > 0) {
          Text(subtitle)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 4 })

      Blank()
    }
    .width('100%')
    .padding({ left: 8, right: WeiyuTheme.PAGE_INSET, top: 14, bottom: 8 })
  }

  @Builder
  private buildPrimaryAction(label: string, background: string) {
    Row() {
      Blank()
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_WHITE)
      Blank()
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(background)
    .borderRadius(WeiyuTheme.RADIUS_CONTROL)
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(label)
  }

  @Builder
  private buildSecondaryAction(label: string) {
    Row() {
      Blank()
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
      Blank()
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(WeiyuTheme.COLOR_SURFACE_MUTED)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
    .borderRadius(WeiyuTheme.RADIUS_CONTROL)
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(label)
  }

  @Builder
  private buildMailboxCard(title: string, count: string, color: string, kind: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
      Text(count)
        .fontSize(12)
        .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
    }
    .alignItems(HorizontalAlign.Start)
    .width('48%')
    .height(108)
    .padding(18)
    .margin({ bottom: 12 })
    .backgroundColor(color)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: 1, color: '#DDE1DF' })
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(`${title}，${count}`)
    .onClick(() => {
      this.openArchive(kind);
    })
  }

  @Builder
  private buildHomeWriteCard() {
    Column() {
      Row({ space: 10 }) {
        Text(`${new Date().getDate()}`.padStart(2, '0'))
          .fontSize(34)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_ACCENT)
        Text(`${new Date().getFullYear()}年${new Date().getMonth() + 1}月`)
          .fontSize(17)
          .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Text('—')
        .fontSize(20)
        .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
        .width('100%')
        .margin({ top: 2 })

      Text('今天想说什么，\n就从第一句开始。')
        .fontSize(15)
        .lineHeight(25)
        .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
        .width('100%')
        .margin({ top: 10 })

      Blank()

      Image($r('app.media.home_hedgehog'))
        .width(184)
        .height(152)
        .objectFit(ImageFit.Contain)

      Blank()

      Row() {
        Blank()
        Text('写一封信')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_WHITE)
        Blank()
      }
      .width('72%')
      .padding({ top: 14, bottom: 14 })
      .backgroundColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
      .borderRadius(26)
      .hoverEffect(HoverEffect.Scale)
    }
    .width(292)
    .height(432)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 28, right: 28, top: 28, bottom: 28 })
    .backgroundColor(WeiyuTheme.COLOR_SURFACE)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
    .borderRadius(WeiyuTheme.RADIUS_HERO)
    .shadow({ radius: 18, color: '#10000000', offsetX: 0, offsetY: 7 })
    .opacity(this.homeEntryOpacity)
    .translate({ x: 0, y: this.homeEntryOffset })
    .onClick(() => {
      this.resetComposer();
      this.openComposer();
    })
    .accessibilityText('写一封信')
    .onAppear(() => {
      this.playHomeEntryAnimation();
    })
  }

  @Builder
  private buildRecentCard(item: LetterRecord) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        if ((item.photoUris ?? []).length > 0) {
          Image(item.photoUris[0])
            .width('100%')
            .height(314)
            .borderRadius({ topLeft: 24, topRight: 24 })
            .objectFit(ImageFit.Cover)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Image(this.getEmotionCover(item.emotion))
              .width(184)
              .height(174)
              .objectFit(ImageFit.Contain)
          }
            .width('100%')
            .height(314)
            .borderRadius({ topLeft: 24, topRight: 24 })
            .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
        }

        Row() {
          Column({ space: 4 }) {
            Text(item.title.trim().length > 0 ? item.title : '这一封信没有标题')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${item.date} · ${item.weekday}`)
              .fontSize(12)
              .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('...')
            .fontSize(18)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .padding({ left: 8, right: 8, top: 2, bottom: 8 })
            .onClick(() => {
              this.toggleDeleteMenu(item.id);
            })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 14 })
      }
      .width('100%')
      .height(432)
      .backgroundColor(WeiyuTheme.COLOR_SURFACE)
      .borderRadius(WeiyuTheme.RADIUS_CARD)
      .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
      .onClick(() => {
        this.enterEcho(item);
      })

      if (this.openedMenuId === item.id) {
        Column() {
          Text('删除')
            .fontSize(14)
            .fontColor('#9D6666')
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#FFFDFC')
        .borderRadius(14)
        .shadow({
          radius: 12,
          color: '#14000000',
          offsetX: 0,
          offsetY: 4
        })
        .margin({ top: 48, right: 18 })
        .onClick(() => {
          this.deleteRecord(item.id);
        })
      }
    }
    .width(292)
    .height(432)
    .shadow({ radius: 18, color: '#0E000000', offsetX: 0, offsetY: 7 })
    .hoverEffect(HoverEffect.Scale)
  }

  @Builder
  private buildEchoListCard(item: LetterRecord) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 12 }) {
        Row() {
          Text(item.date)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          Blank()
          Text(this.getRecordStatusLabel(item))
            .fontSize(12)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.getRecordStatusBackground(item))
            .borderRadius(12)
          Text('...')
            .fontSize(18)
            .fontColor('#7A7065')
            .padding({ left: 8, right: 2, top: 2, bottom: 8 })
            .onClick(() => {
              this.toggleDeleteMenu(item.id);
            })
        }
        .width('100%')

        Text(`${item.recipient} · ${item.emotion}`)
          .fontSize(12)
          .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)

        Text(this.getArchiveDisplayText(item))
          .fontSize(15)
          .lineHeight(24)
          .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
      .borderRadius(WeiyuTheme.RADIUS_CARD)
      .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
      .hoverEffect(HoverEffect.Scale)
      .onClick(() => {
        this.enterEcho(item);
      })

      if (this.openedMenuId === item.id) {
        Column() {
          Text('删除')
            .fontSize(14)
            .fontColor('#9D6666')
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#FFFDFC')
        .borderRadius(14)
        .shadow({
          radius: 12,
          color: '#14000000',
          offsetX: 0,
          offsetY: 4
        })
        .margin({ top: 42, right: 18 })
        .onClick(() => {
          this.deleteRecord(item.id);
        })
      }
    }
    .width('100%')
  }

  @Builder
  private buildStatCard(title: string, value: string, color: string) {
    Column({ space: 8 }) {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
      Text(title)
        .fontSize(13)
        .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
    }
    .width('50%')
    .padding(18)
    .backgroundColor(color)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
  }

  @Builder
  private buildEmptyState(title: string, subtitle: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
      Text(subtitle)
        .fontSize(13)
        .lineHeight(22)
        .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 42, bottom: 42, left: 20, right: 20 })
    .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
  }

  @Builder
  private buildHome() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 8 }) {
          Row() {
            Column({ space: 6 }) {
              Text('未语')
                .fontSize(30)
                .fontWeight(FontWeight.Medium)
                .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              Text('把想说的话，先留在这里。')
                .fontSize(14)
                .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Start)

            Blank()
          }
          .width('100%')

          Text(this.statusText)
            .fontSize(12)
            .lineHeight(19)
            .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18 })

        if (this.homeTab === 0) {
          Scroll() {
            Row({ space: 18 }) {
              this.buildHomeWriteCard()
              ForEach(this.getRecentLetters(6), (item: LetterRecord) => {
                this.buildRecentCard(item)
              }, (item: LetterRecord) => `recent-${item.id}`)
            }
            .width('max-content')
            .padding({ left: 20, right: 20, top: 8, bottom: 28 })
            .opacity(this.recentEntryOpacity)
            .translate({ x: 0, y: this.recentEntryOffset })
            .onAppear(() => {
              this.playRecentEntryAnimation();
            })
          }
          .width('100%')
          .height(500)
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .padding({ bottom: 24 })
        } else if (this.homeTab === 1) {
          Column({ space: 12 }) {
            Text('情绪回声')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .width('100%')

            Scroll() {
              Row({ space: 8 }) {
                ForEach(['all', '7d', '30d', 'year'], (filter: string) => {
                  Text(filter === 'all' ? '全部' : (filter === '7d' ? '近7天' : (filter === '30d' ? '近30天' : '今年')))
                    .fontSize(13)
                    .fontColor(this.echoTimeFilter === filter ? WeiyuTheme.COLOR_WHITE : WeiyuTheme.COLOR_TEXT_SECONDARY)
                    .height(44)
                    .padding({ left: 18, right: 18 })
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.echoTimeFilter === filter ? WeiyuTheme.COLOR_ACCENT_STRONG : WeiyuTheme.COLOR_SURFACE_MUTED)
                    .borderRadius(18)
                    .accessibilityText(`筛选：${filter === 'all' ? '全部' : (filter === '7d' ? '近7天' : (filter === '30d' ? '近30天' : '今年'))}`)
                    .onClick(() => {
                      this.echoTimeFilter = filter;
                    })
                }, (filter: string) => filter)
              }
              .width('max-content')
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            if (this.echoCards.length === 0) {
              this.buildEmptyState('还没有回声卡', '完成一封信后，这里会留下你的温柔回声。')
            } else if (this.getFilteredEchoCards().length === 0) {
              this.buildEmptyState('这个时间段还没有回声', '换一个时间范围，再看看曾经留下的心情。')
            } else {
              ForEach(this.getFilteredEchoCards(), (item: LetterRecord) => {
                this.buildEchoListCard(item)
              }, (item: LetterRecord) => `${item.id}`)
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 110 })
        } else {
          Column({ space: 14 }) {
            Text('我的空间')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              this.buildMailboxCard('草稿箱', `${this.drafts.length} 封草稿`, '#F5EFE7', 'draft')
              this.buildMailboxCard('封存的信', `${this.sealedLetters.length} 封信件`, '#F4EEE7', 'sealed')
              this.buildMailboxCard('未来信', `${this.getUnlockedFutureCount()} / ${this.futureLetters.length} 已开启`, '#F2F4F8', 'future')
              this.buildMailboxCard('漂流信', `${this.driftLetters.length} 封在海上 · 随时可捞起`, '#EAF0F6', 'drift')
              this.buildMailboxCard('光点星空', `${this.getCollectedSparks().length} 已点亮 · ${this.getPendingSparks().length} 待收下`, '#F9ECD8', 'spark')
              this.buildMailboxCard('情绪回声卡', `${this.echoCards.length} 张回声卡`, '#F5F1EA', 'echo')
            }
            .width('100%')

          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 110 })
        }
      }
      .width('100%')
    }
  }

  @Builder
  private buildRecipientPage() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('这封信，想写给谁？', '先想一个名字，再慢慢靠近。')

        Column({ space: 14 }) {
        ForEach(this.recipientOptions, (item: SelectItem, index: number) => {
          this.buildRecipientCard(item, index)
        }, (item: SelectItem) => item.id)

        if (this.selectedRecipientIndex >= 0 && this.recipientOptions[this.selectedRecipientIndex].id === 'custom') {
          Column({ space: 14 }) {
            TextInput({ text: this.customRecipient, placeholder: '例如：曾经的朋友、还没说出口的人' })
              .width('100%')
              .height(48)
              .fontSize(15)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .placeholderColor(WeiyuTheme.COLOR_TEXT_MUTED)
              .backgroundColor('#00FFFFFF')
              .padding({ left: 2, right: 2 })
              .maxLength(20)
              .onChange((value: string) => {
                this.customRecipient = value;
              })
            Divider()
              .strokeWidth(1)
              .color(WeiyuTheme.COLOR_ACCENT)
            Column() {
              this.buildPrimaryAction(this.customRecipient.trim().length > 0 ? '写给这个人' : '先写下收信人', WeiyuTheme.COLOR_ACCENT_STRONG)
            }
            .opacity(this.customRecipient.trim().length > 0 ? 1 : 0.56)
            .onClick(() => {
              this.confirmCustomRecipient();
            })
          }
          .width('100%')
          .padding({ left: 6, right: 6, top: 4, bottom: 6 })
        }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 40 })
      }
      .width('100%')
      .translate({ x: this.recipientPageOffset, y: 0 })
      .onAppear(() => {
        if (this.recipientEntryFromHome) {
          this.recipientEntryFromHome = false;
          this.playRecipientEntryAnimation();
        } else {
          this.recipientPageOffset = 0;
        }
      })
    }
  }

  @Builder
  private buildEmotionPage() {
    Scroll() {
      Column({ space: 14 }) {
        this.buildBackHeader('这张信纸，陪你写下什么？', '先给心情命名，再慢慢说。')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.emotionOptions, (item: SelectItem, index: number) => {
            this.buildEmotionCard(item, index)
          }, (item: SelectItem) => item.id)
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 28 })
        .opacity(this.emotionEntryOpacity)
        .translate({ x: 0, y: this.emotionEntryOffset })
        .onAppear(() => {
          this.playEmotionEntryAnimation();
        })
        .onDisAppear(() => {
          this.stopAllEmotionAnimations();
        })

        if (this.selectedEmotionIndex >= 0 && this.emotionOptions[this.selectedEmotionIndex].id === 'other') {
          Column({ space: 2 }) {
            TextInput({ text: this.customEmotion, placeholder: '此刻更贴切的心情是……' })
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .placeholderColor(WeiyuTheme.COLOR_TEXT_MUTED)
              .backgroundColor('#00FFFFFF')
              .padding({ left: 2, right: 2 })
              .maxLength(16)
              .onChange((value: string) => {
                this.customEmotion = value;
              })
            Divider()
              .strokeWidth(1)
              .color(WeiyuTheme.COLOR_ACCENT)
          }
          .width('100%')
          .padding({ left: 26, right: 26, bottom: 8 })
        }

        Row() {
          Blank()
          Row() {
            Blank()
            Text(this.emotionConfirmLabel)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedEmotionIndex >= 0 &&
                (this.emotionOptions[this.selectedEmotionIndex].id !== 'other' || this.customEmotion.trim().length > 0)
                ? WeiyuTheme.COLOR_WHITE : WeiyuTheme.COLOR_TEXT_MUTED)
            Blank()
          }
          .width('68%')
          .height(52)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.selectedEmotionIndex >= 0 &&
            (this.emotionOptions[this.selectedEmotionIndex].id !== 'other' || this.customEmotion.trim().length > 0)
            ? WeiyuTheme.COLOR_ACCENT_STRONG : WeiyuTheme.COLOR_SURFACE_MUTED)
          .borderRadius(WeiyuTheme.RADIUS_CONTROL)
          .border({ width: 1, color: this.selectedEmotionIndex >= 0 ? WeiyuTheme.COLOR_ACCENT : WeiyuTheme.COLOR_BORDER })
          .opacity(this.selectedEmotionIndex >= 0 &&
            (this.emotionOptions[this.selectedEmotionIndex].id !== 'other' || this.customEmotion.trim().length > 0) ? 1 : 0.72)
          .hoverEffect(HoverEffect.Scale)
          .accessibilityText(this.emotionConfirmLabel)
          .onClick(() => {
            this.confirmEmotionSelection();
          })
          Blank()
        }
        .width('100%')
        .margin({ left: 20, right: 20, bottom: 34 })
      }
      .width('100%')
    }
  }

  @Builder
  private buildWritingPage() {
    Column({ space: 8 }) {
      this.buildBackHeader(
        `写给${this.getSelectedRecipient().title.replace('写给', '')}`,
        `${this.getSelectedEmotion().title}会替你先垫住情绪。`
      )

      if (this.driftReflection.length > 0) {
        Text(this.driftReflection)
          .fontSize(13)
          .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
          .width('90%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(WeiyuTheme.COLOR_ACCENT_SOFT)
          .borderRadius(14)
      }

      Column({ space: 12 }) {
        TextInput({ text: this.letterTitle, placeholder: '给这封信写一个标题（选填）' })
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          .placeholderColor(WeiyuTheme.COLOR_TEXT_MUTED)
          .backgroundColor(WeiyuTheme.COLOR_SURFACE)
          .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
          .borderRadius(WeiyuTheme.RADIUS_CONTROL)
          .padding({ left: 18, right: 18 })
          .maxLength(30)
          .onChange((value: string) => {
            this.letterTitle = value;
          })

        Stack({ alignContent: Alignment.BottomEnd }) {
          TextArea({ text: this.letterContent, placeholder: '今天想说什么，就从第一句开始。' })
            .width('100%')
            .height('100%')
            .fontSize(18)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
            .placeholderColor(WeiyuTheme.COLOR_TEXT_MUTED)
            .backgroundColor(WeiyuTheme.COLOR_SURFACE)
            .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
            .borderRadius(28)
            .padding(20)
            .onChange((value: string) => {
              this.letterContent = value;
            })

          Text(`${this.letterContent.length} 字`)
            .fontSize(13)
            .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            .margin({ right: 22, bottom: 18 })
        }
        .width('100%')
        .layoutWeight(1)

        Row({ space: 10 }) {
          ForEach(this.photoUris, (uri: string, index: number) => {
            Stack({ alignContent: Alignment.TopEnd }) {
              Image(uri)
                .width(72)
                .height(72)
                .borderRadius(14)
                .objectFit(ImageFit.Cover)
              Text('×')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .width(22)
                .height(22)
                .textAlign(TextAlign.Center)
                .backgroundColor('#80534B43')
                .borderRadius(11)
                .onClick(() => {
                  this.removePhoto(index);
                })
            }
          }, (uri: string, index: number) => `${uri}-${index}`)

          Column({ space: 4 }) {
            Text('＋')
              .fontSize(26)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            Text('照片')
              .fontSize(12)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          }
          .width(72)
          .height(72)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(WeiyuTheme.COLOR_SURFACE_MUTED)
          .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
          .borderRadius(14)
          .hoverEffect(HoverEffect.Scale)
          .accessibilityText('添加照片')
          .onClick(() => {
            this.choosePhotos();
          })
        }
        .width('100%')
        .padding({ left: 4, right: 4 })

        Row({ space: 12 }) {
          Column() {
            this.buildSecondaryAction('保存草稿')
          }
          .width('48%')
          .onClick(() => {
            this.saveDraft();
          })

          Column() {
            this.buildPrimaryAction('继续安放', WeiyuTheme.COLOR_ACCENT)
          }
          .width('48%')
          .onClick(() => {
            this.goToRitual();
          })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 20, right: 20, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildRitualPage() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('这封信，你想如何安放？', '选择一种方式，把这封信安顿好。')
        Column({ space: 14 }) {
          ForEach(this.ritualOptions, (item: SelectItem, index: number) => {
            this.buildRitualCard(item, index)
          }, (item: SelectItem) => item.id)
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 30 })
        .opacity(this.ritualEntryOpacity)
        .translate({ x: 0, y: this.ritualEntryOffset })
        .onAppear(() => {
          this.playRitualEntryAnimation();
        })
      }
      .width('100%')
    }
  }

  @Builder
  private buildSparkConfirmPage() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('确认燃成光点？', '这是一种不可撤回的安放方式。')

        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(58)
              .height(58)
              .fill('#D8C7A1')
              .opacity(0.12)
            Circle()
              .width(22)
              .height(22)
              .fill('#D8C7A1')
          }
          .width('100%')
          .height(70)

          Text('确认后，信的正文和照片会被永久清除。')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
            .width('100%')
            .textAlign(TextAlign.Center)

          Text('系统只会留下写信日期、情绪、标题和一束温柔回声，原文与照片之后无法找回。')
            .fontSize(14)
            .lineHeight(24)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .width('100%')
            .textAlign(TextAlign.Center)

          Divider()
            .strokeWidth(1)
            .color(WeiyuTheme.COLOR_BORDER)
            .margin({ top: 4, bottom: 2 })

          Column({ space: 8 }) {
            Text('留下一句余光（选填）')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .width('100%')
            TextInput({
              text: this.sparkAfterglow,
              placeholder: '例如：答案还没出现，但我已经开始向前。'
            })
              .width('100%')
              .height(50)
              .fontSize(15)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .placeholderColor(WeiyuTheme.COLOR_TEXT_MUTED)
              .backgroundColor(WeiyuTheme.COLOR_SURFACE)
              .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
              .borderRadius(WeiyuTheme.RADIUS_CONTROL)
              .padding({ left: 16, right: 16 })
              .maxLength(50)
              .onChange((value: string) => {
                this.sparkAfterglow = value;
              })
            Text('原文会消失，这句话会替它留在星空里。')
              .fontSize(12)
              .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 28, bottom: 28 })
        .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
        .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
        .borderRadius(28)

        Column({ space: 12 }) {
          Column() {
            this.buildPrimaryAction('确认燃成光点', '#B98963')
          }
          .onClick(() => {
            this.confirmSparkRitual();
          })

          Column() {
            this.buildSecondaryAction('再想一想')
          }
          .onClick(() => {
            this.currentPage = 'ritual';
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 30 })
    }
  }

  @Builder
  private buildFutureSchedulePage() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('寄给未来', '选一个具体日期，到那天我再提醒你打开。')

        Column({ space: 16 }) {
          Text('未来开启日期')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
            .width('100%')

          DatePicker({
            start: this.getMinimumFutureDate(),
            end: new Date('2036-12-31'),
            selected: this.futureReminderDate
          })
            .width('100%')
            .height(210)
            .backgroundColor(WeiyuTheme.COLOR_SURFACE)
            .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
            .borderRadius(WeiyuTheme.RADIUS_CARD)
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .onDateChange((value: Date) => {
              this.futureReminderDate = value;
            })

          Column({ space: 8 }) {
            Text('系统会在下面这个时间提醒你：')
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              .width('100%')
            Text(this.formatDateTime(this.getFutureReminderMoment(this.futureReminderDate)))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .width('100%')
            Text('默认在当天 09:00 自动弹通知，到了时间这封未来信也会解锁。')
              .fontSize(12)
              .lineHeight(20)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              .width('100%')
            Text(this.getFuturePermissionHint())
              .fontSize(12)
              .lineHeight(20)
              .fontColor(this.futureNotificationEnabled ? '#6E8E76' : '#A07E6B')
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
          .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
          .borderRadius(WeiyuTheme.RADIUS_CARD)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        if (!this.futureNotificationEnabled) {
          Column() {
            this.buildSecondaryAction('打开通知设置')
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          .onClick(() => {
            this.openFutureReminderSettings();
          })
        }

        Row({ space: 12 }) {
          Column() {
            this.buildSecondaryAction('返回上一页')
          }
          .width('48%')
          .onClick(() => {
            this.currentPage = 'ritual';
          })

          Column() {
            this.buildPrimaryAction('寄给未来', WeiyuTheme.COLOR_ACCENT)
          }
          .width('48%')
          .onClick(() => {
            this.confirmFutureDelivery();
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 30 })
      }
      .width('100%')
      .onAppear(() => {
        this.refreshNotificationPermissionStatus();
      })
    }
  }

  @Builder
  private buildEchoPage() {
    Scroll() {
      Column({ space: 14 }) {
        this.buildBackHeader(
          this.getEchoPageTitle(this.getActiveEcho()),
          this.getEchoPageSubtitle(this.getActiveEcho())
        )

        if (this.getActiveEcho().ritual === '燃成光点') {
          Column({ space: 18 }) {
            Circle()
              .width(32)
              .height(32)
              .fill(this.getSparkColor(this.getActiveEcho().emotion))
              .borderRadius(50)
              .shadow({ radius: 36, color: this.getSparkColor(this.getActiveEcho().emotion), offsetX: 0, offsetY: 0 })
              .scale({ x: this.sparkScale, y: this.sparkScale })
              .opacity(this.sparkOpacity)
            Text(this.collectingSpark ? '正在飞往你的星空…' : (this.isSparkCollected(this.getActiveEcho().id) ? '这颗光，已经在你的星空里。' : '把这一点光，留给往后的自己。'))
              .fontSize(14)
              .fontColor('#DCD6D1')
            Text(this.getActiveEcho().echoLine)
              .fontSize(12)
              .fontColor('#A6A8B8')
          }
          .width('100%')
          .padding({ top: 44, bottom: 32, left: 16, right: 16 })
          .linearGradient({
            angle: 150,
            colors: [['#22293D', 0.0], ['#293149', 0.58], ['#242C42', 1.0]]
          })
          .borderRadius(28)
        }

        Column({ space: 10 }) {
          Text(this.getActiveEcho().date)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
            .width('100%')
          Text(this.getActiveEcho().weekday)
            .fontSize(12)
            .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            .width('100%')

          Row({ space: 8 }) {
            Text('情绪：')
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            Text(this.getActiveEcho().emotion)
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            Text('方式：')
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            Text(this.getActiveEcho().ritual)
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          }
          .width('100%')

          Text('关键词：' + this.getActiveEcho().keywords.join(' / '))
            .fontSize(13)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .width('100%')

          Text(this.getActiveEcho().ritualHint)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .width('100%')

          if (this.getActiveEcho().ritual !== '燃成光点') {
            Text(this.getEchoContentLabel(this.getActiveEcho()))
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              .width('100%')

            Text(this.getDisplayedContent(this.getActiveEcho()))
              .fontSize(17)
              .lineHeight(28)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              .width('100%')

            Text('温柔回声：')
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              .width('100%')

            Text(this.getActiveEcho().echoLine)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              .width('100%')
          }

        }
        .width('100%')
        .padding(20)
        .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
        .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
        .borderRadius(28)

        Column({ space: 12 }) {
          if (this.getActiveEcho().ritual === '漂流') {
            Column() {
              this.buildPrimaryAction('捡回来继续写', '#97AEC3')
            }
            .onClick(() => {
              this.recallDriftLetter(this.getActiveEcho());
            })

            Column() {
              this.buildSecondaryAction('先让它继续漂流')
            }
            .onClick(() => {
              this.currentPage = 'home';
            })
          } else {
            Column() {
              this.buildPrimaryAction(
                this.getActiveEcho().ritual === '燃成光点'
                  ? (this.collectingSpark ? '正在点亮星空…' : (this.isSparkCollected(this.getActiveEcho().id) ? '已收下 · 去星空看看' : '收下这颗光点'))
                  : '保存回声卡',
                WeiyuTheme.COLOR_ACCENT
              )
            }
            .onClick(() => {
              if (this.getActiveEcho().ritual === '燃成光点') {
                this.collectActiveSpark();
                return;
              }
              this.homeTab = 1;
              this.currentPage = 'home';
              this.statusText = this.getActiveEcho().ritual === '燃成光点'
                ? '这颗光点已经留在你的星空里。'
                : '回声卡已经留在你的信箱里。';
            })

            Column() {
              this.buildSecondaryAction('返回信箱')
            }
            .onClick(() => {
              this.currentPage = 'home';
            })
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 24 })
    }
  }

  @Builder
  private buildSparkSky() {
    Scroll() {
      Column({ space: 20 }) {
        this.buildBackHeader('光点星空', '那些放下的心事，成了陪伴你的光。')
        Column({ space: 0 }) {
          Column({ space: 10 }) {
            Text('属于你的微光')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#E8E5DE')
              .width('100%')
            Row({ space: 7 }) {
              Text(`${this.getCollectedSparks().length}`)
                .fontSize(30)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F7F0E3')
              Text('颗心事，已化作星光')
                .fontSize(14)
                .fontColor('#B8BECD')
                .margin({ bottom: 3 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Bottom)
            Text('它们不再讲述原来的故事，只安静留下那一刻的心情。')
              .fontSize(12)
              .lineHeight(19)
              .fontColor('#8F97AD')
              .width('100%')
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 20 })

          if (this.getCollectedSparks().length === 0) {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(44)
                .height(44)
                .fill('#D8C7A1')
                .opacity(0.08)
              Circle()
                .width(12)
                .height(12)
                .fill('#D8C7A1')
                .opacity(0.82)
            }
            .width(52)
            .height(52)
            .margin({ top: 34, bottom: 16 })
            Text('星空还在等第一束光\n收下一颗光点，它就会在这里亮起。')
              .fontSize(14)
              .lineHeight(23)
              .textAlign(TextAlign.Center)
              .fontColor('#B9BFCE')
          } else {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.getCollectedSparks(), (item: LetterRecord, index: number) => {
                Column({ space: 12 }) {
                  Stack({ alignContent: Alignment.Center }) {
                    if (this.selectedSparkId === item.id) {
                      Circle()
                        .width(44)
                        .height(44)
                        .fill(this.getSparkColor(item.emotion))
                        .opacity(this.selectedSparkGlowOpacity * 0.18)
                        .scale({ x: this.selectedSparkGlowScale, y: this.selectedSparkGlowScale })
                      Circle()
                        .width(30)
                        .height(30)
                        .fill(this.getSparkColor(item.emotion))
                        .opacity(this.selectedSparkGlowOpacity * 0.34)
                        .scale({ x: this.selectedSparkGlowScale, y: this.selectedSparkGlowScale })
                    }
                    Circle()
                      .width(this.selectedSparkId === item.id ? 21 : this.getSparkVisualSize(index))
                      .height(this.selectedSparkId === item.id ? 21 : this.getSparkVisualSize(index))
                      .fill(this.getSparkColor(item.emotion))
                      .opacity(this.selectedSparkId === item.id ? 1 : this.getSparkVisualOpacity(index))
                  }
                  .width(48)
                  .height(48)
                  Text(this.selectedSparkId === item.id ? '这一束光' : item.emotion)
                    .fontSize(12)
                    .fontWeight(this.selectedSparkId === item.id ? FontWeight.Medium : FontWeight.Regular)
                    .fontColor(this.selectedSparkId === item.id ? '#EEE9DE' : '#B3B9C9')
                }
                .width('25%')
                .height(108)
                .justifyContent(FlexAlign.Center)
                .translate({ y: this.getSparkVisualOffset(index) })
                .onClick(() => {
                  this.glowSelectedSpark(item.id);
                })
              }, (item: LetterRecord) => `star-${item.id}`)
            }
            .width('100%')
            .padding({ top: 12, bottom: 22 })

            Column({ space: 5 }) {
              Text('轻触一束光')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#D1D5E0')
              Text('看看它曾经承接的心情')
                .fontSize(12)
                .fontColor('#A2A9BA')
            }
            .width('100%')
            .padding({ top: 13, bottom: 3 })
            .border({ width: { top: 1 }, color: '#343C54' })
          }
        }
        .width('100%')
        .padding({ top: 30, bottom: 26, left: 16, right: 16 })
        .linearGradient({
          angle: 155,
          colors: [['#20263A', 0.0], ['#293149', 0.54], ['#222A40', 1.0]]
        })
        .borderRadius(28)

        ForEach(this.getCollectedSparks().filter((item: LetterRecord) => item.id === this.selectedSparkId), (item: LetterRecord) => {
          Column({ space: 12 }) {
            Text(`${item.date} · ${item.emotion}`)
              .fontSize(13)
              .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            Text(item.title.length > 0 ? item.title : '一颗没有名字的光')
              .fontSize(19)
              .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
            Text(item.echoLine)
              .fontSize(16)
              .lineHeight(26)
              .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .padding(22)
          .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
          .borderRadius(WeiyuTheme.RADIUS_CARD)
          .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
        }, (item: LetterRecord) => `selected-${item.id}`)

        if (this.getPendingSparks().length > 0) {
          Text('还有微光，等你收下')
            .fontSize(16)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .width('100%')
          ForEach(this.getPendingSparks(), (item: LetterRecord) => {
            Row() {
              Text(`${item.date} · ${item.emotion}`)
                .fontSize(14)
                .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              Blank()
              Text('去收下  ›')
                .fontSize(14)
                .fontColor('#8B684D')
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#F6ECDD')
            .borderRadius(20)
            .border({ width: 1, color: '#E8D9C2' })
            .hoverEffect(HoverEffect.Scale)
            .onClick(() => {
              this.enterEcho(item);
            })
          }, (item: LetterRecord) => `pending-${item.id}`)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 30 })
    }
  }

  @Builder
  private buildDriftBottle(returned: boolean, large: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.getDriftHedgehogFrame())
        .width(large ? 252 : 266)
        .height(large ? 252 : 266)
        .objectFit(ImageFit.Contain)
        .accessibilityText('小刺猬正划着小船，陪这封信慢慢漂流')
    }
    .width('100%')
    .height(large ? 224 : 248)
    .rotate({ angle: (returned ? -1 : 0) + this.driftFloatAngle })
    .scale({ x: this.driftBottleScale, y: this.driftBottleScale })
    .translate({ x: this.driftBottleOffset, y: this.driftFloatY })
      .opacity(this.driftBottleOpacity)
  }

  @Builder
  private buildDriftSeaScene(record: LetterRecord, large: boolean) {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 8 }) {
          Circle()
            .width(6)
            .height(6)
            .fill(WeiyuTheme.COLOR_ACCENT)
          Text(this.getDriftStage(record))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
        }
        Blank()
        Text(this.getDriftAgeLabel(record))
          .fontSize(12)
          .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
      }
      .width('100%')
      .height(40)
      .padding({ left: 14, right: 14 })
      .backgroundColor(WeiyuTheme.COLOR_ACCENT_SOFT)
      .borderRadius(16)

      this.buildDriftBottle(this.isDriftReturned(record), large)

      Column({ space: 6 }) {
        Text(this.getDriftJourneyLine(record))
          .fontSize(large ? 20 : 15)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          .textAlign(TextAlign.Center)
        Text(this.getDriftRemainingLabel(record))
          .fontSize(13)
          .lineHeight(20)
          .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ bottom: 2 })
  }

  @Builder
  private buildDriftMoodOption(mood: string, index: number) {
    Row({ space: 8 }) {
      Text(mood)
        .fontSize(14)
        .fontWeight(this.driftMoodIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.driftMoodIndex === index ? WeiyuTheme.COLOR_WHITE : WeiyuTheme.COLOR_TEXT_SECONDARY)
      Blank()
      if (this.driftMoodIndex === index) {
        Text('已选')
          .fontSize(11)
          .fontColor('#EAF2F3')
      }
    }
    .width(index === 4 ? '100%' : '48%')
    .height(50)
    .padding({ left: 16, right: 14 })
    .margin({ bottom: 10 })
    .backgroundColor(this.driftMoodIndex === index ? WeiyuTheme.COLOR_ACCENT_STRONG : WeiyuTheme.COLOR_ACCENT_SOFT)
    .borderRadius(16)
    .border({ width: 1, color: this.driftMoodIndex === index ? WeiyuTheme.COLOR_ACCENT_STRONG : '#D8E4E5' })
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(`此刻心情：${mood}${this.driftMoodIndex === index ? '，已选择' : ''}`)
    .onClick(() => {
      this.driftMoodIndex = index;
      if (index !== 4) {
        this.driftCustomMood = '';
      }
    })
  }

  @Builder
  private buildDriftLetterCard(record: LetterRecord) {
    Column({ space: 0 }) {
      Row() {
        Text(this.getDriftStage(record))
          .fontSize(12)
          .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(WeiyuTheme.COLOR_SURFACE_MUTED)
          .borderRadius(14)
        Blank()
        Text(this.getDriftAgeLabel(record))
          .fontSize(12)
          .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
      }
      .width('100%')

      Column({ space: 8 }) {
        Text(record.title.trim().length > 0 ? record.title : '一封没有标题的漂流信')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          .lineHeight(26)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.getDriftJourneyLine(record))
          .fontSize(14)
          .lineHeight(22)
          .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 20, bottom: 18 })

      Divider()
        .strokeWidth(1)
        .color(WeiyuTheme.COLOR_BORDER)
        .margin({ bottom: 14 })

      Row() {
        Text(`${record.date} · ${record.emotion}`)
          .fontSize(12)
          .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
        Blank()
        Text(this.isDriftReturned(record) ? '已经靠岸  ›' : '靠近看看  ›')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
      }
      .height(24)
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
    .borderRadius(WeiyuTheme.RADIUS_CARD)
    .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
    .hoverEffect(HoverEffect.Scale)
    .accessibilityText(`${record.title.trim().length > 0 ? record.title : '一封没有标题的漂流信'}，${this.getDriftAgeLabel(record)}`)
    .onClick(() => {
      this.enterEcho(record);
    })
  }

  @Builder
  private buildDriftSea() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('漂流海', '时间不替你决定，只帮你拉开一点距离。')
        Column({ space: 6 }) {
          Text(`${this.driftLetters.length} 封漂流信`)
            .fontSize(26)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          Text('它们都在海上，想靠近时随时可以捞起。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.driftLetters.length === 0) {
          this.buildEmptyState('海面还是空的', '写一封信，选择漂流，让它暂时离开岸边。')
        } else {
          ForEach(this.driftLetters, (item: LetterRecord) => {
            this.buildDriftLetterCard(item)
          }, (item: LetterRecord) => `drift-${item.id}`)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 35 })
    }
  }

  @Builder
  private buildDriftDetail() {
    Scroll() {
      Column({ space: 20 }) {
        this.buildBackHeader(this.isDriftReturned(this.getActiveEcho()) ? '漂流信回到了岸边' : '去看看漂流中的它', '')

        Column({ space: 16 }) {
          this.buildDriftSeaScene(this.getActiveEcho(), true)

          if (this.initialDriftReceipt) {
            Column() {
              this.buildPrimaryAction('保存这张漂流回声卡', WeiyuTheme.COLOR_ACCENT_STRONG)
            }
            .onClick(() => {
              this.initialDriftReceipt = false;
              this.homeTab = 1;
              this.currentPage = 'home';
              this.statusText = '回声卡已经保存到回声里了。';
            })
          } else if (!this.driftPeek) {
            Column({ space: 10 }) {
              Column() {
                this.buildPrimaryAction('捞起来看看', WeiyuTheme.COLOR_ACCENT_STRONG)
              }
              .onClick(() => {
                this.driftPeek = true;
              })
              Text('只是靠近读一读，不会结束漂流，也不会改变原信。')
                .fontSize(12)
                .lineHeight(18)
                .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
                .width('100%')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
          } else {
            Row({ space: 8 }) {
              Circle()
                .width(6)
                .height(6)
                .fill(WeiyuTheme.COLOR_ACCENT)
              Text('信已经展开，轻触下方信纸可以收起')
                .fontSize(12)
                .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            }
            .height(40)
            .padding({ left: 14, right: 14 })
            .backgroundColor(WeiyuTheme.COLOR_ACCENT_SOFT)
            .borderRadius(16)
          }
        }
        .width('100%')
        .padding(18)
        .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
        .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
        .borderRadius(WeiyuTheme.RADIUS_HERO)

        if (!this.initialDriftReceipt) {
          if (this.driftPeek) {
            Column({ space: 14 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('瓶中那封信')
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
                  Text('读完以后，它仍会留在海上')
                    .fontSize(12)
                    .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text('收起')
                  .fontSize(12)
                  .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
              }
              .width('100%')
              Text(this.getActiveEcho().title.trim().length > 0 ? this.getActiveEcho().title : '一封没有标题的信')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
              Text(this.getActiveEcho().content)
                .fontSize(16)
                .lineHeight(27)
                .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              ForEach(this.getActiveEcho().photoUris, (uri: string) => {
                Image(uri)
                  .width('100%')
                  .height(190)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(16)
              }, (uri: string) => uri)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(22)
            .backgroundColor(WeiyuTheme.COLOR_SURFACE)
            .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
            .borderRadius(WeiyuTheme.RADIUS_CARD)
            .hoverEffect(HoverEffect.Scale)
            .accessibilityText('已经展开的漂流信，轻触收起')
            .onClick(() => {
              this.driftPeek = false;
            })
          }

          Column({ space: 16 }) {
            Column({ space: 6 }) {
              Text('此刻的你，感觉怎样？')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              Text('不用急着变好，只选最接近此刻的一种。')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              ForEach(['轻松些了', '仍有点难过', '平静了', '还说不清', '其他'], (mood: string, index: number) => {
                this.buildDriftMoodOption(mood, index)
              }, (mood: string) => mood)
            }

            if (this.driftMoodIndex === 4) {
              Column({ space: 4 }) {
                Text('把更贴切的感觉写下来')
                  .fontSize(12)
                  .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
                  .width('100%')
                TextInput({ text: this.driftCustomMood, placeholder: '例如：终于能轻轻放下一点了' })
                  .width('100%')
                  .height(48)
                  .fontSize(14)
                  .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
                  .placeholderColor(WeiyuTheme.COLOR_TEXT_MUTED)
                  .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
                  .border({ width: 1, color: '#D8E4E5' })
                  .borderRadius(14)
                  .padding({ left: 14, right: 14 })
                  .maxLength(18)
                  .onChange((value: string) => {
                    this.driftCustomMood = value;
                  })
              }
              .width('100%')
            }

            Row() {
              Blank()
              Text(this.hasCurrentDriftMood() ? '把这封信带回岸边' : '选择一种感受，再带它回岸')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.hasCurrentDriftMood() ? WeiyuTheme.COLOR_WHITE : WeiyuTheme.COLOR_ACCENT_STRONG)
              Blank()
            }
            .width('100%')
            .height(52)
            .backgroundColor(this.hasCurrentDriftMood() ? WeiyuTheme.COLOR_ACCENT_STRONG : WeiyuTheme.COLOR_ACCENT_SOFT)
            .border({ width: 1, color: this.hasCurrentDriftMood() ? WeiyuTheme.COLOR_ACCENT_STRONG : '#D8E4E5' })
            .borderRadius(WeiyuTheme.RADIUS_CONTROL)
            .hoverEffect(HoverEffect.Scale)
            .accessibilityText(this.hasCurrentDriftMood() ? '把这封信带回岸边' : '请先选择此刻的心情')
            .onClick(() => {
              if (this.hasCurrentDriftMood()) {
                this.recallDriftLetter(this.getActiveEcho());
              } else {
                this.statusText = this.driftMoodIndex === 4 ? '写下此刻的感觉，再把信带回岸边。' : '先选一个此刻的心情，再把信带回岸边。';
              }
            })

            Text('带回时会保留正文、照片，也会记住这一次心情的变化。')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(20)
          .backgroundColor(WeiyuTheme.COLOR_SURFACE)
          .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
          .borderRadius(WeiyuTheme.RADIUS_CARD)

          Column({ space: 12 }) {
            Column({ space: 4 }) {
              Text('还想怎么安放它？')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
              Text('如果还没准备好面对，就让海风再替你保管一会儿。')
                .fontSize(12)
                .lineHeight(18)
                .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.buildSecondaryAction(this.isDriftReturned(this.getActiveEcho()) ? '再次放回远海' : '先让它继续漂流')
            }
            .onClick(() => {
              if (this.isDriftReturned(this.getActiveEcho())) {
                this.continueDrift(this.getActiveEcho());
              } else {
                this.currentPage = 'driftSea';
              }
            })

            Divider()
              .strokeWidth(1)
              .color(WeiyuTheme.COLOR_BORDER)
              .margin({ top: 4 })

            Row({ space: 12 }) {
              Column({ space: 3 }) {
                Text('让它化成一束光')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(WeiyuTheme.COLOR_DANGER)
                Text('永久清除正文与照片，只留下余光')
                  .fontSize(12)
                  .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Text('›')
                .fontSize(22)
                .fontColor(WeiyuTheme.COLOR_DANGER)
            }
            .width('100%')
            .height(58)
            .padding({ left: 4, right: 4 })
            .hoverEffect(HoverEffect.Scale)
            .accessibilityText('让它化成一束光，永久清除正文与照片')
            .onClick(() => {
              this.currentPage = 'driftSparkConfirm';
            })
          }
          .width('100%')
          .padding(20)
          .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
          .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
          .borderRadius(WeiyuTheme.RADIUS_CARD)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 36 })
      .opacity(this.driftDetailEntryOpacity)
      .translate({ x: 0, y: this.driftDetailEntryOffset })
      .onAppear(() => {
        this.startDriftMotion();
        this.startDriftHedgehogAnimation();
        this.playDriftDetailEntryAnimation();
      })
      .onDisAppear(() => {
        this.stopDriftMotion();
        this.stopDriftHedgehogAnimation();
      })
    }
  }

  @Builder
  private buildDriftSparkConfirm() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('让它化成光点？', '这一步不能撤回。')
        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(58)
              .height(58)
              .fill('#D8AB80')
              .opacity(0.12)
            Circle()
              .width(20)
              .height(20)
              .fill('#D8AB80')
          }
          .width(70)
          .height(70)
          Text('漂流结束，留下这一点光')
            .fontSize(21)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          Text('确认后，信的正文与照片会被永久清除。日期、情绪和温柔回声会留下，你可以把光点收入星空。')
            .fontSize(14)
            .lineHeight(24)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(27)
        .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
        .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
        .borderRadius(28)
        Column() {
          this.buildPrimaryAction('确认化成光点', '#B98963')
        }
        .onClick(() => {
          this.convertDriftToSpark(this.getActiveEcho());
        })
        Column() {
          this.buildSecondaryAction('让它再等等')
        }
        .onClick(() => {
          this.currentPage = 'driftDetail';
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 30 })
    }
  }

  @Builder
  private buildArchivePage() {
    Scroll() {
      Column({ space: 14 }) {
        this.buildBackHeader(this.getArchiveTitle(), this.getArchiveSubtitle())
        if (this.getArchiveItems().length === 0) {
          this.buildEmptyState('这里还空着', '先去写下一封信，这里会慢慢被填满。')
        } else {
          ForEach(this.getArchiveItems(), (item: LetterRecord) => {
            Column({ space: 10 }) {
              Row() {
                Text(item.date)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
                Blank()
                Stack({ alignContent: Alignment.TopEnd }) {
                  Text(this.getRecordStatusLabel(item))
                    .fontSize(12)
                    .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(this.getRecordStatusBackground(item))
                    .borderRadius(12)
                  if (this.archiveKind !== 'draft') {
                    Text('...')
                      .fontSize(18)
                      .fontColor('#7A7065')
                      .padding({ left: 6, right: 2, top: 2, bottom: 8 })
                      .onClick(() => {
                        this.toggleDeleteMenu(item.id);
                      })
                  }
                  if (this.archiveKind !== 'draft' && this.openedMenuId === item.id) {
                    Column() {
                      Text('删除')
                        .fontSize(14)
                        .fontColor('#9D6666')
                    }
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .backgroundColor('#FFFDFC')
                    .borderRadius(14)
                    .shadow({
                      radius: 12,
                      color: '#14000000',
                      offsetX: 0,
                      offsetY: 4
                    })
                    .margin({ top: 30, right: 2 })
                    .onClick(() => {
                      this.deleteRecord(item.id);
                    })
                  }
                }
              }
              .width('100%')

              Text(`${item.recipient} · ${item.emotion}`)
                .fontSize(12)
                .fontColor(WeiyuTheme.COLOR_TEXT_MUTED)
                .width('100%')

              Text(this.getArchiveDisplayText(item))
                .fontSize(15)
                .lineHeight(24)
                .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')

              if (this.archiveKind === 'draft') {
                Text('继续编辑')
                  .fontSize(13)
                  .fontColor('#97AEC3')
                  .width('100%')
              } else if (this.archiveKind === 'drift') {
                Row() {
                  Text(this.getDriftAgeLabel(item))
                    .fontSize(12)
                    .fontColor('#8A8178')
                  Blank()
                  Text('捡回来继续写')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .backgroundColor('#97AEC3')
                    .borderRadius(14)
                    .onClick(() => {
                      this.recallDriftLetter(item);
                    })
                }
                .width('100%')
              } else if (this.archiveKind !== 'spark') {
                Text(item.echoLine)
                  .fontSize(12)
                  .fontColor('#8A8178')
                  .width('100%')
              }
            }
            .width('100%')
            .padding(18)
            .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
            .borderRadius(WeiyuTheme.RADIUS_CARD)
            .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
            .hoverEffect(HoverEffect.Scale)
            .onClick(() => {
              if (this.archiveKind === 'draft') {
                this.continueDraft(item);
              } else if (this.archiveKind !== 'drift') {
                this.enterEcho(item);
              }
            })
          }, (item: LetterRecord) => `${item.id}`)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 30 })
    }
  }

  @Builder
  private buildBottomTab(icon: string, label: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(19)
        .lineHeight(22)
        .height(24)
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.homeTab === index ? WeiyuTheme.COLOR_ACCENT_STRONG : WeiyuTheme.COLOR_TEXT_MUTED)
      Text(label)
        .fontSize(12)
        .lineHeight(18)
        .height(20)
        .width('100%')
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .fontWeight(this.homeTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.homeTab === index ? WeiyuTheme.COLOR_ACCENT_STRONG : WeiyuTheme.COLOR_TEXT_MUTED)
    }
    .width('100%')
    .height(60)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.homeTab === index ? WeiyuTheme.COLOR_ACCENT_SOFT : '#00FFFFFF')
    .borderRadius(18)
    .accessibilityText(label)
    .onClick(() => {
      this.homeTab = index;
      this.currentPage = 'home';
    })
  }

  @Builder
  private buildBottomBar() {
    Row({ space: 8 }) {
      Column() {
        this.buildBottomTab('⌂', '信箱', 0)
      }
      .layoutWeight(1)
      .height(60)
      Column() {
        this.buildBottomTab('◉', '回声', 1)
      }
      .layoutWeight(1)
      .height(60)
      Column() {
        this.buildBottomTab('○', '我的', 2)
      }
      .layoutWeight(1)
      .height(60)
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 8, bottom: 14 })
    .backgroundColor(WeiyuTheme.COLOR_SURFACE)
    .border({ width: { top: 1 }, color: WeiyuTheme.COLOR_BORDER })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.currentPage === 'home') {
          this.buildHome()
        } else if (this.currentPage === 'recipient') {
          this.buildRecipientPage()
        } else if (this.currentPage === 'emotion') {
          this.buildEmotionPage()
        } else if (this.currentPage === 'writing') {
          this.buildWritingPage()
        } else if (this.currentPage === 'ritual') {
          this.buildRitualPage()
        } else if (this.currentPage === 'sparkConfirm') {
          this.buildSparkConfirmPage()
        } else if (this.currentPage === 'futureSchedule') {
          this.buildFutureSchedulePage()
        } else if (this.currentPage === 'sparkSky') {
          this.buildSparkSky()
        } else if (this.currentPage === 'driftSea') {
          this.buildDriftSea()
        } else if (this.currentPage === 'driftDetail') {
          this.buildDriftDetail()
        } else if (this.currentPage === 'driftSparkConfirm') {
          this.buildDriftSparkConfirm()
        } else if (this.currentPage === 'archive') {
          this.buildArchivePage()
        } else {
          this.buildEchoPage()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(WeiyuTheme.COLOR_BACKGROUND)

      if (this.currentPage === 'home') {
        this.buildBottomBar()
      }

    }
    .width('100%')
    .height('100%')
  }
}

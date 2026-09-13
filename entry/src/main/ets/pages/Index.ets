import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface SelectItem {
  id: string;
  title: string;
  subtitle: string;
  emoji: string;
  color: string;
}

interface LetterRecord {
  id: number;
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
  moodTag: string;
  anonymous: boolean;
  unlockDate: string;
  unlockAt: number;
  reminderId: number;
}

interface StoredLetterState {
  drafts: Array<LetterRecord>;
  sealedLetters: Array<LetterRecord>;
  futureLetters: Array<LetterRecord>;
  driftLetters: Array<LetterRecord>;
  echoCards: Array<LetterRecord>;
  nextId: number;
  activeEchoId: number;
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
    { id: 'drift', title: '漂流', subtitle: '把信放入云朵，让它随风慢慢漂走', emoji: '☁️', color: '#EAF0F6' },
    { id: 'future', title: '寄给未来', subtitle: '把愿望留给未来的自己开启', emoji: '🗓', color: '#F4EEE4' }
  ];
  private readonly letterStoreName: string = 'weiyu_letter_store';
  private readonly letterStoreKey: string = 'letters_payload';
  private readonly futureReminderHour: number = 9;
  private readonly appBundleName: string = 'com.example.weiyu';

  @State private currentPage: string = 'home';
  @State private homeTab: number = 0;
  @State private archiveKind: string = 'draft';
  @State private selectedRecipientIndex: number = -1;
  @State private selectedEmotionIndex: number = -1;
  @State private emotionConfirmLabel: string = '是什么呢';
  @State private letterContent: string = '';
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
  @State private openedMenuId: number = -1;
  @State private homeEntryOffset: number = 18;
  @State private homeEntryOpacity: number = 0;
  @State private recipientEntryOffset: number = 18;
  @State private recipientEntryOpacity: number = 0;
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
      return;
    }

    if (this.restoreStoredLetters()) {
      this.initialized = true;
      return;
    }

    const draft: LetterRecord = {
      id: 1,
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
      reminderId: 0
    };
    const echo: LetterRecord = {
      id: 2,
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
      reminderId: 0
    };

    this.drafts = [draft];
    this.sealedLetters = [echo];
    this.echoCards = [echo];
    this.activeEchoId = echo.id;
    this.persistLetters();
    this.initialized = true;
  }

  aboutToDisappear(): void {
    this.stopAllEmotionAnimations();
    this.stopUnlockWatcher();
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
      unlockDate: record.unlockDate ?? '',
      unlockAt: record.unlockAt ?? 0,
      reminderId: record.reminderId ?? 0
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
      activeEchoId: this.activeEchoId
    };
    store.putSync(this.letterStoreKey, JSON.stringify(snapshot));
    store.flush().catch((_err: BusinessError) => {
    });
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
    return this.recipientOptions[this.selectedRecipientIndex];
  }

  private getSelectedEmotion(): SelectItem {
    if (this.selectedEmotionIndex < 0) {
      return this.emotionOptions[0];
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
    return this.echoCards[0];
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

  private playRecipientEntryAnimation(): void {
    this.recipientEntryOpacity = 0;
    this.recipientEntryOffset = 18;
    setTimeout(() => {
      animateTo({
        duration: 480,
        curve: Curve.EaseOut
      }, () => {
        this.recipientEntryOpacity = 1;
        this.recipientEntryOffset = 0;
      });
    }, 60);
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
    this.currentPage = 'recipient';
    this.statusText = '先决定，这封信想写给谁。';
  }

  private openArchive(kind: string): void {
    this.archiveKind = kind;
    this.currentPage = 'archive';
  }

  private chooseRecipient(index: number): void {
    this.selectedRecipientIndex = index;
    this.selectedEmotionIndex = -1;
    this.emotionConfirmLabel = '是什么呢';
    this.futureReminderDate = this.getMinimumFutureDate();
    this.stopAllEmotionAnimations();
    this.currentPage = 'emotion';
    this.statusText = '再选一张情绪信纸，把心情放上去。';
  }

  private chooseEmotion(index: number): void {
    this.selectedEmotionIndex = index;
    this.emotionConfirmLabel = `是${this.emotionOptions[index].title}啊`;
    if (this.emotionOptions[index].id === 'other') {
      this.stopAllEmotionAnimations();
      this.currentPage = 'writing';
      this.statusText = '说不清也没关系，先慢慢写下来。';
      return;
    }
    this.startSelectedEmotionAnimation(index);
    this.statusText = `原来现在是${this.emotionOptions[index].title}啊。`;
  }

  private confirmEmotionSelection(): void {
    if (this.selectedEmotionIndex < 0) {
      this.statusText = '先选一种此刻更接近的心情。';
      return;
    }
    this.stopAllEmotionAnimations();
    this.currentPage = 'writing';
    this.statusText = '慢慢写，暂时不用急着发送。';
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
      reminderId: 0
    };

    const reminderId: number = await this.scheduleFutureReminder(record);
    record = {
      id: record.id,
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
      reminderId: reminderId
    };

    this.futureLetters = [record, ...this.futureLetters];
    this.echoCards = [record, ...this.echoCards];
    this.activeEchoId = record.id;
    this.drafts = this.drafts.filter((item: LetterRecord) => item.content !== originalContent);
    this.persistLetters();
    this.currentPage = 'echo';
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
    const originalContent: string = this.letterContent.trim();
    let record: LetterRecord = this.createRecord(ritual.title, ritual.subtitle);

    if (ritual.id === 'seal') {
      this.sealedLetters = [record, ...this.sealedLetters];
      this.statusText = '这封信已经被封存在时光盒里了。';
    } else if (ritual.id === 'future') {
      this.refreshNotificationPermissionStatus();
      this.currentPage = 'futureSchedule';
      this.statusText = '选一个未来日期，到那天我再提醒你打开。';
      return;
    } else if (ritual.id === 'drift') {
      record = {
        id: record.id,
        date: record.date,
        weekday: record.weekday,
        recipient: record.recipient,
        recipientHint: record.recipientHint,
        emotion: record.emotion,
        emotionHint: record.emotionHint,
        ritual: record.ritual,
        ritualHint: '它会带着这段情绪慢慢漂远，只留下淡淡一小段摘句。',
        content: this.createSoftExcerpt(record.content, 20),
        echoLine: '它正在漂流，你不用急着把它追回来。',
        keywords: [record.emotion, '漂流', '慢慢放下'],
        moodTag: record.moodTag,
        anonymous: record.anonymous,
        unlockDate: record.unlockDate,
        unlockAt: record.unlockAt,
        reminderId: record.reminderId
      };
      this.driftLetters = [record, ...this.driftLetters];
      this.statusText = '这封信已经开始漂流了，会慢慢离远一点。';
    } else if (ritual.id === 'spark') {
      record = {
        id: record.id,
        date: record.date,
        weekday: record.weekday,
        recipient: record.recipient,
        recipientHint: record.recipientHint,
        emotion: record.emotion,
        emotionHint: record.emotionHint,
        ritual: record.ritual,
        ritualHint: '完整正文已经化成光点，只留下这一束很轻的回声。',
        content: this.createSparkExcerpt(record.content),
        echoLine: '它已经化成光点，全文不再保留。',
        keywords: [record.emotion, '光点', '放下'],
        moodTag: record.moodTag,
        anonymous: record.anonymous,
        unlockDate: record.unlockDate,
        unlockAt: record.unlockAt,
        reminderId: record.reminderId
      };
      this.statusText = '这封信已经化成光点，只留下短短一束回声。';
    }

    this.echoCards = [record, ...this.echoCards];
    this.activeEchoId = record.id;
    this.drafts = this.drafts.filter((item: LetterRecord) => item.content !== originalContent);
    this.persistLetters();
    this.currentPage = 'echo';
  }

  private createRecord(ritual: string, ritualHint: string): LetterRecord {
    const recipient: SelectItem = this.getSelectedRecipient();
    const emotion: SelectItem = this.getSelectedEmotion();
    const now: Date = new Date();
    const record: LetterRecord = {
      id: this.nextId,
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
      moodTag: this.moodTag,
      anonymous: this.isAnonymous,
      unlockDate: '',
      unlockAt: 0,
      reminderId: 0
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
      return '完整正文已经散去，只留下这一束短短的回声。';
    }
    if (record.ritual === '漂流') {
      return '它会带着你的情绪慢慢离远，只留下淡淡的一小段。';
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
      return '最后留下的一束光：';
    }
    if (record.ritual === '漂流') {
      return '漂流后留下的摘句：';
    }
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return '未来开启时间：';
    }
    return '留下的一句话：';
  }

  private getDisplayedContent(record: LetterRecord): string {
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return record.unlockDate;
    }
    return `“${record.content}”`;
  }

  private getArchiveDisplayText(record: LetterRecord): string {
    if (record.ritual === '寄给未来' && !this.isFutureUnlocked(record)) {
      return `将于 ${record.unlockDate} 开启\n在那之前，这封信会先替你安静地留着。`;
    }
    return `“${record.content}”`;
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
    this.emotionConfirmLabel = '是什么呢';
    this.letterContent = '';
    this.isAnonymous = false;
    this.moodTag = '私语';
    this.futureReminderDate = this.getMinimumFutureDate();
  }

  private continueDraft(record: LetterRecord): void {
    this.selectedRecipientIndex = this.findIndexByTitle(this.recipientOptions, record.recipient);
    this.selectedEmotionIndex = this.findIndexByTitle(this.emotionOptions, record.emotion);
    this.letterContent = record.content;
    this.moodTag = record.moodTag;
    this.isAnonymous = record.anonymous;
    this.futureReminderDate = this.getMinimumFutureDate();
    this.currentPage = 'writing';
    this.statusText = '已经帮你把草稿重新铺开了。';
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

  private enterEcho(record: LetterRecord): void {
    this.openedMenuId = -1;
    this.activeEchoId = record.id;
    this.currentPage = 'echo';
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

    return merged.slice(0, limit);
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
          .fontSize(11)
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
          .fontColor('#2F2721')
        Text(item.subtitle)
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#9A9085')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.buildRecipientIllustration(item.id)
    }
    .width('100%')
    .padding({ left: 18, right: 14, top: 16, bottom: 16 })
    .backgroundColor('#FBF8F4')
    .borderRadius(24)
    .shadow({
      radius: 18,
      color: '#14000000',
      offsetX: 0,
      offsetY: 6
    })
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
          .fontColor('#2F2721')
        Text(item.subtitle)
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#998F84')
      }
      .alignItems(HorizontalAlign.Start)
      .width('64%')

      Blank()

      this.buildRitualIllustration(item.id)
    }
    .width('100%')
    .padding({ left: 18, right: 14, top: 16, bottom: 16 })
    .backgroundColor('#FBF8F4')
    .borderRadius(24)
    .shadow({
      radius: 18,
      color: '#14000000',
      offsetX: 0,
      offsetY: 6
    })
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
          .fontSize(11)
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
        .fontColor('#312923')
      Text(item.subtitle)
        .fontSize(12)
        .lineHeight(18)
        .fontColor('#857A70')
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
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .shadow({
      radius: 16,
      color: '#12000000',
      offsetX: 0,
      offsetY: 6
    })
    .opacity(this.selectedEmotionIndex < 0 || this.selectedEmotionIndex === index ? 1 : 0.88)
    .scale(this.selectedEmotionIndex === index ? { x: 1.02, y: 1.02 } : { x: 1, y: 1 })
    .onClick(() => {
      this.chooseEmotion(index);
    })
  }

  @Builder
  private buildBackHeader(title: string, subtitle: string) {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3E362F')
        .width(28)
        .onClick(() => {
          if (this.currentPage === 'emotion') {
            this.currentPage = 'recipient';
          } else if (this.currentPage === 'writing') {
            this.currentPage = 'emotion';
          } else if (this.currentPage === 'futureSchedule') {
            this.currentPage = 'ritual';
          } else if (this.currentPage === 'ritual') {
            this.currentPage = 'writing';
          } else {
            this.currentPage = 'home';
          }
        })

      Column({ space: 4 }) {
        Text(title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2D2520')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#8A8178')
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 8 })

      Blank()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 4 })
  }

  @Builder
  private buildPrimaryAction(label: string, background: string) {
    Row() {
      Blank()
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
      Blank()
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(background)
    .borderRadius(18)
  }

  @Builder
  private buildSecondaryAction(label: string) {
    Row() {
      Blank()
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6B6158')
      Blank()
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor('#F3EEE7')
    .borderRadius(18)
  }

  @Builder
  private buildMailboxCard(title: string, count: string, color: string, kind: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#352D27')
      Text(count)
        .fontSize(12)
        .fontColor('#8F857A')
    }
    .alignItems(HorizontalAlign.Start)
    .width('48%')
    .padding(18)
    .margin({ bottom: 12 })
    .backgroundColor(color)
    .borderRadius(24)
    .onClick(() => {
      this.openArchive(kind);
    })
  }

  @Builder
  private buildRecentCard(item: LetterRecord) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text(item.date)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#362F29')
            Text(`${item.emotion} · ${this.getRecordStatusLabel(item)}`)
              .fontSize(12)
              .fontColor('#93897E')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('...')
            .fontSize(18)
            .fontColor('#7A7065')
            .padding({ left: 8, right: 8, top: 2, bottom: 8 })
            .onClick(() => {
              this.toggleDeleteMenu(item.id);
            })
        }
        .width('100%')

        Text(this.getArchiveDisplayText(item))
          .fontSize(15)
          .lineHeight(26)
          .fontColor('#4C433C')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(item.ritualHint)
          .fontSize(12)
          .fontColor('#8A8178')
          .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
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
    .width('100%')
  }

  @Builder
  private buildEchoListCard(item: LetterRecord) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 12 }) {
        Row() {
          Text(item.date)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#352D27')
          Blank()
          Text(this.getRecordStatusLabel(item))
            .fontSize(12)
            .fontColor('#7A7065')
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
          .fontColor('#8C8379')

        Text(this.getArchiveDisplayText(item))
          .fontSize(15)
          .lineHeight(24)
          .fontColor('#4D433C')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#FBF7F1')
      .borderRadius(22)
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
        .fontWeight(FontWeight.Bold)
        .fontColor('#302822')
      Text(title)
        .fontSize(13)
        .fontColor('#7D746A')
    }
    .width('50%')
    .padding(18)
    .backgroundColor(color)
    .borderRadius(22)
  }

  @Builder
  private buildEmptyState(title: string, subtitle: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#433A34')
      Text(subtitle)
        .fontSize(13)
        .lineHeight(22)
        .fontColor('#8B8177')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 42, bottom: 42, left: 20, right: 20 })
    .backgroundColor('#FBF7F1')
    .borderRadius(24)
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
                .fontWeight(FontWeight.Bold)
                .fontColor('#2F2721')
              Text('把想说的话，先留在这里。')
                .fontSize(13)
                .fontColor('#8D857B')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Text('◌')
              .fontSize(18)
              .fontColor('#8D857B')
              .padding(12)
              .backgroundColor('#F4EEE7')
              .borderRadius(18)
          }
          .width('100%')

          Text(this.statusText)
            .fontSize(12)
            .fontColor('#9B9185')
            .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18 })

        if (this.homeTab === 0) {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 8 }) {
                  Text('写一封信')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#2C251F')
                  Text('今天也可以慢慢写，\n不急着发送。')
                    .fontSize(13)
                    .lineHeight(22)
                    .fontColor('#7B7269')
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Image($r('app.media.home_hedgehog'))
                  .width(156)
                  .height(108)
                  .objectFit(ImageFit.Contain)
                  .margin({ top: 8 })
              }
              .width('100%')

              Row() {
                Text('点击进入')
                  .fontSize(14)
                  .fontColor('#5E5850')
                Blank()
                Text('✎')
                  .fontSize(16)
                  .fontColor('#5E5850')
              }
              .width('100%')
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FBF7F1')
            .borderRadius(28)
            .opacity(this.homeEntryOpacity)
            .translate({ x: 0, y: this.homeEntryOffset })
            .onClick(() => {
              this.resetComposer();
              this.openComposer();
            })
            .onAppear(() => {
              this.playHomeEntryAnimation();
            })

            if (this.getRecentLetters(3).length > 0) {
              Column({ space: 10 }) {
                Text('最近几封')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#403731')
                  .width('100%')
                ForEach(this.getRecentLetters(3), (item: LetterRecord) => {
                  this.buildRecentCard(item)
                }, (item: LetterRecord) => `recent-${item.id}`)
              }
              .width('100%')
            }
          }
          .padding({ left: 20, right: 20, bottom: 110 })
        } else if (this.homeTab === 1) {
          Column({ space: 12 }) {
            Text('情绪回声')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2E2721')
              .width('100%')

            if (this.echoCards.length === 0) {
              this.buildEmptyState('还没有回声卡', '完成一封信后，这里会留下你的温柔回声。')
            } else {
              ForEach(this.echoCards, (item: LetterRecord) => {
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
              .fontWeight(FontWeight.Bold)
              .fontColor('#2E2721')
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              this.buildMailboxCard('草稿箱', `${this.drafts.length} 封草稿`, '#F5EFE7', 'draft')
              this.buildMailboxCard('封存的信', `${this.sealedLetters.length} 封信件`, '#F4EEE7', 'sealed')
              this.buildMailboxCard('未来信', `${this.getUnlockedFutureCount()} / ${this.futureLetters.length} 已开启`, '#F2F4F8', 'future')
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
        Row() {
          Text('‹')
            .fontSize(26)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3E362F')
            .width(28)
            .onClick(() => {
              this.currentPage = 'home';
            })

          Blank()

          Text('这封信，想写给谁？')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2F2721')

          Blank()

          Text('')
            .width(28)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 6 })

        Column({ space: 14 }) {
        ForEach(this.recipientOptions, (item: SelectItem, index: number) => {
          this.buildRecipientCard(item, index)
        }, (item: SelectItem) => item.id)
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 40 })
        .opacity(this.recipientEntryOpacity)
        .translate({ x: 0, y: this.recipientEntryOffset })
        .onAppear(() => {
          this.playRecipientEntryAnimation();
        })
      }
      .width('100%')
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

        Row() {
          Blank()
          Row() {
            Blank()
            Text(this.emotionConfirmLabel)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#5F564E')
            Blank()
          }
          .width('68%')
          .padding({ top: 14, bottom: 14, left: 18, right: 18 })
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .shadow({
            radius: 14,
            color: '#12000000',
            offsetX: 0,
            offsetY: 6
          })
          .opacity(this.selectedEmotionIndex >= 0 ? 1 : 0.92)
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

      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          TextArea({ text: this.letterContent, placeholder: '今天想说什么，就从第一句开始。' })
            .width('100%')
            .height('100%')
            .fontSize(18)
            .fontColor('#2F2721')
            .backgroundColor('#FBF8F3')
            .borderRadius(28)
            .padding(20)
            .onChange((value: string) => {
              this.letterContent = value;
            })

          Text(`${this.letterContent.length} 字`)
            .fontSize(13)
            .fontColor('#8C8379')
            .margin({ right: 22, bottom: 18 })
        }
        .width('100%')
        .layoutWeight(1)

        Row({ space: 12 }) {
          Column() {
            this.buildSecondaryAction('保存草稿')
          }
          .width('48%')
          .onClick(() => {
            this.saveDraft();
          })

          Column() {
            this.buildPrimaryAction('继续安放', '#97AEC3')
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
  private buildFutureSchedulePage() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildBackHeader('寄给未来', '选一个具体日期，到那天我再提醒你打开。')

        Column({ space: 16 }) {
          Text('未来开启日期')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#312923')
            .width('100%')

          DatePicker({
            start: this.getMinimumFutureDate(),
            end: new Date('2036-12-31'),
            selected: this.futureReminderDate
          })
            .width('100%')
            .height(210)
            .backgroundColor('#FFFFFF')
            .borderRadius(24)
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .onDateChange((value: Date) => {
              this.futureReminderDate = value;
            })

          Column({ space: 8 }) {
            Text('系统会在下面这个时间提醒你：')
              .fontSize(13)
              .fontColor('#8A8178')
              .width('100%')
            Text(this.formatDateTime(this.getFutureReminderMoment(this.futureReminderDate)))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#352D27')
              .width('100%')
            Text('默认在当天 09:00 自动弹通知，到了时间这封未来信也会解锁。')
              .fontSize(12)
              .lineHeight(20)
              .fontColor('#8A8178')
              .width('100%')
            Text(this.getFuturePermissionHint())
              .fontSize(12)
              .lineHeight(20)
              .fontColor(this.futureNotificationEnabled ? '#6E8E76' : '#A07E6B')
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FBF7F1')
          .borderRadius(24)
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
            this.buildPrimaryAction('寄给未来', '#97AEC3')
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

        Column({ space: 10 }) {
          Text(this.getActiveEcho().date)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2E2721')
            .width('100%')
          Text(this.getActiveEcho().weekday)
            .fontSize(12)
            .fontColor('#90867B')
            .width('100%')

          Row({ space: 8 }) {
            Text('情绪：')
              .fontSize(13)
              .fontColor('#7D746A')
            Text(this.getActiveEcho().emotion)
              .fontSize(13)
              .fontColor('#4B423C')
            Text('方式：')
              .fontSize(13)
              .fontColor('#7D746A')
            Text(this.getActiveEcho().ritual)
              .fontSize(13)
              .fontColor('#4B423C')
          }
          .width('100%')

          Text('关键词：' + this.getActiveEcho().keywords.join(' / '))
            .fontSize(13)
            .fontColor('#7D746A')
            .width('100%')

          Text(this.getActiveEcho().ritualHint)
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#7D746A')
            .width('100%')

          Text(this.getEchoContentLabel(this.getActiveEcho()))
            .fontSize(13)
            .fontColor('#7D746A')
            .width('100%')

          Text(this.getDisplayedContent(this.getActiveEcho()))
            .fontSize(17)
            .lineHeight(28)
            .fontColor('#342C26')
            .width('100%')

          Text('温柔回声：')
            .fontSize(13)
            .fontColor('#7D746A')
            .width('100%')

          Text(this.getActiveEcho().echoLine)
            .fontSize(14)
            .lineHeight(22)
            .fontColor('#6D645B')
            .width('100%')

        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FBF7F1')
        .borderRadius(28)

        Column({ space: 12 }) {
          Column() {
            this.buildPrimaryAction('保存回声卡', '#9AAFC4')
          }
          .onClick(() => {
            this.homeTab = 1;
            this.currentPage = 'home';
            this.statusText = '回声卡已经留在你的信箱里。';
          })

          Column() {
            this.buildSecondaryAction('返回信箱')
          }
          .onClick(() => {
            this.currentPage = 'home';
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 24 })
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
                  .fontColor('#352D27')
                Blank()
                Stack({ alignContent: Alignment.TopEnd }) {
                  Text(this.getRecordStatusLabel(item))
                    .fontSize(12)
                    .fontColor('#7A7065')
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
                .fontColor('#8E847A')
                .width('100%')

              Text(this.getArchiveDisplayText(item))
                .fontSize(15)
                .lineHeight(24)
                .fontColor('#4D433C')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')

              if (this.archiveKind === 'draft') {
                Text('继续编辑')
                  .fontSize(13)
                  .fontColor('#97AEC3')
                  .width('100%')
              } else {
                Text(item.echoLine)
                  .fontSize(12)
                  .fontColor('#8A8178')
                  .width('100%')
              }
            }
            .width('100%')
            .padding(18)
            .backgroundColor('#FBF7F1')
            .borderRadius(22)
            .onClick(() => {
              if (this.archiveKind === 'draft') {
                this.continueDraft(item);
              } else {
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
  private buildBottomBar() {
    Row() {
      Column({ space: 6 }) {
        Text('⌂')
          .fontSize(18)
          .fontColor(this.homeTab === 0 ? '#6E8EA9' : '#938A80')
        Text('信箱')
          .fontSize(11)
          .fontColor(this.homeTab === 0 ? '#6E8EA9' : '#938A80')
      }
      .width('25%')
      .padding({ top: 6, bottom: 6 })
      .onClick(() => {
        this.homeTab = 0;
        this.currentPage = 'home';
      })

      Column({ space: 6 }) {
        Text('✎')
          .fontSize(18)
          .fontColor('#938A80')
        Text('写信')
          .fontSize(11)
          .fontColor('#938A80')
      }
      .width('25%')
      .padding({ top: 6, bottom: 6 })
      .onClick(() => {
        this.resetComposer();
        this.openComposer();
      })

      Column({ space: 6 }) {
        Text('◍')
          .fontSize(18)
          .fontColor(this.homeTab === 1 ? '#6E8EA9' : '#938A80')
        Text('回声')
          .fontSize(11)
          .fontColor(this.homeTab === 1 ? '#6E8EA9' : '#938A80')
      }
      .width('25%')
      .padding({ top: 6, bottom: 6 })
      .onClick(() => {
        this.homeTab = 1;
        this.currentPage = 'home';
      })

      Column({ space: 6 }) {
        Text('◌')
          .fontSize(18)
          .fontColor(this.homeTab === 2 ? '#6E8EA9' : '#938A80')
        Text('我的')
          .fontSize(11)
          .fontColor(this.homeTab === 2 ? '#6E8EA9' : '#938A80')
      }
      .width('25%')
      .padding({ top: 6, bottom: 6 })
      .onClick(() => {
        this.homeTab = 2;
        this.currentPage = 'home';
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 18 })
    .backgroundColor('#FFFDFC')
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
        } else if (this.currentPage === 'futureSchedule') {
          this.buildFutureSchedulePage()
        } else if (this.currentPage === 'archive') {
          this.buildArchivePage()
        } else {
          this.buildEchoPage()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F3EE')

      if (this.currentPage === 'home') {
        this.buildBottomBar()
      }

    }
    .width('100%')
    .height('100%')
  }
}

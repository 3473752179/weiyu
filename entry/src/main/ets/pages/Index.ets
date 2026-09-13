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
}

@Entry
@Component
struct Index {
  private readonly recipientOptions: Array<SelectItem> = [
    { id: 'self', title: '写给自己', subtitle: '给此刻的自己一点温柔', emoji: '🪞', color: '#F4EEE5' },
    { id: 'someone', title: '写给某个人', subtitle: '给那个TA，说说心里话', emoji: '💌', color: '#F7F1E6' },
    { id: 'future', title: '写给未来的自己', subtitle: '给未来的自己一句话', emoji: '📅', color: '#F5EFE7' },
    { id: 'unknown', title: '写给不会收到的人', subtitle: '有些话，只想说给风听', emoji: '🦔', color: '#EEF3F7' },
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

  @State private currentPage: string = 'home';
  @State private homeTab: number = 0;
  @State private archiveKind: string = 'draft';
  @State private selectedRecipientIndex: number = -1;
  @State private selectedEmotionIndex: number = -1;
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

  aboutToAppear(): void {
    if (this.initialized) {
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
      anonymous: false
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
      anonymous: true
    };

    this.drafts = [draft];
    this.sealedLetters = [echo];
    this.echoCards = [echo];
    this.activeEchoId = echo.id;
    this.initialized = true;
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

  private openComposer(): void {
    this.homeTab = 0;
    this.currentPage = 'recipient';
    this.statusText = '先决定，这封信想写给谁。';
  }

  private openArchive(kind: string): void {
    this.archiveKind = kind;
    this.currentPage = 'archive';
  }

  private chooseRecipient(index: number): void {
    this.selectedRecipientIndex = index;
    this.currentPage = 'emotion';
    this.statusText = '再选一张情绪信纸，把心情放上去。';
  }

  private chooseEmotion(index: number): void {
    this.selectedEmotionIndex = index;
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

  private applyRitual(index: number): void {
    const ritual: SelectItem = this.ritualOptions[index];
    const record: LetterRecord = this.createRecord(ritual.title, ritual.subtitle);

    if (ritual.id === 'seal') {
      this.sealedLetters = [record, ...this.sealedLetters];
    } else if (ritual.id === 'future') {
      this.futureLetters = [record, ...this.futureLetters];
    } else if (ritual.id === 'drift') {
      this.driftLetters = [record, ...this.driftLetters];
    }

    this.echoCards = [record, ...this.echoCards];
    this.activeEchoId = record.id;
    this.drafts = this.drafts.filter((item: LetterRecord) => item.content !== record.content);
    this.currentPage = 'echo';
    this.statusText = '这封信已经被妥善安放。';
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
      anonymous: this.isAnonymous
    };
    this.nextId += 1;
    return record;
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
    this.letterContent = '';
    this.isAnonymous = false;
    this.moodTag = '私语';
  }

  private continueDraft(record: LetterRecord): void {
    this.selectedRecipientIndex = this.findIndexByTitle(this.recipientOptions, record.recipient);
    this.selectedEmotionIndex = this.findIndexByTitle(this.emotionOptions, record.emotion);
    this.letterContent = record.content;
    this.moodTag = record.moodTag;
    this.isAnonymous = record.anonymous;
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
    this.activeEchoId = record.id;
    this.currentPage = 'echo';
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
      Image($r('app.media.emotion_sad'))
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'regret') {
      Image($r('app.media.emotion_regret'))
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'angry') {
      Image($r('app.media.emotion_angry'))
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'happy') {
      Image($r('app.media.emotion_happy'))
        .width(88)
        .height(72)
        .objectFit(ImageFit.Contain)
    } else if (id === 'confused') {
      Image($r('app.media.emotion_confused'))
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
    .backgroundColor(item.color)
    .borderRadius(24)
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
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(item.date)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#362F29')
          Text(`${item.emotion} · ${item.ritual}`)
            .fontSize(12)
            .fontColor('#93897E')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(item.anonymous ? '匿名' : '署名')
          .fontSize(12)
          .fontColor('#7A7065')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F1E7DD')
          .borderRadius(12)
      }
      .width('100%')

      Text(`“${item.content}”`)
        .fontSize(15)
        .lineHeight(26)
        .fontColor('#4C433C')

      Text(item.echoLine)
        .fontSize(12)
        .fontColor('#8A8178')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .onClick(() => {
      this.enterEcho(item);
    })
  }

  @Builder
  private buildEchoListCard(item: LetterRecord) {
    Column({ space: 12 }) {
      Row() {
        Text(item.date)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#352D27')
        Blank()
        Text(item.ritual)
          .fontSize(12)
          .fontColor('#7A7065')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F1E8DE')
          .borderRadius(12)
      }
      .width('100%')

      Text(`${item.recipient} · ${item.emotion}`)
        .fontSize(12)
        .fontColor('#8C8379')

      Text(`“${item.content}”`)
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
      Text('🦔')
        .fontSize(48)
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
            .onClick(() => {
              this.resetComposer();
              this.openComposer();
            })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              this.buildMailboxCard('草稿箱', `${this.drafts.length} 封草稿`, '#F5EFE7', 'draft')
              this.buildMailboxCard('封存的信', `${this.sealedLetters.length} 封信件`, '#F4EEE7', 'sealed')
              this.buildMailboxCard('未来信', `${this.futureLetters.length} 封待开启`, '#F2F4F8', 'future')
              this.buildMailboxCard('情绪回声卡', `${this.echoCards.length} 张回声卡`, '#F5F1EA', 'echo')
            }
            .width('100%')

            if (this.echoCards.length > 0) {
              Column({ space: 10 }) {
                Text('最近一封')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#403731')
                  .width('100%')
                this.buildRecentCard(this.echoCards[0])
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

            Row({ space: 12 }) {
              this.buildStatCard('封存柜', `${this.sealedLetters.length}`, '#F6EFE7')
              this.buildStatCard('漂流瓶', `${this.driftLetters.length}`, '#EEF4F8')
            }
            .width('100%')

            Row({ space: 12 }) {
              this.buildStatCard('未来信箱', `${this.futureLetters.length}`, '#F4EFE6')
              this.buildStatCard('回声卡', `${this.echoCards.length}`, '#F6F2EA')
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
      }
      .width('100%')
    }
  }

  @Builder
  private buildEchoPage() {
    Scroll() {
      Column({ space: 14 }) {
        this.buildBackHeader('这是一封未寄出的信', '它已经被妥善安放。')

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

          Text('留下的一句话：')
            .fontSize(13)
            .fontColor('#7D746A')
            .width('100%')

          Text(`“${this.getActiveEcho().content}”`)
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

          Text('🦔')
            .fontSize(48)
            .width('100%')
            .textAlign(TextAlign.End)
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
                Text(item.ritual)
                  .fontSize(12)
                  .fontColor('#7A7065')
              }
              .width('100%')

              Text(`${item.recipient} · ${item.emotion}`)
                .fontSize(12)
                .fontColor('#8E847A')
                .width('100%')

              Text(`“${item.content}”`)
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

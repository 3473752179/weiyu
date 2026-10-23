let cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct LetterCard {
  @LocalStorageProp('hasLetter') private hasLetter: boolean = false;
  @LocalStorageProp('date') private date: string = '微语';
  @LocalStorageProp('emotionAndRitual') private emotionAndRitual: string = '给此刻留一点空间';
  @LocalStorageProp('content') private content: string = '最近，有没有什么想写下来的？';
  @LocalStorageProp('target') private target: string = 'write';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        target: this.target
      }
    }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column({ space: 10 }) {
          Row() {
            Text(this.date)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#51483F')
            Blank()
            Text(this.hasLetter ? this.emotionAndRitual : '写一封信')
              .fontSize(11)
              .fontColor('#8C8176')
          }
          .width('100%')

          Text(this.content)
            .fontSize(this.hasLetter ? 16 : 18)
            .fontWeight(this.hasLetter ? FontWeight.Regular : FontWeight.Medium)
            .lineHeight(25)
            .fontColor('#342C26')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Blank()

          Text(this.hasLetter ? '打开这封信  ›' : '现在写一点  ✎')
            .fontSize(12)
            .fontColor('#6E8EA9')
            .width('100%')
        }
        .width('100%')
        .height('100%')
        .padding(20)

        Image($r('app.media.home_hedgehog'))
          .width(76)
          .height(58)
          .objectFit(ImageFit.Contain)
          .margin({ right: 10, bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FBF7F1')
      .borderRadius(24)
    }
    .width('100%')
    .height('100%')
  }
}

import { WeiyuTheme } from '../../theme/WeiyuTheme';

let cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct LetterCard {
  @LocalStorageProp('hasLetter') private hasLetter: boolean = false;
  @LocalStorageProp('date') private date: string = '今天';
  @LocalStorageProp('emotionAndRitual') private emotionAndRitual: string = '片刻停靠';
  @LocalStorageProp('eyebrow') private eyebrow: string = '给忙碌按一次暂停';
  @LocalStorageProp('headline') private headline: string = '现在的你，还好吗？';
  @LocalStorageProp('content') private content: string = '用一句话，把此刻从忙碌里轻轻取出来。';
  @LocalStorageProp('actionLabel') private actionLabel: string = '写下此刻';
  @LocalStorageProp('target') private target: string = 'write';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        target: this.target
      }
    }) {
      Column({ space: 0 }) {
        Row() {
          Text('未语')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)

          Blank()

          Text(this.emotionAndRitual)
            .fontSize(10)
            .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(WeiyuTheme.COLOR_SURFACE_MUTED)
            .borderRadius(12)
        }
        .width('100%')

        Text(`${this.date} · ${this.eyebrow}`)
          .fontSize(11)
          .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 14 })

        Text(this.headline)
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .lineHeight(26)
          .fontColor(WeiyuTheme.COLOR_TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })

        Text(this.content)
          .fontSize(12)
          .lineHeight(19)
          .fontColor(WeiyuTheme.COLOR_TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })

        Blank()

        Row() {
          Row({ space: 5 }) {
            Text(this.actionLabel)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
              .maxLines(1)

            Text('›')
              .fontSize(16)
              .fontColor(WeiyuTheme.COLOR_ACCENT_STRONG)
          }
          .padding({ left: 12, right: 11, top: 8, bottom: 8 })
          .backgroundColor(WeiyuTheme.COLOR_ACCENT_SOFT)
          .borderRadius(15)

          Blank()

          Image($r('app.media.home_hedgehog'))
            .width(62)
            .height(46)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height(48)
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 16, top: 16, bottom: 14 })
      .backgroundColor(WeiyuTheme.COLOR_SURFACE_WARM)
      .border({ width: 1, color: WeiyuTheme.COLOR_BORDER })
      .borderRadius(WeiyuTheme.RADIUS_CARD)
    }
    .width('100%')
    .height('100%')
  }
}

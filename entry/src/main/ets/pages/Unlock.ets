import { UnlockItemVm, defaultUnlockItems, runUnlockCheck } from '../model/UnlockChecks';
import { Theme } from '../ui/Theme';

@Component
export struct Unlock {
  @State items: UnlockItemVm[] = defaultUnlockItems();
  @State testingAll: boolean = false;
  @State hint: string = '连接后检测会走当前节点';

  private applyResult(result: UnlockItemVm): void {
    const next: UnlockItemVm[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const cur = this.items[i];
      const copy = new UnlockItemVm();
      copy.name = cur.name;
      copy.status = cur.status;
      copy.region = cur.region;
      copy.time = cur.time;
      if (cur.name === result.name) {
        copy.status = result.status;
        copy.region = result.region;
        copy.time = result.time;
      }
      next.push(copy);
    }
    this.items = next;
  }

  private setRunning(name: string): void {
    const running = new UnlockItemVm();
    running.name = name;
    running.status = 'Running';
    running.time = '';
    this.applyResult(running);
  }

  private async testOne(name: string): Promise<void> {
    this.setRunning(name);
    const result = await runUnlockCheck(name);
    this.applyResult(result);
  }

  private async testAll(): Promise<void> {
    if (this.testingAll) {
      return;
    }
    this.testingAll = true;
    this.hint = '正在检测…';
    for (let i = 0; i < this.items.length; i++) {
      this.setRunning(this.items[i].name);
    }
    const tasks: Promise<void>[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const name = this.items[i].name;
      tasks.push(runUnlockCheck(name).then((result) => {
        this.applyResult(result);
      }));
    }
    await Promise.all(tasks);
    this.testingAll = false;
    this.hint = '检测完成';
  }

  private statusLabel(status: string): string {
    if (status === 'Yes') {
      return '支持';
    }
    if (status === 'No') {
      return '不支持';
    }
    if (status === 'Originals') {
      return '仅自制剧';
    }
    if (status === 'Running') {
      return '检测中';
    }
    if (status === 'Failed') {
      return '失败';
    }
    return '待检测';
  }

  private badgeColor(status: string): string {
    if (status === 'Yes') {
      return Theme.ok;
    }
    if (status === 'No') {
      return Theme.danger;
    }
    if (status === 'Originals') {
      return Theme.warn;
    }
    if (status === 'Failed') {
      return Theme.danger;
    }
    if (status === 'Running') {
      return Theme.accent;
    }
    return Theme.subtle;
  }

  private timeLabel(item: UnlockItemVm): string {
    if (item.time.length > 0) {
      return item.time;
    }
    return '--';
  }

  private titleText(item: UnlockItemVm): string {
    if (item.region.length > 0 && (item.status === 'Yes' || item.status === 'No')) {
      return `${item.name}  ${item.region}`;
    }
    return item.name;
  }

  build() {
    Column() {
      Row() {
        Text(this.hint)
          .fontSize(13)
          .fontColor(Theme.muted)
          .layoutWeight(1)
        Button(this.testingAll ? '检测中' : '测试全部')
          .type(ButtonType.Capsule)
          .fontSize(13)
          .height(32)
          .fontColor('#FFFFFF')
          .backgroundColor(Theme.accent)
          .enabled(!this.testingAll)
          .onClick(() => {
            this.testAll();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Scroll() {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.items, (item: UnlockItemVm) => {
            Column() {
              Row() {
                Text(this.titleText(item))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.text)
                  .layoutWeight(1)
                  .maxLines(2)
                Text('刷新')
                  .fontSize(12)
                  .fontColor(Theme.accent)
                  .onClick(() => {
                    this.testOne(item.name);
                  })
              }
              .width('100%')

              Text(this.statusLabel(item.status))
                .fontSize(12)
                .fontColor('#FFFFFF')
                .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                .borderRadius(10)
                .backgroundColor(this.badgeColor(item.status))
                .margin({ top: 12 })
                .alignSelf(ItemAlign.Start)

              Text(this.timeLabel(item))
                .fontSize(11)
                .fontColor(Theme.subtle)
                .width('100%')
                .textAlign(TextAlign.End)
                .margin({ top: 12 })
            }
            .width('48%')
            .padding(14)
            .margin({ bottom: 12 })
            .borderRadius(20)
            .backgroundColor(Theme.card)
          }, (item: UnlockItemVm) => `${item.name}|${item.status}|${item.time}|${item.region}`)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(Theme.bg)
  }
}

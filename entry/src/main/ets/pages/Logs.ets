import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClashRest } from '../model/ClashRest';
import { RuntimeBridge } from '../model/RuntimeBridge';
import { LOG_DOMAIN, LOG_TAG } from '../common/Constants';
import { Theme } from '../ui/Theme';

interface ConnMetaJson {
  host?: string;
  destinationIP?: string;
  network?: string;
  type?: string;
}

interface ConnItemJson {
  metadata?: ConnMetaJson;
}

interface ConnectionsJson {
  downloadTotal?: number;
  uploadTotal?: number;
  connections?: ConnItemJson[];
}

class ConnVm {
  title: string = '';
  detail: string = '';
}

@Component
export struct Logs {
  @State rows: ConnVm[] = [];
  @State summary: string = '请先连接后再刷新';
  private runtime?: RuntimeBridge;

  aboutToAppear(): void {
    const filesDir = AppStorage.get('filesDir') as string;
    this.runtime = new RuntimeBridge(filesDir);
    this.refresh();
  }

  private async clearConns(): Promise<void> {
    try {
      const code = await ClashRest.deleteNoBody('/connections', this.runtime);
      this.summary = `已清空连接 HTTP ${code}`;
      await this.refresh();
    } catch (e) {
      this.summary = `清空失败 ${ClashRest.formatErr(e as Object)}`;
    }
  }

  private async refresh(): Promise<void> {
    try {
      const raw = await ClashRest.getText('/connections', this.runtime);
      const parsed = JSON.parse(raw) as ConnectionsJson;
      const conns = parsed.connections ?? [];
      const next: ConnVm[] = [];
      const n = conns.length > 40 ? 40 : conns.length;
      for (let i = 0; i < n; i++) {
        const meta = conns[i].metadata;
        const hostRaw = `${meta?.host ?? ''}`;
        const ipRaw = `${meta?.destinationIP ?? ''}`;
        const vm = new ConnVm();
        vm.title = hostRaw.length > 0 ? hostRaw : (ipRaw.length > 0 ? ipRaw : '(unknown)');
        vm.detail = `${meta?.network ?? ''}  ${meta?.type ?? ''}`;
        next.push(vm);
      }
      this.rows = next;
      this.summary = `↑ ${parsed.uploadTotal ?? 0}   ↓ ${parsed.downloadTotal ?? 0} · ${conns.length} 条`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'REST GET /connections n=%{public}d', conns.length);
    } catch (e) {
      this.rows = [];
      this.summary = `拉取失败 ${ClashRest.formatErr(e as Object)}`;
    }
  }

  build() {
    NavDestination() {
    Column() {
      Text(this.summary)
        .fontSize(13)
        .fontColor(Theme.muted)
        .width('100%')
        .margin({ bottom: 12 })
      Row({ space: 10 }) {
        Button('刷新')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(40)
          .fontColor(Theme.accent)
          .backgroundColor(Theme.accentSoft)
          .onClick(() => {
            this.refresh();
          })
        Button('清空连接')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(40)
          .fontColor(Theme.danger)
          .backgroundColor('#FDECEA')
          .onClick(() => {
            this.clearConns();
          })
      }
      .width('100%')

      List() {
        ForEach(this.rows, (item: ConnVm, idx: number) => {
          ListItem() {
            Column() {
              Text(item.title)
                .fontSize(14)
                .fontColor(Theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.detail)
                .fontSize(12)
                .fontColor(Theme.subtle)
                .margin({ top: 4 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          }
        }, (item: ConnVm, idx: number) => `${idx}|${item.title}`)
      }
      .layoutWeight(1)
      .width('100%')
      .margin({ top: 12 })
      .backgroundColor(Theme.card)
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(Theme.bg)
    }
    .title('连接日志')
    .hideBackButton(false)
    .backgroundColor(Theme.bg)
  }
}

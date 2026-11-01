import { common } from '@kit.AbilityKit';
import { PrefStore } from '../model/PrefStore';
import { AppSettings } from '../model/AppState';
import { ClashRest } from '../model/ClashRest';
import { RuntimeBridge } from '../model/RuntimeBridge';
import { Theme } from '../ui/Theme';
import { loadProxySession, saveProxyMode } from '../model/ProxySessionStore';

@Component
export struct Settings {
  @State testUrlBrief: string = '';
  @State vpnBrief: string = '';
  @State message: string = '';
  @State proxyMode: string = '';
  @State showModeSheet: boolean = false;
  private prefs: PrefStore = new PrefStore();
  private runtime?: RuntimeBridge;

  aboutToAppear(): void {
    const filesDir = AppStorage.get('filesDir') as string;
    const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
    this.runtime = new RuntimeBridge(filesDir);
    this.prefs.init(ctx).then(async () => {
      const session = await loadProxySession(this.prefs);
      if (session.mode.length > 0) {
        this.proxyMode = session.mode;
      }
      await this.refreshSummaries();
      await this.loadProxyMode();
    });
  }

  private briefUrl(url: string): string {
    if (url.length <= 36) {
      return url;
    }
    return `${url.substring(0, 33)}…`;
  }

  private summarizeVpn(s: AppSettings): string {
    const v6 = s.enableIpv6 ? 'IPv6 开' : 'IPv6 关';
    let access = '全部应用';
    if (s.access.mode === 'allow') {
      access = '仅所选';
    } else if (s.access.mode === 'block') {
      access = '排除所选';
    }
    return `${v6} · ${s.tunStack} · ${access}`;
  }

  private async refreshSummaries(): Promise<void> {
    const s = await this.prefs.getSettings();
    this.testUrlBrief = this.briefUrl(s.testUrl);
    this.vpnBrief = this.summarizeVpn(s);
  }

  private proxyLabel(): string {
    if (this.proxyMode === 'rule') {
      return '规则';
    }
    if (this.proxyMode === 'global') {
      return '全局';
    }
    if (this.proxyMode === 'direct') {
      return '直连';
    }
    return this.proxyMode.length > 0 ? this.proxyMode : '未连接';
  }

  private async loadProxyMode(): Promise<void> {
    try {
      const raw = await ClashRest.getText('/configs', this.runtime);
      const obj = JSON.parse(raw) as Record<string, Object>;
      const live = `${obj['mode'] ?? ''}`;
      if (live.length > 0) {
        this.proxyMode = live;
      }
    } catch (_e) {
    }
  }

  private async setProxyMode(next: string): Promise<void> {
    this.showModeSheet = false;
    await saveProxyMode(this.prefs, next);
    this.proxyMode = next;
    try {
      const code = await ClashRest.patchJson('/configs', JSON.stringify({ mode: next }), this.runtime);
      if (code === 204 || code === 200) {
        this.message = `代理模式已切换为 ${this.proxyLabel()}`;
      } else {
        this.message = `已保存，切换失败 HTTP ${code}`;
      }
    } catch (_e) {
      this.message = `已保存，连接 VPN 后生效`;
    }
  }

  private openModeSheet(): void {
    this.loadProxyMode();
    this.showModeSheet = true;
  }

  build() {
    Scroll() {
      Column() {
        List() {
          ListItem() {
            this.navRow('VPN 与隧道', this.vpnBrief.length > 0 ? this.vpnBrief : 'DNS、TUN、按应用')
          }
          .onClick(() => {
            this.openDest('VpnTunnel');
          })
          ListItem() {
            this.navRow('订阅', '导入、更新与选用配置')
          }
          .onClick(() => {
            this.openDest('Profiles');
          })
          ListItem() {
            this.navRow('Providers', '更新订阅节点集')
          }
          .onClick(() => {
            this.openDest('Providers');
          })
          ListItem() {
            this.navRow('连接日志', '当前会话连接')
          }
          .onClick(() => {
            this.openDest('Logs');
          })
          ListItem() {
            this.navRow('测速与诊断', this.testUrlBrief.length > 0 ? this.testUrlBrief : '测速 URL')
          }
          .onClick(() => {
            this.openDest('TestDiagnostics');
          })
          ListItem() {
            this.modeRow()
          }
          ListItem() {
            this.navRow('关于', '版本与说明')
          }
          .onClick(() => {
            this.openDest('About');
          })
        }
        .width('100%')
        .margin({ top: 8, bottom: 24 })
        .backgroundColor(Theme.card)
        .borderRadius(20)
        .clip(true)
        .divider({
          strokeWidth: 0.5,
          color: Theme.line,
          startMargin: 16,
          endMargin: 16
        })

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor(Theme.ok)
            .margin({ top: 12 })
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .backgroundColor(Theme.bg)
    .scrollBar(BarState.Off)
    .onVisibleAreaChange([0.0, 1.0], (visible: boolean, ratio: number) => {
      if (visible && ratio > 0) {
        this.refreshSummaries();
      }
    })
    .bindSheet($$this.showModeSheet, this.modeSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      backgroundColor: Theme.card
    })
  }

  private openDest(name: string): void {
    const info = this.queryNavigationInfo();
    if (info) {
      info.pathStack.pushPathByName(name, '');
    }
  }

  @Builder
  modeRow() {
    Row() {
      Text('代理模式')
        .fontSize(16)
        .fontColor(Theme.text)
        .layoutWeight(1)
      Text(this.proxyLabel())
        .fontSize(14)
        .fontColor(Theme.accent)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([Theme.subtle])
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.openModeSheet();
    })
  }

  @Builder
  modeSheet() {
    Column() {
      Text('选择代理模式')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .width('100%')
        .margin({ bottom: 16, top: 16 })
      this.sheetOption('规则', 'rule', '按配置规则分流')
      this.sheetOption('全局', 'global', '全部走代理')
      this.sheetOption('直连', 'direct', '全部直连')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 32 })
  }

  @Builder
  sheetOption(title: string, value: string, hint: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(17)
          .fontWeight(this.proxyMode === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.proxyMode === value ? Theme.accent : Theme.text)
        Text(hint)
          .fontSize(13)
          .fontColor(Theme.subtle)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.proxyMode === value) {
        Text('✓')
          .fontSize(18)
          .fontColor(Theme.accent)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .margin({ bottom: 10 })
    .borderRadius(16)
    .backgroundColor(this.proxyMode === value ? Theme.accentSoft : Theme.chip)
    .onClick(() => {
      this.setProxyMode(value);
    })
  }

  @Builder
  navRow(title: string, subtitle: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor(Theme.text)
        Text(subtitle)
          .fontSize(12)
          .fontColor(Theme.subtle)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([Theme.subtle])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

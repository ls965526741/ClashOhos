import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { startVpn, stopVpn, VpnStartParams } from '../vpn/VpnController';
import { ProfileStore } from '../model/ProfileStore';
import { PrefStore } from '../model/PrefStore';
import { RuntimeBridge } from '../model/RuntimeBridge';
import { CONTROLLER_URL, LOG_DOMAIN, LOG_TAG } from '../common/Constants';
import { http } from '@kit.NetworkKit';
import { Theme } from '../ui/Theme';
import { applyProxySession } from '../model/ProxySessionStore';

interface ConnectionsTotals {
  downloadTotal?: number;
  uploadTotal?: number;
}

@Component
export struct HomeTab {
  @State statusText: string = '未连接';
  @State errorText: string = '';
  @State probeText: string = '';
  @State probeOk: boolean = false;
  @State upload: string = '0 B';
  @State download: string = '0 B';
  @State activeName: string = '未选择配置';
  @State connecting: boolean = false;
  @State linked: boolean = false;
  private timerId: number = -1;
  private restOk: boolean = false;
  private prefs: PrefStore = new PrefStore();
  private store?: ProfileStore;
  private runtime?: RuntimeBridge;
  private autoConnectStarted: boolean = false;
  private sessionRestoreDone: boolean = false;

  aboutToAppear(): void {
    const filesDir = AppStorage.get('filesDir') as string;
    const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
    this.store = new ProfileStore(filesDir);
    this.runtime = new RuntimeBridge(filesDir);
    this.prefs.init(ctx).then(async () => {
      await this.refreshActive();
      await this.tryAutoConnect();
    });
    this.timerId = setInterval(() => this.poll(), 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
    }
  }

  private async refreshActive(): Promise<void> {
    const uuid = await this.prefs.getActiveUuid();
    const rec = this.store?.list().find((item) => item.uuid === uuid);
    this.activeName = rec ? rec.name : '未选择配置';
  }

  private poll(): void {
    const st = this.runtime?.readStatus();
    const controller = (st?.controller && st.controller.length > 0) ? st.controller : CONTROLLER_URL;
    this.pollRest(controller);
    if (st?.connected && this.restOk) {
      this.connecting = false;
      this.linked = true;
      this.statusText = '已连接';
      if (!this.sessionRestoreDone) {
        this.sessionRestoreDone = true;
        applyProxySession(this.prefs, this.runtime);
      }
      return;
    }
    this.linked = false;
    if (!st?.connected) {
      this.sessionRestoreDone = false;
    }
    if (st?.connected && !this.restOk) {
      this.statusText = '正在就绪';
      return;
    }
    if (this.connecting || (st?.lastError && st.lastError.indexOf('正在') >= 0)) {
      this.statusText = '连接中';
      return;
    }
    this.statusText = st?.lastError ? '连接失败' : '未连接';
  }

  private formatBytes(n: number): string {
    if (n < 1024) {
      return `${n} B`;
    }
    if (n < 1024 * 1024) {
      return `${(n / 1024).toFixed(1)} KB`;
    }
    if (n < 1024 * 1024 * 1024) {
      return `${(n / 1024 / 1024).toFixed(1)} MB`;
    }
    return `${(n / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }

  private pollTraffic(controller: string): void {
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 1500,
      readTimeout: 1500
    };
    http.createHttp().request(`${controller}/connections`, extra).then((res) => {
      if (res.responseCode !== 200) {
        return;
      }
      try {
        const parsed = JSON.parse(`${res.result}`) as ConnectionsTotals;
        this.upload = this.formatBytes(parsed.uploadTotal ?? 0);
        this.download = this.formatBytes(parsed.downloadTotal ?? 0);
      } catch (_e) {
      }
    }).catch((_e: BusinessError) => {
    });
  }

  private pollRest(controller: string): void {
    if (!controller) {
      return;
    }
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 1500,
      readTimeout: 1500
    };
    http.createHttp().request(`${controller}/version`, extra).then((res) => {
      this.restOk = res.responseCode === 200;
      if (res.responseCode === 200) {
        this.pollTraffic(controller);
      }
    }).catch((_e: BusinessError) => {
      this.restOk = false;
    });
  }

  private async tryAutoConnect(): Promise<void> {
    if (this.autoConnectStarted) {
      return;
    }
    const uuid = await this.prefs.getActiveUuid();
    if (!uuid) {
      return;
    }
    this.autoConnectStarted = true;
    const st = this.runtime?.readStatus();
    if (st?.connected) {
      return;
    }
    await this.connectVpn();
  }

  private async connectVpn(): Promise<void> {
    const uuid = await this.prefs.getActiveUuid();
    if (!uuid) {
      this.errorText = '请先在设置 → 订阅导入并激活一份配置';
      return;
    }
    const settings = await this.prefs.getSettings();
    const path = this.store!.profileDir(uuid);
    this.connecting = true;
    try {
      const params = new VpnStartParams();
      params.profilePath = path;
      params.enableIpv6 = settings.enableIpv6 ? '1' : '0';
      params.tunStack = settings.tunStack;
      params.dns = settings.dns;
      params.accessMode = settings.access.mode;
      params.bundles = settings.access.bundles.join(',');
      const startErr = await startVpn(params);
      if (startErr.length > 0) {
        this.connecting = false;
        this.errorText = startErr;
      } else {
        this.statusText = '连接中';
      }
    } catch (e) {
      this.connecting = false;
      const err = e as BusinessError;
      this.errorText = `${err.code}:${err.message}`;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'connectVpn failed %{public}s', this.errorText);
    }
  }

  private async toggle(): Promise<void> {
    this.errorText = '';
    const st = this.runtime?.readStatus();
    if (st?.connected && this.restOk) {
      const stopErr = await stopVpn();
      this.restOk = false;
      this.connecting = false;
      this.linked = false;
      this.runtime?.markDisconnected('');
      if (stopErr.length > 0) {
        this.errorText = stopErr;
      } else {
        this.statusText = '正在停止';
      }
      return;
    }
    if (st?.connected && !this.restOk) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'stale connected status, start VPN instead of stop');
      this.runtime?.markDisconnected('');
    }
    await this.connectVpn();
  }

  private async probe(): Promise<void> {
    this.probeText = '探测中…';
    this.probeOk = false;
    const started = Date.now();
    try {
      let url = 'https://www.gstatic.com/generate_204';
      const saved = (await this.prefs.getSettings()).testUrl;
      if (saved.length > 0) {
        url = saved;
      }
      const extra: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 8000
      };
      const res = await http.createHttp().request(url, extra);
      const ms = Date.now() - started;
      const code = res.responseCode;
      if (code === 204 || code === 200) {
        this.probeOk = true;
        this.probeText = `延迟 ${ms} ms`;
        this.errorText = '';
        return;
      }
      this.probeOk = false;
      this.probeText = `异常 HTTP ${code} · ${ms} ms`;
    } catch (e) {
      this.probeOk = false;
      this.probeText = `探测失败`;
    }
  }

  private powerLabel(): string {
    if (this.connecting) {
      return '处理中';
    }
    return this.linked ? '断开连接' : '连接';
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Row() {
            Text(this.statusText)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.linked ? Theme.ok : Theme.text)
              .layoutWeight(1)
            Text(this.linked ? '运行中' : '空闲')
              .fontSize(12)
              .fontColor(this.linked ? Theme.ok : Theme.subtle)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .borderRadius(10)
              .backgroundColor(this.linked ? '#E8F8E8' : Theme.chip)
          }
          .width('100%')
          Text(this.activeName)
            .fontSize(14)
            .fontColor(Theme.muted)
            .margin({ top: 8 })
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(Theme.card)
        .borderRadius(20)

        Button(this.powerLabel())
          .type(ButtonType.Capsule)
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor(this.linked ? Theme.danger : Theme.accent)
          .margin({ top: 16 })
          .enabled(!this.connecting)
          .onClick(() => {
            this.toggle();
          })

        Row({ space: 12 }) {
          Column() {
            Text('上传').fontSize(12).fontColor(Theme.muted)
            Text(this.upload)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Theme.card)
          .borderRadius(20)

          Column() {
            Text('下载').fontSize(12).fontColor(Theme.muted)
            Text(this.download)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Theme.card)
          .borderRadius(20)
        }
        .width('100%')
        .margin({ top: 12 })

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(13)
            .fontColor(Theme.danger)
            .width('100%')
            .margin({ top: 12 })
        }
        if (this.probeText.length > 0) {
          Text(this.probeText)
            .fontSize(13)
            .fontColor(this.probeOk ? Theme.ok : Theme.warn)
            .width('100%')
            .margin({ top: 8 })
        }

        Button('连通测试')
          .type(ButtonType.Capsule)
          .width('100%')
          .height(44)
          .fontSize(15)
          .fontColor(Theme.accent)
          .backgroundColor(Theme.accentSoft)
          .margin({ top: 16, bottom: 24 })
          .onClick(() => {
            this.probe();
          })
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
  }
}

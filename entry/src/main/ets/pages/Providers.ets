import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClashRest } from '../model/ClashRest';
import { PrefStore } from '../model/PrefStore';
import { RuntimeBridge } from '../model/RuntimeBridge';
import { LOG_DOMAIN, LOG_TAG } from '../common/Constants';
import { Theme } from '../ui/Theme';

class ProviderVm {
  name: string = '';
  vehicle: string = '';
  count: number = 0;
  updated: string = '';
}

interface ProviderJson {
  vehicleType?: string;
  updatedAt?: string;
  proxies?: Object[];
}

interface ProvidersRoot {
  providers?: Record<string, ProviderJson>;
}

interface ProxyNowJson {
  now?: string;
  type?: string;
  all?: string[];
}

@Component
export struct Providers {
  @State list: ProviderVm[] = [];
  @State message: string = '请先连接 VPN';
  private runtime?: RuntimeBridge;

  aboutToAppear(): void {
    const filesDir = AppStorage.get('filesDir') as string;
    this.runtime = new RuntimeBridge(filesDir);
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'REST GET /providers/proxies start');
      const raw = await ClashRest.getText('/providers/proxies', this.runtime);
      const parsed = JSON.parse(raw) as ProvidersRoot;
      const map = parsed.providers ?? {};
      const next: ProviderVm[] = [];
      const names = Object.keys(map);
      for (let i = 0; i < names.length; i++) {
        const name = names[i];
        const item = map[name];
        const vm = new ProviderVm();
        vm.name = name;
        vm.vehicle = `${item.vehicleType ?? ''}`;
        vm.count = item.proxies ? item.proxies.length : 0;
        vm.updated = `${item.updatedAt ?? ''}`;
        next.push(vm);
      }
      this.list = next;
      this.message = next.length === 0 ? '当前配置没有 proxy-providers' : `共 ${next.length} 个 Provider`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'REST GET /providers/proxies n=%{public}d', next.length);
    } catch (e) {
      this.list = [];
      this.message = `拉取失败 ${ClashRest.formatErr(e as Object)}`;
    }
  }

  private async updateOne(name: string): Promise<void> {
    try {
      const code = await ClashRest.putNoBody(`/providers/proxies/${encodeURIComponent(name)}`, 20000, this.runtime);
      this.message = `更新 ${name} HTTP ${code}`;
      await this.refresh();
    } catch (e) {
      this.message = `更新失败 ${ClashRest.formatErr(e as Object)}`;
    }
  }

  private isPassthrough(name: string): boolean {
    return name === 'DIRECT' || name === 'REJECT' || name === 'REJECT-DROP' ||
      name === 'PASS' || name === 'COMPATIBLE';
  }

  private remember(line: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', line);
    this.runtime?.writeRestLast(line);
  }

  private async health(): Promise<void> {
    try {
      this.message = '测速中…';
      this.remember('REST GET delay start');
      const globalRaw = await ClashRest.getText('/proxies/GLOBAL', this.runtime, 5000);
      const globalObj = JSON.parse(globalRaw) as ProxyNowJson;
      const rawNames: string[] = [];
      const now = `${globalObj.now ?? ''}`.trim();
      if (now.length > 0) {
        rawNames.push(now);
      }
      const all = globalObj.all ?? [];
      for (let i = 0; i < all.length; i++) {
        rawNames.push(`${all[i]}`);
      }
      const targets: string[] = [];
      for (let i = 0; i < rawNames.length; i++) {
        const name = rawNames[i].trim();
        if (name.length === 0 || this.isPassthrough(name)) {
          continue;
        }
        let seen = false;
        for (let j = 0; j < targets.length; j++) {
          if (targets[j] === name) {
            seen = true;
            break;
          }
        }
        if (!seen) {
          targets.push(name);
        }
      }
      if (targets.length === 0) {
        this.message = `GLOBAL 当前是 ${now.length > 0 ? now : '空'}，没有可测的代理节点`;
        this.remember(`REST GET delay skip now=${now}`);
        return;
      }
      let testUrl = 'https://www.gstatic.com/generate_204';
      try {
        const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
        const prefs = new PrefStore();
        await prefs.init(ctx);
        const saved = (await prefs.getSettings()).testUrl;
        if (saved.length > 0) {
          testUrl = saved;
        }
      } catch (_e) {
      }
      const limit = targets.length > 3 ? 3 : targets.length;
      let lastLine = '';
      for (let i = 0; i < limit; i++) {
        const target = targets[i];
        const path =
          `/proxies/${encodeURIComponent(target)}/delay?url=${encodeURIComponent(testUrl)}&timeout=8000`;
        const res = await ClashRest.getRaw(path, this.runtime, 20000);
        const snippet = res.body.slice(0, 120);
        if (res.code === 200) {
          this.message = `测速 ${target} ${snippet}`;
          this.remember(`REST GET delay ok node=${target} ${snippet}`);
          return;
        }
        lastLine = `REST GET delay HTTP ${res.code} node=${target} ${snippet}`;
        this.remember(lastLine);
      }
      this.message = lastLine.length > 0 ? lastLine : '测速失败';
    } catch (e) {
      const err = ClashRest.formatErr(e as Object);
      this.message = `健康检查失败 ${err}`;
      this.remember(`REST GET delay fail ${err}`);
    }
  }

  build() {
    NavDestination() {
    Column() {
      Text(this.message)
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
        Button('GLOBAL 测速')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(40)
          .fontColor('#FFFFFF')
          .backgroundColor(Theme.accent)
          .onClick(() => {
            this.health();
          })
      }
      .width('100%')
      List() {
        ForEach(this.list, (item: ProviderVm) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.name)
                  .fontSize(16)
                  .fontColor(Theme.text)
                  .fontWeight(FontWeight.Medium)
                Text(`${item.vehicle} · ${item.count} 节点`)
                  .fontSize(12)
                  .fontColor(Theme.subtle)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('更新')
                .type(ButtonType.Capsule)
                .fontSize(13)
                .height(32)
                .fontColor(Theme.accent)
                .backgroundColor(Theme.accentSoft)
                .onClick(() => {
                  this.updateOne(item.name);
                })
            }
            .width('100%')
            .padding(14)
          }
        }, (item: ProviderVm) => item.name)
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
    .backgroundColor(Theme.bg)
    .padding(16)
    }
    .title('Providers')
    .hideBackButton(false)
    .backgroundColor(Theme.bg)
  }
}

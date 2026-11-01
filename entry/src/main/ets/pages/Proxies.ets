import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClashRest } from '../model/ClashRest';
import { PrefStore } from '../model/PrefStore';
import { RuntimeBridge } from '../model/RuntimeBridge';
import { LOG_DOMAIN, LOG_TAG } from '../common/Constants';
import { Theme } from '../ui/Theme';
import { displayNodeName } from '../common/NodeDisplay';
import { saveGroupSelection } from '../model/ProxySessionStore';

class NodeVm {
  name: string = '';
  delay: string = '';
}

class ProxyGroupVm {
  name: string = '';
  type: string = '';
  now: string = '';
  nodes: NodeVm[] = [];
}

interface ProxyItemJson {
  type?: string;
  now?: string;
  all?: string[];
}

interface ProxiesJson {
  proxies?: Record<string, ProxyItemJson>;
}

interface DelayJson {
  delay?: number;
}

@Component
export struct Proxies {
  @StorageLink('mainTab') @Watch('onTab') tab: number = 0;
  @StorageLink('proxyTick') @Watch('onProxyTick') proxyTick: number = 0;
  @State groups: ProxyGroupVm[] = [];
  @State message: string = '连接后再选择节点';
  @State loading: boolean = false;
  @State testing: boolean = false;
  private runtime?: RuntimeBridge;

  aboutToAppear(): void {
    const filesDir = AppStorage.get('filesDir') as string;
    this.runtime = new RuntimeBridge(filesDir);
    this.refresh();
  }

  onTab(): void {
    if (this.tab === 1) {
      this.refresh();
    }
  }

  onProxyTick(): void {
    this.refresh();
  }

  private copyGroups(): ProxyGroupVm[] {
    const next: ProxyGroupVm[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      const src = this.groups[i];
      const vm = new ProxyGroupVm();
      vm.name = src.name;
      vm.type = src.type;
      vm.now = src.now;
      const nodes: NodeVm[] = [];
      for (let j = 0; j < src.nodes.length; j++) {
        const n = new NodeVm();
        n.name = src.nodes[j].name;
        n.delay = src.nodes[j].delay;
        nodes.push(n);
      }
      vm.nodes = nodes;
      next.push(vm);
    }
    return next;
  }

  private applyNow(groupName: string, now: string): void {
    const next = this.copyGroups();
    for (let i = 0; i < next.length; i++) {
      if (next[i].name === groupName) {
        next[i].now = now;
      }
    }
    this.groups = next;
  }

  private setDelay(nodeName: string, delay: string): void {
    const next = this.copyGroups();
    for (let i = 0; i < next.length; i++) {
      for (let j = 0; j < next[i].nodes.length; j++) {
        if (next[i].nodes[j].name === nodeName) {
          next[i].nodes[j].delay = delay;
        }
      }
    }
    this.groups = next;
  }

  private groupKey(group: ProxyGroupVm): string {
    let delays = '';
    for (let i = 0; i < group.nodes.length; i++) {
      delays += `${group.nodes[i].name}:${group.nodes[i].delay}|`;
    }
    return `${group.name}|${group.now}|${delays}`;
  }

  private selectable(type: string): boolean {
    return type === 'Selector' || type === 'URLTest' || type === 'Fallback' || type === 'LoadBalance';
  }

  private isPassthrough(name: string): boolean {
    return name === 'DIRECT' || name === 'REJECT' || name === 'REJECT-DROP' ||
      name === 'PASS' || name === 'COMPATIBLE';
  }

  private delayColor(delay: string): string {
    if (delay === '超时' || delay === '失败') {
      return Theme.danger;
    }
    if (delay === '…') {
      return Theme.subtle;
    }
    const n = parseInt(delay, 10);
    if (n > 0 && n < 300) {
      return Theme.ok;
    }
    if (n >= 300 && n < 800) {
      return Theme.warn;
    }
    if (n >= 800) {
      return Theme.danger;
    }
    return Theme.subtle;
  }

  private async refresh(): Promise<void> {
    this.loading = true;
    try {
      const raw = await ClashRest.getText('/proxies', this.runtime);
      const parsed = JSON.parse(raw) as ProxiesJson;
      const map = parsed.proxies ?? {};
      const old = this.copyGroups();
      const next: ProxyGroupVm[] = [];
      const names = Object.keys(map);
      for (let i = 0; i < names.length; i++) {
        const name = names[i];
        const item = map[name];
        const type = `${item.type ?? ''}`;
        const all = item.all ?? [];
        if (!this.selectable(type) || all.length === 0) {
          continue;
        }
        const vm = new ProxyGroupVm();
        vm.name = name;
        vm.type = type;
        vm.now = `${item.now ?? ''}`;
        const nodes: NodeVm[] = [];
        for (let j = 0; j < all.length; j++) {
          const n = new NodeVm();
          n.name = all[j];
          n.delay = this.findOldDelay(old, all[j]);
          nodes.push(n);
        }
        vm.nodes = nodes;
        next.push(vm);
      }
      this.groups = next;
      this.message = next.length === 0 ? '没有可切换的代理组' : `${next.length} 个代理组`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'REST GET /proxies groups=%{public}d', next.length);
    } catch (e) {
      this.groups = [];
      this.message = `请先在首页连接（${ClashRest.formatErr(e as Object)}）`;
    } finally {
      this.loading = false;
    }
  }

  private findOldDelay(old: ProxyGroupVm[], nodeName: string): string {
    for (let i = 0; i < old.length; i++) {
      for (let j = 0; j < old[i].nodes.length; j++) {
        if (old[i].nodes[j].name === nodeName && old[i].nodes[j].delay.length > 0) {
          return old[i].nodes[j].delay;
        }
      }
    }
    return '';
  }

  private async selectNode(group: string, name: string): Promise<void> {
    try {
      const code = await ClashRest.putJson(
        `/proxies/${encodeURIComponent(group)}`,
        JSON.stringify({ name: name }),
        this.runtime
      );
      if (code !== 204 && code !== 200) {
        this.message = `切换失败 HTTP ${code}`;
        return;
      }
      this.applyNow(group, name);
      const raw = await ClashRest.getText(`/proxies/${encodeURIComponent(group)}`, this.runtime);
      const item = JSON.parse(raw) as ProxyItemJson;
      const now = `${item.now ?? name}`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'REST PUT /proxies now=%{public}s want=%{public}s', now, name);
      this.applyNow(group, now);
      this.message = now === name ? `已切换到 ${displayNodeName(now)}` : `已请求 ${displayNodeName(name)}`;
      const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
      const prefs = new PrefStore();
      await prefs.init(ctx);
      await saveGroupSelection(prefs, group, now);
    } catch (e) {
      this.message = `切换失败 ${ClashRest.formatErr(e as Object)}`;
    }
  }

  private async testUrl(): Promise<string> {
    let url = 'https://www.gstatic.com/generate_204';
    try {
      const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
      const prefs = new PrefStore();
      await prefs.init(ctx);
      const saved = (await prefs.getSettings()).testUrl;
      if (saved.length > 0) {
        url = saved;
      }
    } catch (_e) {
    }
    return url;
  }

  private async pingOne(name: string, url: string): Promise<void> {
    if (this.isPassthrough(name)) {
      this.setDelay(name, '');
      return;
    }
    this.setDelay(name, '…');
    try {
      const path = `/proxies/${encodeURIComponent(name)}/delay?url=${encodeURIComponent(url)}&timeout=5000`;
      const res = await ClashRest.getRaw(path, this.runtime, 12000);
      if (res.code !== 200) {
        this.setDelay(name, '超时');
        return;
      }
      const parsed = JSON.parse(res.body) as DelayJson;
      const ms = parsed.delay ?? 0;
      if (ms > 0) {
        this.setDelay(name, `${ms}ms`);
      } else {
        this.setDelay(name, '超时');
      }
    } catch (_e) {
      this.setDelay(name, '失败');
    }
  }

  private collectNames(group?: ProxyGroupVm): string[] {
    const names: string[] = [];
    const groups = group ? [group] : this.groups;
    for (let i = 0; i < groups.length; i++) {
      for (let j = 0; j < groups[i].nodes.length; j++) {
        const name = groups[i].nodes[j].name;
        if (this.isPassthrough(name)) {
          continue;
        }
        let seen = false;
        for (let k = 0; k < names.length; k++) {
          if (names[k] === name) {
            seen = true;
            break;
          }
        }
        if (!seen) {
          names.push(name);
        }
      }
    }
    return names;
  }

  private async testNodes(group?: ProxyGroupVm): Promise<void> {
    if (this.testing) {
      return;
    }
    this.testing = true;
    this.message = '测速中…';
    const url = await this.testUrl();
    const names = this.collectNames(group);
    for (let i = 0; i < names.length; i++) {
      await this.pingOne(names[i], url);
    }
    this.testing = false;
    this.message = names.length === 0 ? '没有可测节点' : '测速完成';
  }

  build() {
    Column() {
      Row() {
        Text(this.message)
          .fontSize(13)
          .fontColor(Theme.muted)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button(this.testing ? '测速中' : '测速')
          .type(ButtonType.Capsule)
          .fontSize(13)
          .height(32)
          .fontColor('#FFFFFF')
          .backgroundColor(Theme.accent)
          .enabled(!this.testing)
          .margin({ right: 8 })
          .onClick(() => {
            this.testNodes();
          })
        Button(this.loading ? '…' : '刷新')
          .type(ButtonType.Capsule)
          .fontSize(13)
          .height(32)
          .fontColor(Theme.accent)
          .backgroundColor(Theme.accentSoft)
          .onClick(() => {
            this.refresh();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      List() {
        ForEach(this.groups, (group: ProxyGroupVm) => {
          ListItem() {
            Column() {
              Row() {
                Text(group.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.text)
                  .layoutWeight(1)
                Text(group.type)
                  .fontSize(11)
                  .fontColor(Theme.accent)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor(Theme.accentSoft)
                Text('测速')
                  .fontSize(12)
                  .fontColor(Theme.accent)
                  .margin({ left: 10 })
                  .onClick(() => {
                    this.testNodes(group);
                  })
              }
              .width('100%')
              Text(`当前 ${displayNodeName(group.now)}`)
                .fontSize(12)
                .fontColor(Theme.muted)
                .margin({ top: 6, bottom: 6 })
                .width('100%')

              ForEach(group.nodes, (node: NodeVm) => {
                Row() {
                  Text(displayNodeName(node.name))
                    .fontSize(15)
                    .fontColor(node.name === group.now ? Theme.accent : Theme.text)
                    .fontWeight(node.name === group.now ? FontWeight.Medium : FontWeight.Regular)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(node.delay.length > 0 ? node.delay : '--')
                    .fontSize(13)
                    .fontColor(this.delayColor(node.delay))
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .margin({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(12)
                .backgroundColor(node.name === group.now ? Theme.accentSoft : '#00000000')
                .onClick(() => {
                  this.selectNode(group.name, node.name);
                })
              }, (node: NodeVm) => `${group.name}|${node.name}|${group.now}|${node.delay}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .margin({ bottom: 12 })
            .backgroundColor(Theme.card)
            .borderRadius(20)
          }
        }, (group: ProxyGroupVm) => this.groupKey(group))
      }
      .layoutWeight(1)
      .width('100%')
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

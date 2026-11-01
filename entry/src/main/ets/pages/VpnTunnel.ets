import { common } from '@kit.AbilityKit';
import { PrefStore } from '../model/PrefStore';
import { AppSettings, defaultSettings } from '../model/AppState';
import { Theme } from '../ui/Theme';
import { AppPickItem, loadInstalledApps, lookupBundle } from '../model/InstalledApps';

@Component
export struct VpnTunnel {
  @State ipv6: boolean = false;
  @State dns: string = defaultSettings().dns;
  @State stack: string = defaultSettings().tunStack;
  @State mode: string = 'all';
  @State selectedPickItems: AppPickItem[] = [];
  @State message: string = '';
  @State appListHint: string = '';
  @State manualBundleHint: string = '';
  @State sheetKind: string = '';
  @State @Watch('onShowSheetChanged') showSheet: boolean = false;
  @State appItems: AppPickItem[] = [];
  @State appSearch: string = '';
  @State manualBundle: string = '';
  @State appsLoading: boolean = false;
  private prefs: PrefStore = new PrefStore();
  private lastSheetDismissMs: number = 0;
  private sheetWasVisible: boolean = false;
  private sheetOpenTimer: number = -1;
  private readonly sheetSwitchDelayMs: number = 360;

  aboutToAppear(): void {
    const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
    this.prefs.init(ctx).then(async () => {
      const s = await this.prefs.getSettings();
      this.ipv6 = s.enableIpv6;
      this.dns = s.dns;
      this.stack = s.tunStack;
      this.mode = s.access.mode;
      this.selectedPickItems = [];
      for (let i = 0; i < s.access.bundles.length; i++) {
        const name = s.access.bundles[i];
        const stub = new AppPickItem();
        stub.bundleName = name;
        stub.label = name;
        this.selectedPickItems.push(stub);
      }
      await this.hydratePickLabels();
    });
  }

  private async save(): Promise<void> {
    const prev = await this.prefs.getSettings();
    const settings = new AppSettings();
    settings.enableIpv6 = this.ipv6;
    settings.dns = this.dns.trim().length > 0 ? this.dns.trim() : defaultSettings().dns;
    settings.tunStack = this.stack;
    settings.testUrl = prev.testUrl;
    settings.access.mode = this.mode;
    settings.access.bundles = this.copyBundleNames();
    await this.prefs.setSettings(settings);
    this.message = '已保存，下次连接 VPN 时生效';
  }

  private copyBundleNames(): string[] {
    const bundles: string[] = [];
    for (let i = 0; i < this.selectedPickItems.length; i++) {
      bundles.push(this.selectedPickItems[i].bundleName);
    }
    return bundles;
  }

  private async hydratePickLabels(): Promise<void> {
    for (let i = 0; i < this.selectedPickItems.length; i++) {
      const name = this.selectedPickItems[i].bundleName;
      const resolved = await lookupBundle(name);
      if (resolved !== null) {
        this.selectedPickItems[i].label = resolved.label;
      }
    }
    this.selectedPickItems = this.clonePickItems(this.selectedPickItems);
  }

  private clonePickItems(src: AppPickItem[]): AppPickItem[] {
    const out: AppPickItem[] = [];
    for (let i = 0; i < src.length; i++) {
      const copy = new AppPickItem();
      copy.bundleName = src[i].bundleName;
      copy.label = src[i].label;
      out.push(copy);
    }
    return out;
  }

  private accessLabel(): string {
    if (this.mode === 'allow') {
      return '仅所选走代理';
    }
    if (this.mode === 'block') {
      return '所选不走代理';
    }
    return '全部应用';
  }

  private accessModeHint(): string {
    if (this.mode === 'allow') {
      return '仅下方列表中的应用走 VPN';
    }
    if (this.mode === 'block') {
      return '下方列表中的应用不走 VPN';
    }
    return '所有应用流量进入 VPN';
  }

  aboutToDisappear(): void {
    if (this.sheetOpenTimer >= 0) {
      clearTimeout(this.sheetOpenTimer);
      this.sheetOpenTimer = -1;
    }
  }

  private onShowSheetChanged(): void {
    if (!this.showSheet && this.sheetWasVisible) {
      this.lastSheetDismissMs = Date.now();
    }
    this.sheetWasVisible = this.showSheet;
  }

  private clearSheetTimer(): void {
    if (this.sheetOpenTimer >= 0) {
      clearTimeout(this.sheetOpenTimer);
      this.sheetOpenTimer = -1;
    }
  }

  private scheduleSheetOpen(kind: string, afterOpen?: () => void): void {
    this.clearSheetTimer();
    const launch = (): void => {
      this.sheetOpenTimer = -1;
      this.sheetKind = kind;
      this.showSheet = true;
      if (afterOpen) {
        afterOpen();
      }
    };
    let delayMs = 0;
    if (this.showSheet) {
      this.showSheet = false;
      delayMs = this.sheetSwitchDelayMs;
    } else {
      const elapsed = Date.now() - this.lastSheetDismissMs;
      if (elapsed < this.sheetSwitchDelayMs) {
        delayMs = this.sheetSwitchDelayMs - elapsed;
      }
    }
    if (delayMs > 0) {
      this.sheetOpenTimer = setTimeout(launch, delayMs);
      return;
    }
    launch();
  }

  private closeSheet(): void {
    this.clearSheetTimer();
    this.showSheet = false;
  }

  private openStackSheet(): void {
    this.scheduleSheetOpen('stack');
  }

  private openAccessSheet(): void {
    this.scheduleSheetOpen('access');
  }

  private async openAppSheet(): Promise<void> {
    this.scheduleSheetOpen('app', () => {
      this.manualBundleHint = '';
      this.appsLoading = true;
      loadInstalledApps().then((loaded) => {
        this.appItems = loaded.items;
        this.appListHint = loaded.hint;
        this.appsLoading = false;
      });
    });
  }

  private filteredApps(): AppPickItem[] {
    const key = this.appSearch.trim().toLowerCase();
    if (key.length === 0) {
      return this.appItems;
    }
    const out: AppPickItem[] = [];
    for (let i = 0; i < this.appItems.length; i++) {
      const item = this.appItems[i];
      if (item.label.toLowerCase().indexOf(key) >= 0 || item.bundleName.toLowerCase().indexOf(key) >= 0) {
        out.push(item);
      }
    }
    return out;
  }

  private isBundleSelected(name: string): boolean {
    for (let i = 0; i < this.selectedPickItems.length; i++) {
      if (this.selectedPickItems[i].bundleName === name) {
        return true;
      }
    }
    return false;
  }

  private addPickItem(item: AppPickItem): void {
    if (item.bundleName.length === 0 || this.isBundleSelected(item.bundleName)) {
      return;
    }
    const next = this.clonePickItems(this.selectedPickItems);
    next.push(item);
    this.selectedPickItems = next;
  }

  private togglePickItem(item: AppPickItem): void {
    if (this.isBundleSelected(item.bundleName)) {
      const next: AppPickItem[] = [];
      for (let i = 0; i < this.selectedPickItems.length; i++) {
        if (this.selectedPickItems[i].bundleName !== item.bundleName) {
          next.push(this.selectedPickItems[i]);
        }
      }
      this.selectedPickItems = next;
      return;
    }
    this.addPickItem(item);
  }

  private removePickItem(name: string): void {
    const next: AppPickItem[] = [];
    for (let i = 0; i < this.selectedPickItems.length; i++) {
      if (this.selectedPickItems[i].bundleName !== name) {
        next.push(this.selectedPickItems[i]);
      }
    }
    this.selectedPickItems = next;
  }

  private async verifyAndAddManualBundle(): Promise<void> {
    const name = this.manualBundle.trim();
    if (name.length === 0) {
      this.manualBundleHint = '请输入包名';
      return;
    }
    if (this.isBundleSelected(name)) {
      this.manualBundleHint = '已在列表中';
      return;
    }
    this.manualBundleHint = '正在验证…';
    const resolved = await lookupBundle(name);
    if (resolved !== null) {
      this.addPickItem(resolved);
      this.manualBundle = '';
      this.manualBundleHint = `已添加：${resolved.label}`;
      return;
    }
    this.manualBundleHint = '未找到该包名，可点「仍添加包名」强制写入';
  }

  private addManualBundleRaw(): void {
    const name = this.manualBundle.trim();
    if (name.length === 0 || this.isBundleSelected(name)) {
      return;
    }
    const item = new AppPickItem();
    item.bundleName = name;
    item.label = name;
    this.addPickItem(item);
    this.manualBundle = '';
    this.manualBundleHint = '已按包名添加（未验证）';
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column() {
            Row() {
              Column() {
                Text('IPv6 双栈')
                  .fontSize(16)
                  .fontColor(Theme.text)
                if (this.ipv6) {
                  Text('为隧道增加 IPv6 地址，无需额外填写')
                    .fontSize(12)
                    .fontColor(Theme.subtle)
                    .margin({ top: 4 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.ipv6 })
                .selectedColor(Theme.accent)
                .onChange((v) => this.ipv6 = v)
            }
            .width('100%')
            .padding({ top: 4, bottom: 12 })

            Text('DNS')
              .fontSize(12)
              .fontColor(Theme.muted)
              .width('100%')
            Text('VPN 隧道 DNS，默认 172.19.0.2，与 IPv6 开关无关')
              .fontSize(11)
              .fontColor(Theme.subtle)
              .width('100%')
              .margin({ top: 2 })
            TextInput({ text: this.dns })
              .onChange((v) => this.dns = v)
              .backgroundColor(Theme.chip)
              .fontColor(Theme.text)
              .height(40)
              .borderRadius(10)
              .margin({ top: 6, bottom: 14 })

            Row() {
              Text('TUN stack')
                .fontSize(16)
                .fontColor(Theme.text)
                .layoutWeight(1)
              Text(this.stack)
                .fontSize(14)
                .fontColor(Theme.accent)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([Theme.subtle])
                .margin({ left: 4 })
            }
            .width('100%')
            .height(48)
            .padding({ top: 4, bottom: 12 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.openStackSheet();
            })

            Row() {
              Text('按应用接管')
                .fontSize(16)
                .fontColor(Theme.text)
                .layoutWeight(1)
              Text(this.accessLabel())
                .fontSize(14)
                .fontColor(Theme.accent)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([Theme.subtle])
                .margin({ left: 4 })
            }
            .width('100%')
            .height(48)
            .padding({ bottom: 4 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.openAccessSheet();
            })

            Text(this.accessModeHint())
              .fontSize(11)
              .fontColor(Theme.subtle)
              .width('100%')
              .margin({ top: 8, bottom: 8 })

            if (this.mode !== 'all') {
              Button('添加应用')
                .type(ButtonType.Capsule)
                .width('100%')
                .height(40)
                .fontColor(Theme.accent)
                .backgroundColor(Theme.accentSoft)
                .onClick(() => {
                  this.openAppSheet();
                })

              if (this.selectedPickItems.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.selectedPickItems, (item: AppPickItem) => {
                    Text(`${item.label}  ×`)
                      .fontSize(12)
                      .fontColor(Theme.accent)
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .margin({ right: 8, top: 8 })
                      .borderRadius(10)
                      .backgroundColor(Theme.accentSoft)
                      .onClick(() => {
                        this.removePickItem(item.bundleName);
                      })
                  }, (item: AppPickItem) => item.bundleName)
                }
                .width('100%')
              }
            }

            Button('保存')
              .type(ButtonType.Capsule)
              .width('100%')
              .height(44)
              .fontColor('#FFFFFF')
              .backgroundColor(Theme.accent)
              .margin({ top: 16 })
              .onClick(() => {
                this.save();
              })

            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(13)
                .fontColor(Theme.ok)
                .width('100%')
                .margin({ top: 10 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Theme.card)
          .borderRadius(20)
        }
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.bg)
      .padding(16)
    }
    .bindSheet($$this.showSheet, this.unifiedSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      backgroundColor: Theme.card
    })
    .title('VPN 与隧道')
    .hideBackButton(false)
    .backgroundColor(Theme.bg)
  }

  @Builder
  unifiedSheet() {
    if (this.sheetKind === 'stack') {
      this.stackSheet()
    } else if (this.sheetKind === 'access') {
      this.accessSheet()
    } else if (this.sheetKind === 'app') {
      this.appPickerSheet()
    }
  }

  @Builder
  stackSheet() {
    Column() {
      Text('选择 TUN stack')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .width('100%')
        .margin({ bottom: 16, top: 16 })
      this.stackSheetOption('system', 'system', '优先系统栈，一般推荐')
      this.stackSheetOption('gvisor', 'gvisor', '用户态网络栈')
      this.stackSheetOption('mixed', 'mixed', '混合模式')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 32 })
  }

  @Builder
  accessSheet() {
    Column() {
      Text('按应用接管')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .width('100%')
        .margin({ bottom: 16, top: 16 })
      this.accessSheetOption('全部应用', 'all', '所有应用流量进入 VPN')
      this.accessSheetOption('仅所选走代理', 'allow', '仅列表中的应用走 VPN')
      this.accessSheetOption('所选不走代理', 'block', '列表中的应用不走 VPN')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 32 })
  }

  @Builder
  stackSheetOption(title: string, value: string, hint: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(17)
          .fontWeight(this.stack === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.stack === value ? Theme.accent : Theme.text)
        Text(hint)
          .fontSize(13)
          .fontColor(Theme.subtle)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.stack === value) {
        Text('✓')
          .fontSize(18)
          .fontColor(Theme.accent)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .margin({ bottom: 10 })
    .borderRadius(16)
    .backgroundColor(this.stack === value ? Theme.accentSoft : Theme.chip)
    .onClick(() => {
      this.stack = value;
      this.closeSheet();
    })
  }

  @Builder
  accessSheetOption(title: string, value: string, hint: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(17)
          .fontWeight(this.mode === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.mode === value ? Theme.accent : Theme.text)
        Text(hint)
          .fontSize(13)
          .fontColor(Theme.subtle)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.mode === value) {
        Text('✓')
          .fontSize(18)
          .fontColor(Theme.accent)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .margin({ bottom: 10 })
    .borderRadius(16)
    .backgroundColor(this.mode === value ? Theme.accentSoft : Theme.chip)
    .onClick(() => {
      this.mode = value;
      this.closeSheet();
    })
  }

  @Builder
  appPickerSheet() {
    Column() {
      Text('添加应用')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .width('100%')
        .margin({ top: 8, bottom: 8 })
      if (this.appListHint.length > 0) {
        Text(this.appListHint)
          .fontSize(12)
          .fontColor(Theme.muted)
          .width('100%')
          .margin({ bottom: 10 })
      }
      TextInput({ placeholder: '包名，如 com.huawei.hmos.browser', text: this.manualBundle })
        .onChange((v) => {
          this.manualBundle = v;
          this.manualBundleHint = '';
        })
        .backgroundColor(Theme.chip)
        .height(40)
        .borderRadius(10)
      Row({ space: 8 }) {
        Button('验证并添加')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(40)
          .fontColor('#FFFFFF')
          .backgroundColor(Theme.accent)
          .onClick(() => {
            this.verifyAndAddManualBundle();
          })
        Button('仍添加包名')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(40)
          .fontColor(Theme.accent)
          .backgroundColor(Theme.accentSoft)
          .onClick(() => this.addManualBundleRaw())
      }
      .width('100%')
      .margin({ top: 8 })
      if (this.manualBundleHint.length > 0) {
        Text(this.manualBundleHint)
          .fontSize(12)
          .fontColor(Theme.subtle)
          .width('100%')
          .margin({ top: 6 })
      }
      if (this.appsLoading) {
        Text('正在尝试读取应用列表…')
          .fontSize(13)
          .fontColor(Theme.muted)
          .width('100%')
          .padding({ top: 12 })
      } else if (this.appItems.length > 0) {
        Text('可勾选（当前设备允许枚举时）')
          .fontSize(12)
          .fontColor(Theme.muted)
          .width('100%')
          .margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '搜索应用名或包名', text: this.appSearch })
          .onChange((v) => this.appSearch = v)
          .backgroundColor(Theme.chip)
          .height(40)
          .borderRadius(10)
          .margin({ bottom: 8 })
        List() {
          ForEach(this.filteredApps(), (item: AppPickItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.label)
                    .fontSize(15)
                    .fontColor(Theme.text)
                  Text(item.bundleName)
                    .fontSize(11)
                    .fontColor(Theme.subtle)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.isBundleSelected(item.bundleName)) {
                  Text('✓')
                    .fontSize(18)
                    .fontColor(Theme.accent)
                }
              }
              .width('100%')
              .padding({ left: 4, right: 4, top: 8, bottom: 8 })
              .onClick(() => {
                this.togglePickItem(item);
              })
            }
          }, (item: AppPickItem) => item.bundleName)
        }
        .layoutWeight(1)
        .width('100%')
      }
      Button('完成')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(44)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.accent)
        .margin({ top: 12, bottom: 16 })
        .onClick(() => {
          this.closeSheet();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }
}

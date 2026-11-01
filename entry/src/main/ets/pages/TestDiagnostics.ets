import { common } from '@kit.AbilityKit';
import { PrefStore } from '../model/PrefStore';
import { AppSettings, defaultSettings } from '../model/AppState';
import { Theme } from '../ui/Theme';

@Component
export struct TestDiagnostics {
  @State testUrl: string = defaultSettings().testUrl;
  @State message: string = '';
  private prefs: PrefStore = new PrefStore();

  aboutToAppear(): void {
    const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
    this.prefs.init(ctx).then(async () => {
      const s = await this.prefs.getSettings();
      this.testUrl = s.testUrl;
    });
  }

  private async persist(): Promise<void> {
    const settings = await this.prefs.getSettings();
    settings.testUrl = this.testUrl.trim();
    if (settings.testUrl.length === 0) {
      settings.testUrl = defaultSettings().testUrl;
      this.testUrl = settings.testUrl;
    }
    await this.prefs.setSettings(settings);
    this.message = '已保存，节点测速与连通测试将使用新地址';
  }

  private restoreDefault(): void {
    this.testUrl = defaultSettings().testUrl;
    this.message = '已恢复默认，点保存后生效';
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Text('测速 URL')
            .fontSize(12)
            .fontColor(Theme.muted)
            .width('100%')
          Text('用于首页连通测试与节点页延迟，不影响 VPN 隧道建立')
            .fontSize(11)
            .fontColor(Theme.subtle)
            .width('100%')
            .margin({ top: 2, bottom: 8 })
          TextArea({ text: this.testUrl })
            .onChange((v) => this.testUrl = v)
            .backgroundColor(Theme.chip)
            .fontColor(Theme.text)
            .placeholderColor(Theme.subtle)
            .height(96)
            .borderRadius(10)

          Button('恢复默认测速地址')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(40)
            .fontColor(Theme.accent)
            .backgroundColor(Theme.accentSoft)
            .margin({ top: 12 })
            .onClick(() => this.restoreDefault())

          Button('保存')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(44)
            .fontColor('#FFFFFF')
            .backgroundColor(Theme.accent)
            .margin({ top: 12 })
            .onClick(() => {
              this.persist();
            })

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(13)
              .fontColor(Theme.ok)
              .width('100%')
              .margin({ top: 10 })
          }

          Text(`默认：${defaultSettings().testUrl}`)
            .fontSize(11)
            .fontColor(Theme.subtle)
            .width('100%')
            .margin({ top: 16 })
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
      .padding(16)
      .backgroundColor(Theme.bg)
    }
    .title('测速与诊断')
    .hideBackButton(false)
    .backgroundColor(Theme.bg)
  }
}

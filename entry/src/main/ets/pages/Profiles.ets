import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { ProfileStore } from '../model/ProfileStore';
import { PrefStore } from '../model/PrefStore';
import { ProfileRecord } from '../model/AppState';
import { Theme } from '../ui/Theme';

@Component
export struct Profiles {
  @State list: ProfileRecord[] = [];
  @State url: string = '';
  @State message: string = '';
  @State activeUuid: string = '';
  private store?: ProfileStore;
  private prefs: PrefStore = new PrefStore();

  aboutToAppear(): void {
    const filesDir = AppStorage.get('filesDir') as string;
    const ctx = AppStorage.get('uiContext') as common.UIAbilityContext;
    this.store = new ProfileStore(filesDir);
    this.prefs.init(ctx).then(async () => {
      this.activeUuid = await this.prefs.getActiveUuid();
      this.reload();
    });
  }

  private reload(): void {
    this.list = this.store?.list() ?? [];
  }

  private async pickFile(): Promise<void> {
    try {
      const document = new picker.DocumentViewPicker();
      const uris = await document.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['.yaml', '.yml', '.txt']
      });
      if (uris.length === 0) {
        return;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const yaml = String.fromCharCode(...new Uint8Array(buf));
      this.store!.importYaml('本地导入', yaml, uris[0]);
      this.message = '已导入本地配置，点「使用」后回首页连接';
      this.reload();
    } catch (e) {
      this.message = `文件导入失败 ${JSON.stringify(e)}`;
    }
  }

  private async importUrl(): Promise<void> {
    const target = this.url.trim();
    if (target.length < 8) {
      this.message = '请填写订阅 URL';
      return;
    }
    try {
      const extra: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000
      };
      const res = await http.createHttp().request(target, extra);
      const body = `${res.result}`;
      if (res.responseCode !== 200 || body.length < 8) {
        this.message = `订阅失败 HTTP ${res.responseCode}`;
        return;
      }
      const existing = this.list.find((item) => item.source === target);
      if (existing) {
        this.store!.updateYaml(existing.uuid, body);
        this.message = '已更新同一订阅';
      } else {
        this.store!.importYaml('订阅', body, target);
        this.message = '订阅已保存，请点「使用」';
      }
      this.reload();
    } catch (e) {
      this.message = `订阅失败 ${JSON.stringify(e)}`;
    }
  }

  private async activate(item: ProfileRecord): Promise<void> {
    await this.prefs.setActiveUuid(item.uuid);
    this.activeUuid = item.uuid;
    this.message = `已选用 ${item.name}`;
  }

  build() {
    NavDestination() {
    Column() {
      Column() {
        TextArea({ placeholder: 'https:// 订阅地址', text: this.url })
          .onChange((v) => this.url = v)
          .backgroundColor(Theme.chip)
          .fontColor(Theme.text)
          .placeholderColor(Theme.subtle)
          .height(96)
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        Row({ space: 10 }) {
          Button('导入文件')
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .height(40)
            .fontColor(Theme.accent)
            .backgroundColor(Theme.accentSoft)
            .onClick(() => this.pickFile())
          Button('拉取订阅')
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .height(40)
            .fontColor('#FFFFFF')
            .backgroundColor(Theme.accent)
            .onClick(() => this.importUrl())
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.card)
      .borderRadius(20)

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor(Theme.warn)
          .width('100%')
          .margin({ top: 10, bottom: 4 })
      }

      List() {
        ForEach(this.list, (item: ProfileRecord) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.name)
                  .fontSize(16)
                  .fontColor(Theme.text)
                  .fontWeight(FontWeight.Medium)
                Text(item.source)
                  .fontSize(11)
                  .fontColor(Theme.subtle)
                  .margin({ top: 4 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button(this.activeUuid === item.uuid ? '使用中' : '使用')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .height(32)
                .fontColor(this.activeUuid === item.uuid ? Theme.ok : '#FFFFFF')
                .backgroundColor(this.activeUuid === item.uuid ? '#E8F8E8' : Theme.accent)
                .onClick(() => this.activate(item))
              Button('删除')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .height(32)
                .fontColor(Theme.danger)
                .backgroundColor('#FDECEA')
                .margin({ left: 8 })
                .onClick(() => {
                  this.store?.remove(item.uuid);
                  this.reload();
                })
            }
            .width('100%')
            .padding(14)
          }
        }, (item: ProfileRecord) => item.uuid)
      }
      .layoutWeight(1)
      .width('100%')
      .margin({ top: 12 })
      .backgroundColor(Theme.card)
      .borderRadius(20)
      .padding({ top: 4, bottom: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(Theme.bg)
    }
    .title('订阅')
    .hideBackButton(false)
    .backgroundColor(Theme.bg)
  }
}

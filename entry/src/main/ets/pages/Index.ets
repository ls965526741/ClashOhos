import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HomeTab } from './HomeTab';
import { Proxies } from './Proxies';
import { Unlock } from './Unlock';
import { Settings } from './Settings';
import { Profiles } from './Profiles';
import { Providers } from './Providers';
import { Logs } from './Logs';
import { About } from './About';
import { TestDiagnostics } from './TestDiagnostics';
import { VpnTunnel } from './VpnTunnel';
import { APP_NAME } from '../common/Constants';
import { Theme } from '../ui/Theme';

@Entry
@Component
struct Index {
  @State navSub: string = '首页';
  private controller: TabsController = new TabsController();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    AppStorage.setOrCreate('mainTab', 0);
  }

  private makeTitle(): NavigationCommonTitle {
    const title: NavigationCommonTitle = {
      main: APP_NAME,
      sub: this.navSub
    };
    return title;
  }

  private tabIcon(normal: Resource, selected: Resource, text: string): BottomTabBarStyle {
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier(normal)
        .fontSize(24)
        .fontColor([Theme.subtle]),
      selected: new SymbolGlyphModifier(selected)
        .fontSize(24)
        .fontColor([Theme.accent])
    }, text)
      .iconStyle({ unselectedColor: Theme.subtle, selectedColor: Theme.accent });
  }

  private tabName(index: number): string {
    if (index === 1) {
      return '节点';
    }
    if (index === 2) {
      return '测试';
    }
    if (index === 3) {
      return '设置';
    }
    return '首页';
  }

  @Builder
  destMap(name: string) {
    if (name === 'Profiles') {
      Profiles()
    } else if (name === 'Providers') {
      Providers()
    } else if (name === 'Logs') {
      Logs()
    } else if (name === 'About') {
      About()
    } else if (name === 'TestDiagnostics') {
      TestDiagnostics()
    } else if (name === 'VpnTunnel') {
      VpnTunnel()
    }
  }

  build() {
    Navigation(this.pathStack) {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          Column() {
            HomeTab()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .tabBar(this.tabIcon($r('sys.symbol.house'), $r('sys.symbol.house_fill'), '首页'))

        TabContent() {
          Column() {
            Proxies()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .tabBar(this.tabIcon($r('sys.symbol.paperplane'), $r('sys.symbol.paperplane_fill'), '节点'))

        TabContent() {
          Column() {
            Unlock()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .tabBar(this.tabIcon($r('sys.symbol.checkmark_circle'), $r('sys.symbol.checkmark_circle_fill'), '测试'))

        TabContent() {
          Column() {
            Settings()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .tabBar(this.tabIcon($r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), '设置'))
      }
      .barMode(BarMode.Fixed)
      .barBackgroundColor(Theme.card)
      .onChange((index: number) => {
        this.navSub = this.tabName(index);
        AppStorage.setOrCreate('mainTab', index);
      })
      .width('100%')
      .height('100%')
    }
    .id('mainNav')
    .title(this.makeTitle())
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.destMap)
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}

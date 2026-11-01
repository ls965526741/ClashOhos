import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { LOG_DOMAIN, LOG_TAG } from '../common/Constants';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'EntryAbility onCreate (no libclash in UI process)');
    AppStorage.setOrCreate('filesDir', this.context.filesDir);
    AppStorage.setOrCreate('uiContext', this.context);
    AppStorage.setOrCreate('mainTab', 0);
    AppStorage.setOrCreate('proxyTick', 0);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'loadContent failed %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'loadContent ok');
    });
  }
}

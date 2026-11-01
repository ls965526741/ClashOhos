import clashOhos, { ClashOhosNative } from 'libclash_ohos.so';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { APP_VERSION_NAME, LOG_DOMAIN, LOG_TAG, MIHOMO_VERSION } from '../common/Constants';

/**
 * 仅允许 VpnExtensionAbility 引用。
 * 禁止 loadNativeModule：该 API 只允许 UI 主线程，VpnExtension 会 10200301。
 */
export class ClashCore {
  private static inited: boolean = false;
  private static cached: ClashOhosNative | undefined = undefined;

  static formatErr(e: Object): string {
    const be = e as BusinessError;
    const text = `${be.code ?? ''} ${be.message ?? ''}`.trim();
    return text.length > 0 ? text : `${e}`;
  }

  private static napi(): ClashOhosNative {
    if (ClashCore.cached !== undefined) {
      return ClashCore.cached;
    }
    const mod = clashOhos;
    const pingType = mod === undefined || mod === null ? 'null' : typeof mod.ping;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'static import libclash_ohos.so ping=%{public}s', pingType);
    if (mod === undefined || mod === null || typeof mod.ping !== 'function') {
      throw new Error('libclash_ohos.so 静态 import 失败（扩展进程不可用 loadNativeModule）');
    }
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'napi ping=%{public}s', mod.ping());
    } catch (e) {
      throw new Error(`napi ping throw: ${ClashCore.formatErr(e as Object)}`);
    }
    ClashCore.cached = mod;
    return ClashCore.cached;
  }

  static version(): string {
    try {
      return ClashCore.napi().coreVersion();
    } catch (e) {
      return `napi-error:${ClashCore.formatErr(e as Object)}`;
    }
  }

  static init(home: string): void {
    if (ClashCore.inited) {
      return;
    }
    ClashCore.napi().coreInit(home, MIHOMO_VERSION, 22);
    ClashCore.inited = true;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'vpn-process coreInit home=%{public}s', home);
  }

  static async load(path: string): Promise<string> {
    try {
      return await ClashCore.napi().load(path);
    } catch (e) {
      return `napi-throw: ${ClashCore.formatErr(e as Object)}`;
    }
  }

  static setSocketProtect(cb: (fd: number) => void): void {
    ClashCore.napi().setSocketProtect(cb);
  }

  static protectDone(): void {
    ClashCore.napi().protectDone();
  }

  static startTun(fd: number, stack: string, gateway: string, portal: string, dns: string): number {
    return ClashCore.napi().startTun(fd, stack, gateway, portal, dns);
  }

  static stopTun(): void {
    ClashCore.napi().stopTun();
  }
}

import { bundle, bundleManager } from '@kit.AbilityKit';

export class AppPickItem {
  bundleName: string = '';
  label: string = '';
}

export class AppPickLoadResult {
  items: AppPickItem[] = [];
  /** 列表为空时的说明（含权限限制） */
  hint: string = '';
}

function pushUnique(out: AppPickItem[], item: AppPickItem): void {
  for (let i = 0; i < out.length; i++) {
    if (out[i].bundleName === item.bundleName) {
      return;
    }
  }
  out.push(item);
}

function itemFromBundleInfo(info: bundleManager.BundleInfo): AppPickItem {
  const item = new AppPickItem();
  item.bundleName = info.name;
  const appInfo = info.appInfo;
  if (appInfo !== undefined && appInfo.label.length > 0) {
    item.label = appInfo.label;
  } else {
    item.label = info.name;
  }
  return item;
}

async function tryInstalledBundleList(out: AppPickItem[]): Promise<boolean> {
  try {
    const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
    const list = await bundleManager.getInstalledBundleList(flag);
    for (let i = 0; i < list.length; i++) {
      const info = list[i];
      if (info.appInfo !== undefined && !info.appInfo.enabled) {
        continue;
      }
      pushUnique(out, itemFromBundleInfo(info));
    }
    out.sort((a, b) => a.label.localeCompare(b.label));
    return out.length > 0;
  } catch (_e) {
    return false;
  }
}

async function tryLegacyAllApps(out: AppPickItem[]): Promise<boolean> {
  try {
    const flag = bundle.BundleFlag.GET_ALL_APPLICATION_INFO;
    const list = await bundle.getAllApplicationInfo(flag);
    for (let i = 0; i < list.length; i++) {
      const info = list[i];
      if (!info.enabled) {
        continue;
      }
      const item = new AppPickItem();
      item.bundleName = info.name;
      item.label = info.label.length > 0 ? info.label : info.name;
      pushUnique(out, item);
    }
    out.sort((a, b) => a.label.localeCompare(b.label));
    return out.length > 0;
  } catch (_e) {
    return false;
  }
}

/** 尝试读取全量列表；普通三方应用通常会失败，hint 会说明原因 */
export async function loadInstalledApps(): Promise<AppPickLoadResult> {
  const result = new AppPickLoadResult();
  if (await tryInstalledBundleList(result.items)) {
    return result;
  }
  if (await tryLegacyAllApps(result.items)) {
    return result;
  }
  result.hint =
    'HarmonyOS 不允许普通应用读取全部安装列表。请在下方输入包名，通过「验证并添加」加入；也可在系统「设置 → 应用」中查看包名。';
  return result;
}

/** 按包名查询已安装应用（仅需 GET_BUNDLE_INFO，适合 split-tunnel 配置） */
export async function lookupBundle(bundleName: string): Promise<AppPickItem | null> {
  const key = bundleName.trim();
  if (key.length === 0) {
    return null;
  }
  try {
    const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
    const info = await bundleManager.getBundleInfo(key, flag);
    return itemFromBundleInfo(info);
  } catch (_e) {
  }
  try {
    const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
    const info = await bundleManager.getBundleInfo(key, flag);
    return itemFromBundleInfo(info);
  } catch (_e2) {
  }
  return null;
}

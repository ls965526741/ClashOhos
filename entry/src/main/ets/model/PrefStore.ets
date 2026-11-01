import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppSettings, defaultSettings } from './AppState';

const STORE = 'clash_ohos_prefs';

function mergeSettings(raw: string): AppSettings {
  const out = defaultSettings();
  if (raw.length === 0) {
    return out;
  }
  try {
    const parsed = JSON.parse(raw) as AppSettings;
    out.enableIpv6 = parsed.enableIpv6;
    out.dns = parsed.dns && parsed.dns.length > 0 ? parsed.dns : out.dns;
    if (out.dns.indexOf('198.18.') >= 0) {
      out.dns = '172.19.0.2';
    }
    out.tunStack = parsed.tunStack && parsed.tunStack.length > 0 ? parsed.tunStack : out.tunStack;
    if (parsed.testUrl && parsed.testUrl.length > 0) {
      out.testUrl = parsed.testUrl;
    }
    if (parsed.access) {
      out.access.mode = parsed.access.mode;
      out.access.bundles = parsed.access.bundles;
    }
  } catch (_e) {
  }
  return out;
}

export class PrefStore {
  private pref: preferences.Preferences | null = null;

  async init(context: common.UIAbilityContext | common.ExtensionContext): Promise<void> {
    this.pref = await preferences.getPreferences(context, STORE);
  }

  async getActiveUuid(): Promise<string> {
    return (await this.pref?.get('activeUuid', '')) as string;
  }

  async setActiveUuid(uuid: string): Promise<void> {
    await this.pref?.put('activeUuid', uuid);
    await this.pref?.flush();
  }

  async getSettings(): Promise<AppSettings> {
    const raw = (await this.pref?.get('settings', '')) as string;
    return mergeSettings(raw);
  }

  async setSettings(settings: AppSettings): Promise<void> {
    await this.pref?.put('settings', JSON.stringify(settings));
    await this.pref?.flush();
  }

  async getOverrideJson(): Promise<string> {
    return (await this.pref?.get('overrideJson', '{}')) as string;
  }

  async setOverrideJson(json: string): Promise<void> {
    await this.pref?.put('overrideJson', json);
    await this.pref?.flush();
  }

  async getProxySessionJson(): Promise<string> {
    return (await this.pref?.get('proxySession', '{}')) as string;
  }

  async setProxySessionJson(json: string): Promise<void> {
    await this.pref?.put('proxySession', json);
    await this.pref?.flush();
  }
}

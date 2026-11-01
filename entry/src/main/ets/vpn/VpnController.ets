import { Want } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BUNDLE_NAME, LOG_DOMAIN, LOG_TAG, VPN_ABILITY } from '../common/Constants';

export class VpnStartParams {
  profilePath: string = '';
  enableIpv6: string = '0';
  tunStack: string = 'system';
  dns: string = '';
  accessMode: string = 'all';
  bundles: string = '';
}

export function vpnWant(params?: VpnStartParams): Want {
  const want: Want = {
    bundleName: BUNDLE_NAME,
    abilityName: VPN_ABILITY
  };
  if (params) {
    const map: Record<string, Object> = {};
    map['profilePath'] = params.profilePath;
    map['enableIpv6'] = params.enableIpv6;
    map['tunStack'] = params.tunStack;
    map['dns'] = params.dns;
    map['accessMode'] = params.accessMode;
    map['bundles'] = params.bundles;
    want.parameters = map;
  }
  return want;
}

export async function startVpn(params: VpnStartParams): Promise<string> {
  try {
    await vpnExtension.startVpnExtensionAbility(vpnWant(params));
    hilog.info(LOG_DOMAIN, LOG_TAG, 'startVpnExtensionAbility success');
    return '';
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(LOG_DOMAIN, LOG_TAG, 'startVpn failed %{public}s', JSON.stringify(err));
    return `${err.code}:${err.message}`;
  }
}

export async function stopVpn(): Promise<string> {
  try {
    await vpnExtension.stopVpnExtensionAbility(vpnWant());
    hilog.info(LOG_DOMAIN, LOG_TAG, 'stopVpnExtensionAbility success');
    return '';
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(LOG_DOMAIN, LOG_TAG, 'stopVpn failed %{public}s', JSON.stringify(err));
    return `${err.code}:${err.message}`;
  }
}

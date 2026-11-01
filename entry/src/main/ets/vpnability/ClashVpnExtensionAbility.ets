import { Want } from '@kit.AbilityKit';
import { vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClashCore } from '../native/ClashCore';
import { RuntimeBridge, RuntimeStatus } from '../model/RuntimeBridge';
import {
  LOG_DOMAIN,
  LOG_TAG,
  TUN_ADDRESS,
  TUN_DNS,
  TUN_GATEWAY,
  TUN_IPV6,
  TUN_IPV6_PREFIX,
  TUN_MTU,
  TUN_PORTAL,
  TUN_PREFIX
} from '../common/Constants';

export default class ClashVpnExtensionAbility extends VpnExtensionAbility {
  private conn: vpnExtension.VpnConnection | undefined = undefined;
  private runtime: RuntimeBridge | undefined = undefined;
  private timerId: number = -1;
  private tunFd: number = -1;

  onCreate(want: Want): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'VpnExtension onCreate');
    this.bootstrap(want);
  }

  onDestroy(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'VpnExtension onDestroy');
    this.teardown();
  }

  private async bootstrap(want: Want): Promise<void> {
    const filesDir = this.context.filesDir;
    this.runtime = new RuntimeBridge(filesDir);
    try {
      ClashCore.init(filesDir + '/clash');
      hilog.info(LOG_DOMAIN, LOG_TAG, 'vpn-process coreInit done');
      this.conn = vpnExtension.createVpnConnection(this.context);
      ClashCore.setSocketProtect((fd: number) => {
        const vpn = this.conn;
        if (vpn === undefined) {
          ClashCore.protectDone();
          return;
        }
        vpn.protect(fd).then(() => {
          ClashCore.protectDone();
        }).catch((e: BusinessError) => {
          hilog.warn(LOG_DOMAIN, LOG_TAG, 'protect fd=%{public}d %{public}s', fd, JSON.stringify(e));
          ClashCore.protectDone();
        });
      });
      try {
        await this.conn.protectProcessNet();
        hilog.info(LOG_DOMAIN, LOG_TAG, 'protectProcessNet ok');
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'protectProcessNet skip %{public}s', JSON.stringify(e));
      }

      const params = want.parameters;
      let profilePath = '';
      let enableIpv6 = false;
      let stack = 'system';
      let dns = TUN_DNS;
      let accessMode = 'all';
      let bundlesRaw = '';
      if (params) {
        profilePath = `${params['profilePath'] ?? ''}`;
        enableIpv6 = `${params['enableIpv6'] ?? '0'}` === '1';
        stack = `${params['tunStack'] ?? 'system'}`;
        dns = `${params['dns'] ?? TUN_DNS}`;
        if (dns.indexOf('198.18.') >= 0 || dns.length === 0) {
          dns = TUN_DNS;
        }
        accessMode = `${params['accessMode'] ?? 'all'}`;
        bundlesRaw = `${params['bundles'] ?? ''}`;
      }
      const bundles = bundlesRaw.length > 0 ? bundlesRaw.split(',') : [];

      if (profilePath.length > 0) {
        const loading = new RuntimeStatus();
        loading.connected = false;
        loading.lastError = '正在加载配置…';
        loading.controller = 'http://127.0.0.1:9090';
        loading.profilePath = profilePath;
        loading.updatedAt = Date.now();
        this.runtime.writeStatus(loading);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'clashLoad start %{public}s', profilePath);
        const loadErr = await ClashCore.load(profilePath);
        if (loadErr && loadErr.length > 0) {
          hilog.error(LOG_DOMAIN, LOG_TAG, 'clashLoad fail %{public}s', loadErr);
          this.fail(loadErr, profilePath);
          return;
        }
        hilog.info(LOG_DOMAIN, LOG_TAG, 'clashLoad done err=ok');
      }

      const config: vpnExtension.VpnConfig = {
        addresses: [
          { address: { address: TUN_ADDRESS, family: 1 }, prefixLength: TUN_PREFIX }
        ],
        mtu: TUN_MTU,
        dnsAddresses: dns.split(',').filter((item: string) => item.length > 0)
      };
      if (enableIpv6) {
        config.addresses?.push({
          address: { address: TUN_IPV6, family: 2 },
          prefixLength: TUN_IPV6_PREFIX
        });
      }
      if (accessMode === 'allow' && bundles.length > 0) {
        config.trustedApplications = bundles;
      } else if (accessMode === 'block' && bundles.length > 0) {
        config.blockedApplications = bundles;
      }

      this.tunFd = await this.conn.create(config);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'tunFd=%{public}d', this.tunFd);
      if (this.tunFd < 0) {
        this.fail('invalid tunFd', profilePath);
        return;
      }

      const gatewayCidr = `${TUN_ADDRESS}/${TUN_PREFIX}`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'startTun fd=%{public}d stack=%{public}s gw=%{public}s', this.tunFd, stack, gatewayCidr);
      const startRc = ClashCore.startTun(this.tunFd, stack, gatewayCidr, TUN_PORTAL, dns);
      if (startRc !== 0) {
        this.fail(`startTun=${startRc}`, profilePath);
        return;
      }

      const st = new RuntimeStatus();
      st.connected = true;
      st.tunFd = this.tunFd;
      st.lastError = '';
      st.coreVersion = ClashCore.version();
      st.profilePath = profilePath;
      st.controller = 'http://127.0.0.1:9090';
      st.updatedAt = Date.now();
      this.runtime.writeStatus(st);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'startTun rc=0 tunFd=%{public}d controller=%{public}s', this.tunFd, st.controller);

      this.timerId = -1;
    } catch (e) {
      const err = e as BusinessError;
      this.fail(`${err.code}:${err.message}`, '');
    }
  }

  private fail(message: string, profilePath: string): void {
    hilog.error(LOG_DOMAIN, LOG_TAG, 'vpn fail %{public}s', message);
    const st = new RuntimeStatus();
    st.connected = false;
    st.tunFd = -1;
    st.lastError = message;
    st.coreVersion = ClashCore.version();
    st.profilePath = profilePath;
    st.updatedAt = Date.now();
    this.runtime?.writeStatus(st);
  }

  private teardown(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    try {
      ClashCore.stopTun();
    } catch (_e) {
    }
    this.conn?.destroy().catch((e: BusinessError) => {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'destroy vpn %{public}s', JSON.stringify(e));
    });
    const st = new RuntimeStatus();
    st.connected = false;
    st.tunFd = -1;
    st.coreVersion = ClashCore.version();
    st.updatedAt = Date.now();
    this.runtime?.writeStatus(st);
  }
}

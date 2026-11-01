export interface Traffic {
  upload: number;
  download: number;
}

export interface ClashOhosNative {
  ping: () => string;
  coreVersion: () => string;
  coreInit: (home: string, versionName: string, sdkVersion: number) => void;
  reset: () => void;
  load: (path: string) => Promise<string>;
  fetchAndValid: (path: string, url: string, force: boolean) => Promise<string>;
  queryTunnelState: () => string;
  queryTrafficNow: () => Traffic;
  queryTrafficTotal: () => Traffic;
  queryGroupNames: (excludeNotSelectable: boolean) => string;
  queryGroup: (name: string, sort: string) => string;
  patchSelector: (group: string, name: string) => boolean;
  startTun: (fd: number, stack: string, gateway: string, portal: string, dns: string) => number;
  stopTun: () => void;
  setSocketProtect: (cb: (fd: number) => void) => void;
  protectDone: () => void;
  queryProviders: () => string;
  updateProvider: (type: string, name: string) => Promise<string>;
  healthCheck: (name: string) => Promise<void>;
  healthCheckAll: () => void;
  readOverride: (slot: number) => string;
  writeOverride: (slot: number, content: string) => void;
  clearOverride: (slot: number) => void;
  subscribeLogcat: () => void;
}

declare const clashOhos: ClashOhosNative;
export default clashOhos;

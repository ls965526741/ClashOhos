export interface ProfileRecord {
  uuid: string;
  name: string;
  source: string;
  updatedAt: number;
}

export class AccessControl {
  mode: string = 'all';
  bundles: string[] = [];
}

export class AppSettings {
  enableIpv6: boolean = false;
  dns: string = '172.19.0.2';
  tunStack: string = 'system';
  access: AccessControl = new AccessControl();
  testUrl: string = 'https://www.gstatic.com/generate_204';
}

export function defaultSettings(): AppSettings {
  return new AppSettings();
}

export class ProxySession {
  mode: string = '';
  selections: Record<string, string> = {};
}

export function emptyProxySession(): ProxySession {
  return new ProxySession();
}

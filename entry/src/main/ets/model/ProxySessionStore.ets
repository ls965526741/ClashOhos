import { ClashRest } from './ClashRest';
import { emptyProxySession, ProxySession } from './AppState';
import { PrefStore } from './PrefStore';
import { RuntimeBridge } from './RuntimeBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LOG_DOMAIN, LOG_TAG } from '../common/Constants';

function parseSession(raw: string): ProxySession {
  const out = emptyProxySession();
  if (raw.length === 0) {
    return out;
  }
  try {
    const parsed = JSON.parse(raw) as ProxySession;
    out.mode = `${parsed.mode ?? ''}`;
    if (parsed.selections) {
      out.selections = parsed.selections;
    }
  } catch (_e) {
  }
  return out;
}

export async function loadProxySession(prefs: PrefStore): Promise<ProxySession> {
  const raw = await prefs.getProxySessionJson();
  return parseSession(raw);
}

export async function saveProxyMode(prefs: PrefStore, mode: string): Promise<void> {
  const session = await loadProxySession(prefs);
  session.mode = mode;
  await prefs.setProxySessionJson(JSON.stringify(session));
}

export async function saveGroupSelection(prefs: PrefStore, group: string, node: string): Promise<void> {
  const session = await loadProxySession(prefs);
  session.selections[group] = node;
  await prefs.setProxySessionJson(JSON.stringify(session));
}

export async function applyProxySession(
  prefs: PrefStore,
  runtime: RuntimeBridge | undefined
): Promise<void> {
  const session = await loadProxySession(prefs);
  if (session.mode.length > 0) {
    try {
      const code = await ClashRest.patchJson('/configs', JSON.stringify({ mode: session.mode }), runtime);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'restore mode=%{public}s code=%{public}d', session.mode, code);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'restore mode fail %{public}s', ClashRest.formatErr(e as Object));
    }
  }
  const groups = Object.keys(session.selections);
  for (let i = 0; i < groups.length; i++) {
    const group = groups[i];
    const node = session.selections[group];
    if (node.length === 0) {
      continue;
    }
    try {
      const code = await ClashRest.putJson(
        `/proxies/${encodeURIComponent(group)}`,
        JSON.stringify({ name: node }),
        runtime
      );
      hilog.info(LOG_DOMAIN, LOG_TAG, 'restore proxy %{public}s -> %{public}s code=%{public}d', group, node, code);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'restore proxy fail %{public}s', ClashRest.formatErr(e as Object));
    }
  }
  const tick = (AppStorage.get('proxyTick') as number) ?? 0;
  AppStorage.setOrCreate('proxyTick', tick + 1);
}

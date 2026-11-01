import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CONTROLLER_URL, LOG_DOMAIN, LOG_TAG } from '../common/Constants';
import { RuntimeBridge } from './RuntimeBridge';

export class ClashRest {
  static baseUrl(runtime?: RuntimeBridge): string {
    const fromStatus = runtime?.readStatus().controller ?? '';
    return fromStatus.length > 0 ? fromStatus : CONTROLLER_URL;
  }

  static async getRaw(path: string, runtime?: RuntimeBridge, timeoutMs?: number): Promise<ClashRestRaw> {
    const t = timeoutMs !== undefined ? timeoutMs : 3000;
    const url = `${ClashRest.baseUrl(runtime)}${path}`;
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: t,
      readTimeout: t
    };
    const res = await http.createHttp().request(url, extra);
    const out = new ClashRestRaw();
    out.code = res.responseCode;
    out.body = `${res.result}`;
    return out;
  }

  static async getText(path: string, runtime?: RuntimeBridge, timeoutMs?: number): Promise<string> {
    const raw = await ClashRest.getRaw(path, runtime, timeoutMs);
    if (raw.code !== 200) {
      throw new Error(`GET ${path} HTTP ${raw.code} ${raw.body.slice(0, 80)}`);
    }
    return raw.body;
  }

  static async putJson(path: string, body: string, runtime?: RuntimeBridge): Promise<number> {
    const url = `${ClashRest.baseUrl(runtime)}${path}`;
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.PUT,
      extraData: body,
      header: { 'Content-Type': 'application/json' },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 3000,
      readTimeout: 3000
    };
    const res = await http.createHttp().request(url, extra);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'REST PUT %{public}s -> %{public}d', path, res.responseCode);
    return res.responseCode;
  }

  static async patchJson(path: string, body: string, runtime?: RuntimeBridge): Promise<number> {
    const url = `${ClashRest.baseUrl(runtime)}${path}`;
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.PATCH,
      extraData: body,
      header: { 'Content-Type': 'application/json' },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 5000
    };
    const res = await http.createHttp().request(url, extra);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'REST PATCH %{public}s -> %{public}d', path, res.responseCode);
    return res.responseCode;
  }

  static async deleteNoBody(path: string, runtime?: RuntimeBridge): Promise<number> {
    const url = `${ClashRest.baseUrl(runtime)}${path}`;
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.DELETE,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 3000,
      readTimeout: 3000
    };
    const res = await http.createHttp().request(url, extra);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'REST DELETE %{public}s -> %{public}d', path, res.responseCode);
    return res.responseCode;
  }

  static async putNoBody(path: string, timeoutMs: number, runtime?: RuntimeBridge): Promise<number> {
    const url = `${ClashRest.baseUrl(runtime)}${path}`;
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.PUT,
      extraData: '{}',
      header: { 'Content-Type': 'application/json' },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };
    const res = await http.createHttp().request(url, extra);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'REST PUT %{public}s -> %{public}d', path, res.responseCode);
    return res.responseCode;
  }

  static formatErr(e: Object): string {
    const be = e as BusinessError;
    const fromBe = `${be.code ?? ''} ${be.message ?? ''}`.trim();
    if (fromBe.length > 0) {
      return fromBe;
    }
    try {
      const asErr = e as Error;
      if (asErr.message && asErr.message.length > 0) {
        return asErr.message;
      }
    } catch (_ignored) {
    }
    return `${e}`;
  }
}

export class ClashRestRaw {
  code: number = 0;
  body: string = '';
}

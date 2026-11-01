import { http } from '@kit.NetworkKit';

export const UNLOCK_UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

export class UnlockHttpResult {
  code: number = 0;
  body: string = '';
  location: string = '';
  setCookie: string = '';
}

export class UnlockHttp {
  static async get(url: string, cookie: string, timeoutMs: number): Promise<UnlockHttpResult> {
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs,
      header: {
        'User-Agent': UNLOCK_UA,
        'Accept': '*/*',
        'Cookie': cookie
      }
    };
    const res = await http.createHttp().request(url, extra);
    return UnlockHttp.fromRes(res);
  }

  static async post(url: string, body: string, contentType: string, auth: string,
    timeoutMs: number): Promise<UnlockHttpResult> {
    const extra: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      extraData: body,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs,
      header: {
        'User-Agent': UNLOCK_UA,
        'Accept': '*/*',
        'Content-Type': contentType,
        'authorization': auth
      }
    };
    const res = await http.createHttp().request(url, extra);
    return UnlockHttp.fromRes(res);
  }

  private static fromRes(res: http.HttpResponse): UnlockHttpResult {
    const out = new UnlockHttpResult();
    out.code = res.responseCode;
    out.body = `${res.result}`;
    const raw = JSON.stringify(res.header);
    out.location = UnlockHttp.pickHeader(raw, 'location');
    out.setCookie = UnlockHttp.pickHeader(raw, 'set-cookie');
    return out;
  }

  private static pickHeader(raw: string, key: string): string {
    const lower = raw.toLowerCase();
    const needle = `"${key}":"`;
    const i = lower.indexOf(needle);
    if (i < 0) {
      return '';
    }
    const start = i + needle.length;
    const rest = raw.substring(start);
    const end = rest.indexOf('"');
    if (end < 0) {
      return '';
    }
    return rest.substring(0, end);
  }
}

export function quotedField(body: string, key: string): string {
  const a = `"${key}":"`;
  let i = body.indexOf(a);
  if (i < 0) {
    const b = `"${key}": "`;
    i = body.indexOf(b);
    if (i < 0) {
      return '';
    }
    const start = i + b.length;
    const rest = body.substring(start);
    const end = rest.indexOf('"');
    return end < 0 ? '' : rest.substring(0, end);
  }
  const start = i + a.length;
  const rest = body.substring(start);
  const end = rest.indexOf('"');
  return end < 0 ? '' : rest.substring(0, end);
}

export function traceLoc(body: string): string {
  const lines = body.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.indexOf('loc=') === 0) {
      return line.substring(4).trim().toUpperCase();
    }
  }
  return '';
}

export function nowStamp(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

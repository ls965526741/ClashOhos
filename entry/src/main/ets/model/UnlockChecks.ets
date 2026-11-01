import { UnlockHttp, UnlockHttpResult, nowStamp, quotedField, traceLoc } from './UnlockHttp';

export class UnlockItemVm {
  name: string = '';
  status: string = 'Pending';
  region: string = '';
  time: string = '';
}

interface BiliJson {
  code?: number;
}

const TIMEOUT = 15000;
const DISNEY_AUTH = 'Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84';
const CLAUDE_BLOCKED: string[] = ['AF', 'BY', 'CN', 'CU', 'HK', 'IR', 'KP', 'MO', 'RU', 'SY'];
const GEMINI_BLOCKED: string[] = ['CHN', 'RUS', 'BLR', 'CUB', 'IRN', 'PRK', 'SYR', 'HKG', 'MAC'];

export const UNLOCK_NAMES: string[] = [
  '哔哩哔哩大陆',
  '哔哩哔哩港澳台',
  'Bahamut Anime',
  'ChatGPT Web',
  'Claude',
  'Disney+',
  'Gemini',
  'Netflix',
  'Prime Video',
  'Spotify',
  'TikTok',
  'YouTube Premium',
  'P站',
  '谷歌'
];

export function defaultUnlockItems(): UnlockItemVm[] {
  const list: UnlockItemVm[] = [];
  for (let i = 0; i < UNLOCK_NAMES.length; i++) {
    const item = new UnlockItemVm();
    item.name = UNLOCK_NAMES[i];
    item.status = 'Pending';
    list.push(item);
  }
  return list;
}

export async function runUnlockCheck(name: string): Promise<UnlockItemVm> {
  try {
    if (name === '哔哩哔哩大陆') {
      return await checkBili(
        name,
        'https://api.bilibili.com/pgc/player/web/playurl?avid=82846771&qn=0&type=&otype=json&ep_id=307247&fourk=1&fnver=0&fnval=16&module=bangumi'
      );
    }
    if (name === '哔哩哔哩港澳台') {
      return await checkBili(
        name,
        'https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&module=bangumi'
      );
    }
    if (name === 'Bahamut Anime') {
      return await checkBahamut();
    }
    if (name === 'ChatGPT Web') {
      return await checkChatGptWeb();
    }
    if (name === 'Claude') {
      return await checkClaude();
    }
    if (name === 'Disney+') {
      return await checkDisney();
    }
    if (name === 'Gemini') {
      return await checkGemini();
    }
    if (name === 'Netflix') {
      return await checkNetflix();
    }
    if (name === 'Prime Video') {
      return await checkPrime();
    }
    if (name === 'Spotify') {
      return await checkSpotify();
    }
    if (name === 'TikTok') {
      return await checkTikTok();
    }
    if (name === 'YouTube Premium') {
      return await checkYoutube();
    }
    if (name === 'P站') {
      return await checkPornhub();
    }
    if (name === '谷歌') {
      return await checkGoogle();
    }
  } catch (_e) {
    return failed(name);
  }
  return failed(name);
}

function done(name: string, status: string, region: string): UnlockItemVm {
  const item = new UnlockItemVm();
  item.name = name;
  item.status = status;
  item.region = region;
  item.time = nowStamp();
  return item;
}

function failed(name: string): UnlockItemVm {
  return done(name, 'Failed', '');
}

function contains(body: string, needle: string): boolean {
  return body.toLowerCase().indexOf(needle.toLowerCase()) >= 0;
}

function inList(code: string, list: string[]): boolean {
  for (let i = 0; i < list.length; i++) {
    if (list[i] === code) {
      return true;
    }
  }
  return false;
}

async function checkBili(name: string, url: string): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get(url, '', TIMEOUT);
  try {
    const json = JSON.parse(res.body) as BiliJson;
    const code = json.code !== undefined ? json.code : -1;
    if (code === 0) {
      return done(name, 'Yes', '');
    }
    if (code === -10403) {
      return done(name, 'No', '');
    }
    return failed(name);
  } catch (e) {
    return failed(name);
  }
}

async function checkBahamut(): Promise<UnlockItemVm> {
  const device = await UnlockHttp.get('https://ani.gamer.com.tw/ajax/getdeviceid.php', '', TIMEOUT);
  const deviceId = quotedField(device.body, 'deviceid');
  if (deviceId.length === 0) {
    return failed('Bahamut Anime');
  }
  const tokenUrl =
    `https://ani.gamer.com.tw/ajax/token.php?adID=89422&sn=37783&device=${deviceId}`;
  const token = await UnlockHttp.get(tokenUrl, device.setCookie, TIMEOUT);
  if (token.body.indexOf('animeSn') < 0) {
    return done('Bahamut Anime', 'No', '');
  }
  const home = await UnlockHttp.get('https://ani.gamer.com.tw/', device.setCookie, TIMEOUT);
  let region = '';
  const geoKey = 'data-geo="';
  const gi = home.body.indexOf(geoKey);
  if (gi >= 0) {
    const rest = home.body.substring(gi + geoKey.length);
    const end = rest.indexOf('"');
    if (end > 0) {
      region = rest.substring(0, end);
    }
  }
  return done('Bahamut Anime', 'Yes', region);
}

async function checkChatGptWeb(): Promise<UnlockItemVm> {
  let region = '';
  try {
    const trace = await UnlockHttp.get('https://chat.openai.com/cdn-cgi/trace', '', TIMEOUT);
    region = traceLoc(trace.body);
  } catch (e) {
    region = '';
  }
  const web = await UnlockHttp.get('https://api.openai.com/compliance/cookie_requirements', '', TIMEOUT);
  if (contains(web.body, 'unsupported_country')) {
    return done('ChatGPT Web', 'No', region);
  }
  if (web.code >= 200 && web.code < 500) {
    return done('ChatGPT Web', 'Yes', region);
  }
  return failed('ChatGPT Web');
}

async function checkClaude(): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get('https://claude.ai/cdn-cgi/trace', '', TIMEOUT);
  const loc = traceLoc(res.body);
  if (loc.length === 0) {
    return failed('Claude');
  }
  if (inList(loc, CLAUDE_BLOCKED)) {
    return done('Claude', 'No', loc);
  }
  return done('Claude', 'Yes', loc);
}

async function checkDisney(): Promise<UnlockItemVm> {
  const deviceBody =
    '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}';
  const device = await UnlockHttp.post(
    'https://disney.api.edge.bamgrid.com/devices',
    deviceBody,
    'application/json; charset=UTF-8',
    DISNEY_AUTH,
    TIMEOUT
  );
  if (device.code === 403) {
    return done('Disney+', 'No', '');
  }
  const home = await UnlockHttp.get('https://www.disneyplus.com/', '', TIMEOUT);
  const body = home.body;
  if (contains(body, 'unavailable') || contains(home.location, 'preview') || contains(home.location, 'unavailable')) {
    return done('Disney+', 'No', '');
  }
  let region = quotedField(body, 'countryCode');
  if (region.length === 0) {
    region = quotedField(body, 'region');
  }
  if (contains(body, '"inSupportedLocation":false')) {
    return done('Disney+', 'No', region);
  }
  if (home.code >= 200 && home.code < 400) {
    return done('Disney+', 'Yes', region);
  }
  return failed('Disney+');
}

async function checkGemini(): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get('https://gemini.google.com', '', TIMEOUT);
  const marker = ',2,1,200,"';
  const i = res.body.indexOf(marker);
  if (i < 0) {
    return failed('Gemini');
  }
  const code = res.body.substring(i + marker.length, i + marker.length + 3);
  if (code.length !== 3) {
    return failed('Gemini');
  }
  if (inList(code, GEMINI_BLOCKED)) {
    return done('Gemini', 'No', code);
  }
  return done('Gemini', 'Yes', code);
}

async function checkNetflix(): Promise<UnlockItemVm> {
  const a = await UnlockHttp.get('https://www.netflix.com/title/81280792', '', TIMEOUT);
  const b = await UnlockHttp.get('https://www.netflix.com/title/70143836', '', TIMEOUT);
  if (a.code === 404 && b.code === 404) {
    return done('Netflix', 'Originals', '');
  }
  if (a.code === 403 || b.code === 403) {
    return done('Netflix', 'No', '');
  }
  if (a.code === 200 || a.code === 301 || a.code === 302 || b.code === 200 || b.code === 301 ||
    b.code === 302) {
    const locRes = await UnlockHttp.get('https://www.netflix.com/title/80018499', '', TIMEOUT);
    const loc = locRes.location.length > 0 ? locRes.location : locRes.body;
    const parts = loc.split('/');
    let region = '';
    if (parts.length >= 4) {
      region = parts[3].split('-')[0];
    }
    return done('Netflix', 'Yes', region);
  }
  return failed('Netflix');
}

async function checkPrime(): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get('https://www.primevideo.com', '', TIMEOUT);
  if (contains(res.body, 'isServiceRestricted')) {
    return done('Prime Video', 'No', '');
  }
  const region = quotedField(res.body, 'currentTerritory');
  if (region.length > 0) {
    return done('Prime Video', 'Yes', region);
  }
  return failed('Prime Video');
}

async function checkSpotify(): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get(
    'https://www.spotify.com/api/content/v1/country-selector?platform=web&format=json',
    '',
    TIMEOUT
  );
  if (res.code === 403 || res.code === 451) {
    return done('Spotify', 'No', '');
  }
  if (res.code < 200 || res.code >= 300) {
    return failed('Spotify');
  }
  if (contains(res.body, 'not available in your country')) {
    return done('Spotify', 'No', '');
  }
  let region = quotedField(res.body, 'countryCode');
  if (region.length === 0) {
    region = quotedField(res.body, 'country');
  }
  return done('Spotify', 'Yes', region.toUpperCase());
}

async function checkTikTok(): Promise<UnlockItemVm> {
  let res: UnlockHttpResult;
  try {
    res = await UnlockHttp.get('https://www.tiktok.com/cdn-cgi/trace', '', TIMEOUT);
  } catch (e) {
    res = new UnlockHttpResult();
  }
  let status = tiktokStatus(res);
  let region = traceLoc(res.body);
  if (region.length === 0) {
    region = quotedField(res.body, 'region');
  }
  if (status === 'Failed' || region.length === 0) {
    const home = await UnlockHttp.get('https://www.tiktok.com/', '', TIMEOUT);
    if (status !== 'No') {
      status = tiktokStatus(home);
    }
    if (region.length === 0) {
      region = quotedField(home.body, 'region');
    }
  }
  return done('TikTok', status, region.toUpperCase());
}

function tiktokStatus(res: UnlockHttpResult): string {
  if (res.code === 403 || res.code === 451) {
    return 'No';
  }
  if (res.code < 200 || res.code >= 300) {
    return 'Failed';
  }
  if (contains(res.body, 'access denied') || contains(res.body, 'not available in your region') ||
    contains(res.body, 'tiktok is not available')) {
    return 'No';
  }
  return 'Yes';
}

async function checkYoutube(): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get('https://www.youtube.com/premium', '', TIMEOUT);
  const body = res.body;
  if (contains(body, 'youtube premium is not available in your country')) {
    return done('YouTube Premium', 'No', '');
  }
  if (contains(body, 'ad-free')) {
    let region = '';
    const mark = 'id="country-code"';
    const i = body.indexOf(mark);
    if (i >= 0) {
      const gt = body.indexOf('>', i);
      const lt = body.indexOf('<', gt);
      if (gt >= 0 && lt > gt) {
        region = body.substring(gt + 1, lt).trim();
      }
    }
    return done('YouTube Premium', 'Yes', region);
  }
  return failed('YouTube Premium');
}

async function checkPornhub(): Promise<UnlockItemVm> {
  const res = await UnlockHttp.get('https://www.pornhub.com/', '', TIMEOUT);
  if (res.code === 403 || res.code === 451) {
    return done('P站', 'No', '');
  }
  if (res.code < 200 || res.code >= 400) {
    return failed('P站');
  }
  if (contains(res.body, 'geoBlocked') ||
    contains(res.body, 'not available in your country') ||
    contains(res.body, 'this content is unavailable in your country') ||
    contains(res.body, 'access has been denied')) {
    return done('P站', 'No', '');
  }
  let region = quotedField(res.body, 'countryCode');
  if (region.length === 0) {
    region = quotedField(res.body, 'country');
  }
  return done('P站', 'Yes', region.toUpperCase());
}

async function checkGoogle(): Promise<UnlockItemVm> {
  const probe = await UnlockHttp.get('https://www.google.com/generate_204', '', TIMEOUT);
  if (probe.code === 204 || probe.code === 200) {
    let region = '';
    try {
      const home = await UnlockHttp.get('https://www.google.com/', '', TIMEOUT);
      if (contains(home.body, 'unusual traffic') || contains(home.body, '/sorry/')) {
        return done('谷歌', 'No', '');
      }
      region = quotedField(home.body, 'gl');
      if (region.length === 0) {
        const hl = quotedField(home.body, 'hl');
        if (hl.indexOf('-') > 0) {
          region = hl.split('-')[1].toUpperCase();
        }
      }
    } catch (e) {
      region = '';
    }
    return done('谷歌', 'Yes', region.toUpperCase());
  }
  if (probe.code === 403 || probe.code === 451) {
    return done('谷歌', 'No', '');
  }
  try {
    const home = await UnlockHttp.get('https://www.google.com/ncr', '', TIMEOUT);
    if (home.code >= 200 && home.code < 400) {
      if (contains(home.body, 'unusual traffic') || contains(home.body, '/sorry/')) {
        return done('谷歌', 'No', '');
      }
      return done('谷歌', 'Yes', '');
    }
    if (home.code === 403 || home.code === 451) {
      return done('谷歌', 'No', '');
    }
  } catch (e) {
    return failed('谷歌');
  }
  return failed('谷歌');
}

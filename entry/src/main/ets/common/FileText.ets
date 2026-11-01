import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export function ensureDir(path: string): void {
  if (!fs.accessSync(path)) {
    fs.mkdirSync(path, true);
  }
}

export function writeText(path: string, text: string): void {
  const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
  const encoder = new util.TextEncoder();
  const bytes = encoder.encodeInto(text);
  fs.writeSync(file.fd, bytes.buffer);
  fs.closeSync(file);
}

export function readText(path: string): string {
  if (!fs.accessSync(path)) {
    return '';
  }
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  const stat = fs.statSync(file.fd);
  const buf = new ArrayBuffer(stat.size);
  fs.readSync(file.fd, buf);
  fs.closeSync(file);
  const decoder = util.TextDecoder.create('utf-8');
  return decoder.decodeToString(new Uint8Array(buf));
}

import { fileIo as fs } from '@kit.CoreFileKit';
import { ProfileRecord } from './AppState';
import { ensureDir, readText, writeText } from '../common/FileText';

const INDEX_NAME = 'profiles.json';

export class ProfileStore {
  private root: string;
  private indexPath: string;

  constructor(filesDir: string) {
    this.root = filesDir + '/profiles';
    this.indexPath = this.root + '/' + INDEX_NAME;
    ensureDir(this.root);
  }

  list(): ProfileRecord[] {
    const content = readText(this.indexPath);
    if (content.length === 0) {
      return [];
    }
    try {
      return JSON.parse(content) as ProfileRecord[];
    } catch (_e) {
      return [];
    }
  }

  saveList(list: ProfileRecord[]): void {
    ensureDir(this.root);
    writeText(this.indexPath, JSON.stringify(list));
  }

  profileDir(uuid: string): string {
    return this.root + '/' + uuid;
  }

  configPath(uuid: string): string {
    return this.profileDir(uuid) + '/config.yaml';
  }

  importYaml(name: string, yaml: string, source: string): ProfileRecord {
    const uuid = `${Date.now().toString(16)}-${Math.floor(Math.random() * 1e9).toString(16)}`;
    const dir = this.profileDir(uuid);
    ensureDir(dir);
    writeText(this.configPath(uuid), yaml);
    const rec: ProfileRecord = {
      uuid: uuid,
      name: name,
      source: source,
      updatedAt: Date.now()
    };
    const list = this.list();
    list.push(rec);
    this.saveList(list);
    return rec;
  }

  updateYaml(uuid: string, yaml: string): void {
    writeText(this.configPath(uuid), yaml);
    const list = this.list();
    for (let i = 0; i < list.length; i++) {
      if (list[i].uuid === uuid) {
        list[i].updatedAt = Date.now();
      }
    }
    this.saveList(list);
  }

  remove(uuid: string): void {
    const dir = this.profileDir(uuid);
    if (fs.accessSync(dir)) {
      fs.rmdirSync(dir);
    }
    const next: ProfileRecord[] = [];
    const list = this.list();
    for (let i = 0; i < list.length; i++) {
      if (list[i].uuid !== uuid) {
        next.push(list[i]);
      }
    }
    this.saveList(next);
  }
}

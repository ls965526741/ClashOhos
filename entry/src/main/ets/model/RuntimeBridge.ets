import { ensureDir, readText, writeText } from '../common/FileText';

export class RuntimeStatus {
  connected: boolean = false;
  tunFd: number = -1;
  lastError: string = '';
  coreVersion: string = '';
  profilePath: string = '';
  controller: string = '';
  updatedAt: number = 0;
}

export class RuntimeCommand {
  action: string = 'none';
  group: string = '';
  name: string = '';
  content: string = '';
}

export class RuntimeBridge {
  private dir: string;

  constructor(filesDir: string) {
    this.dir = filesDir + '/runtime';
    ensureDir(this.dir);
  }

  statusPath(): string {
    return this.dir + '/status.json';
  }

  commandPath(): string {
    return this.dir + '/command.json';
  }

  logPath(): string {
    return this.dir + '/logcat.jsonl';
  }

  restLastPath(): string {
    return this.dir + '/rest-last.txt';
  }

  writeRestLast(line: string): void {
    writeText(this.restLastPath(), `${Date.now()} ${line}`);
  }

  writeStatus(status: RuntimeStatus): void {
    writeText(this.statusPath(), JSON.stringify(status));
  }

  markDisconnected(reason: string): void {
    const st = new RuntimeStatus();
    st.connected = false;
    st.tunFd = -1;
    st.lastError = reason;
    st.updatedAt = Date.now();
    this.writeStatus(st);
  }

  readStatus(): RuntimeStatus {
    const raw = readText(this.statusPath());
    const st = new RuntimeStatus();
    if (raw.length === 0) {
      return st;
    }
    try {
      const obj = JSON.parse(raw) as RuntimeStatus;
      st.connected = obj.connected;
      st.tunFd = obj.tunFd;
      st.lastError = obj.lastError;
      st.coreVersion = obj.coreVersion;
      st.profilePath = obj.profilePath;
      st.controller = obj.controller;
      st.updatedAt = obj.updatedAt;
      return st;
    } catch (_e) {
      return st;
    }
  }

  writeCommand(cmd: RuntimeCommand): void {
    writeText(this.commandPath(), JSON.stringify(cmd));
  }

  readCommand(): RuntimeCommand {
    const raw = readText(this.commandPath());
    const cmd = new RuntimeCommand();
    if (raw.length === 0) {
      return cmd;
    }
    try {
      const obj = JSON.parse(raw) as RuntimeCommand;
      cmd.action = obj.action;
      cmd.group = obj.group;
      cmd.name = obj.name;
      cmd.content = obj.content;
      return cmd;
    } catch (_e) {
      return cmd;
    }
  }

  appendLog(line: string): void {
    const prev = readText(this.logPath());
    const parts = (prev + line + '\n').split('\n');
    const keep = parts.length > 400 ? parts.slice(parts.length - 400) : parts;
    writeText(this.logPath(), keep.join('\n'));
  }

  readLogs(): string {
    return readText(this.logPath());
  }
}

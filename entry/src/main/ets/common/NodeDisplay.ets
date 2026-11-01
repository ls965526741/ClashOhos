/** 展示用节点名：去掉订阅前缀（如 iGG-01 - 香港） */
export function displayNodeName(full: string): string {
  const idx = full.indexOf(' - ');
  if (idx >= 0 && idx + 3 < full.length) {
    return full.substring(idx + 3);
  }
  return full;
}

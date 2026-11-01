/** 应用版本（与 AppScope/app.json5 保持一致） */
export const APP_VERSION_NAME = '0.1.0';
export const APP_VERSION_CODE = 100;
/** 内置 mihomo / libclash 核心版本（与 CMFA 2.11.36 对齐） */
export const MIHOMO_VERSION = '2.11.36';

/** 应用显示名（与 AppScope/entry 的 string.json 中 app_name 等保持一致） */
export const APP_NAME = 'ClashOhos';
/** 与 AppScope/app.json5 的 bundleName 必须一致 */
export const BUNDLE_NAME = 'com.clashohos.app';
export const VPN_ABILITY = 'ClashVpnExtensionAbility';
export const LOG_DOMAIN = 0x3200;
export const LOG_TAG = 'ClashOhos';
export const CONTROLLER_URL = 'http://127.0.0.1:9090';
/** 发布到 GitHub 后请改为本仓库地址，供「关于」页展示 */
export const SOURCE_CODE_URL = 'https://github.com/ls965526741/ClashOhos';

export const TUN_ADDRESS = '172.19.0.1';
export const TUN_PREFIX = 30;
export const TUN_GATEWAY = '172.19.0.1';
export const TUN_PORTAL = '172.19.0.2';
export const TUN_DNS = '172.19.0.2';
export const TUN_MTU = 1400;
export const TUN_IPV6 = 'fdfe:dcba:9876::1';
export const TUN_IPV6_PREFIX = 126;

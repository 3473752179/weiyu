export class RemoteWritingConfig {
  // localhost 配合 hdc rport 最稳定；10.0.2.2 作为不同模拟器实现的兼容回退。
  // 部署后把 HTTPS 地址放在数组首位即可。
  static readonly API_BASE_URLS: Array<string> = [
    'http://127.0.0.1:8787',
    'http://10.0.2.2:8787'
  ];
  static readonly CONNECT_TIMEOUT_MS: number = 2500;
  static readonly READ_TIMEOUT_MS: number = 6000;
}

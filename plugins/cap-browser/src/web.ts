import { WebPlugin } from '@capacitor/core';

import type { CapBrowserPlugin, OpenOptions, OpenWebViewOptions } from './definitions';
import { registerPlugin } from '@capacitor/core';

export class CapBrowserWeb extends WebPlugin implements CapBrowserPlugin {
  async open(options: OpenOptions): Promise<any> {
    console.log(options);
    return true;
  }
  
  async close(): Promise<any> {
    return true;
  }
  
  async openWebView(options: OpenWebViewOptions): Promise<any> {
    console.log(options);
    return true;
  }
}

const CapBrowser = registerPlugin<CapBrowserPlugin>('CapBrowser', {
  web: () => import('./web').then(m => new m.CapBrowserWeb())
});


export * from './definitions';
export { CapBrowser };

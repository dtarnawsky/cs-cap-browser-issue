import { registerPlugin } from '@capacitor/core';

import type { CapBrowserPlugin } from './definitions';

const CapBrowser = registerPlugin<CapBrowserPlugin>('CapBrowser', {
  web: () => import('./web').then(m => new m.CapBrowserWeb()),
});

export * from './definitions';
export { CapBrowser };
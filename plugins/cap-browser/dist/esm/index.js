import { registerPlugin } from '@capacitor/core';
const CapBrowser = registerPlugin('CapBrowser', {
    web: () => import('./web').then(m => new m.CapBrowserWeb()),
});
export * from './definitions';
export { CapBrowser };
//# sourceMappingURL=index.js.map
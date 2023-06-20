import { WebPlugin } from '@capacitor/core';
import { registerPlugin } from '@capacitor/core';
export class CapBrowserWeb extends WebPlugin {
    async open(options) {
        console.log(options);
        return true;
    }
    async close() {
        return true;
    }
    async openWebView(options) {
        console.log(options);
        return true;
    }
}
const CapBrowser = registerPlugin('CapBrowser', {
    web: () => import('./web').then(m => new m.CapBrowserWeb())
});
export * from './definitions';
export { CapBrowser };
//# sourceMappingURL=web.js.map
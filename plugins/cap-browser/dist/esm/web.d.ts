import { WebPlugin } from '@capacitor/core';
import type { CapBrowserPlugin, OpenOptions, OpenWebViewOptions } from './definitions';
export declare class CapBrowserWeb extends WebPlugin implements CapBrowserPlugin {
    open(options: OpenOptions): Promise<any>;
    close(): Promise<any>;
    openWebView(options: OpenWebViewOptions): Promise<any>;
}
declare const CapBrowser: CapBrowserPlugin;
export * from './definitions';
export { CapBrowser };

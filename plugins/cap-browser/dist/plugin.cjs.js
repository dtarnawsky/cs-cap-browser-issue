'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@capacitor/core');

exports.ToolBarType = void 0;
(function (ToolBarType) {
    ToolBarType["ACTIVITY"] = "activity";
    ToolBarType["NAVIGATION"] = "navigation";
    ToolBarType["BLANK"] = "blank";
    ToolBarType["DEFAULT"] = "";
})(exports.ToolBarType || (exports.ToolBarType = {}));

const CapBrowser$1 = core.registerPlugin('CapBrowser', {
    web: () => Promise.resolve().then(function () { return web; }).then(m => new m.CapBrowserWeb()),
});

class CapBrowserWeb extends core.WebPlugin {
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
const CapBrowser = core.registerPlugin('CapBrowser', {
    web: () => Promise.resolve().then(function () { return web; }).then(m => new m.CapBrowserWeb())
});

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    CapBrowserWeb: CapBrowserWeb,
    CapBrowser: CapBrowser,
    get ToolBarType () { return exports.ToolBarType; }
});

exports.CapBrowser = CapBrowser$1;
//# sourceMappingURL=plugin.cjs.js.map

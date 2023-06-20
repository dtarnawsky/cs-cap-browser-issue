package com.cap.browser.plugin;

import android.webkit.WebView;

public class JavascriptInterface {
    private Options _options;
    private WebView _webView;

    public JavascriptInterface(WebView webView, Options options) {
        this._options = options;
        this._webView = webView;
    }

    @android.webkit.JavascriptInterface
    public void downloadObsPdf(String jsonString, String token) {
        _webView.post(() -> {
            String url = _webView.getUrl();
            _options.getCallbacks().downloadObsPdf(url, jsonString, token);
        });
    }
}

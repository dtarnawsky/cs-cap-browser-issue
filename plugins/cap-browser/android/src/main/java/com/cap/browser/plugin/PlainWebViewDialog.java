package com.cap.browser.plugin;

import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.text.TextUtils;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class PlainWebViewDialog extends Dialog implements CustomDialog{
    private Options _options;
    private WebView _webView;
    private boolean isInitialized;

    public PlainWebViewDialog(@NonNull Context context, int themeResId, Options options) {
        super(context, themeResId);
        _options = options;
    }

    public void presentWebView() {
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().getAttributes().windowAnimations = android.R.style.Animation_Dialog;
        setCancelable(true);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);

        this._webView = new WebView(_options.getActivity());
        this._webView.setLayoutParams(new LinearLayout.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT));
        this._webView.setId(Integer.valueOf(6));


        _webView.getSettings().setJavaScriptEnabled(true);
        _webView.getSettings().setJavaScriptCanOpenWindowsAutomatically(true);
        _webView.getSettings().setDatabaseEnabled(true);
        _webView.getSettings().setDomStorageEnabled(true);
        _webView.getSettings().setPluginState(android.webkit.WebSettings.PluginState.ON);

        Map<String, String> requestHeaders = new HashMap<>();
        if(_options.getHeaders() != null) {
            Iterator<String> keys = _options.getHeaders().keys();
            while(keys.hasNext()) {
                String key = keys.next();
                if(TextUtils.equals(key, "User-Agent")) {
                    _webView.getSettings().setUserAgentString(_options.getHeaders().getString(key));
                } else {
                    requestHeaders.put(key, _options.getHeaders().getString(key));
                }
            }
        }

        _webView.loadUrl(this._options.getUrl(), requestHeaders);

        _webView.setId(Integer.valueOf(6));
        _webView.getSettings().setLoadWithOverviewMode(true);
        _webView.requestFocus();
        _webView.requestFocusFromTouch();

        LinearLayout main = new LinearLayout(_options.getActivity());
        main.setOrientation(LinearLayout.VERTICAL);

        RelativeLayout webViewLayout = new RelativeLayout(_options.getActivity());
        webViewLayout.addView(_webView);

        main.addView(webViewLayout);

        WindowManager.LayoutParams lp = new WindowManager.LayoutParams();
        lp.copyFrom(getWindow().getAttributes());
        lp.width = WindowManager.LayoutParams.MATCH_PARENT;
        lp.height = WindowManager.LayoutParams.MATCH_PARENT;

        setContentView(main);


        setWebViewClient();

        getWindow().setAttributes(lp);

        if(!this._options.isPresentAfterPageLoad()) {
            show();
            _options.getPluginCall().success();
        }
    }

    private void setWebViewClient() {
        _webView.setWebViewClient(new WebViewClient() {

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                if (request.getUrl().toString().startsWith("tel:")) {
                    Intent intent = new Intent(Intent.ACTION_DIAL, request.getUrl());
                    _options.getActivity().startActivity(intent);
                    return true;
                }
                 else if(request.getUrl().toString() != null && request.getUrl().toString().toLowerCase().endsWith(".pdf")) {
                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    intent.setDataAndType(request.getUrl(), "application/pdf");
                    intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    _options.getActivity().startActivity(intent);
                    return true;
                }
                return false;
            }

            @Override
            public void onLoadResource(WebView view, String url) {
                super.onLoadResource(view, url);
            }

            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                try {
                    URI uri = new URI(url);
                    setTitle(uri.getHost());
                } catch (URISyntaxException e) {
                    // Do nothing
                }
                _options.getCallbacks().urlChangeEvent(url, "");
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                _options.getCallbacks().pageLoaded();
                if(!isInitialized) {
                    isInitialized = true;
                    _webView.clearHistory();
                    if(_options.isPresentAfterPageLoad()) {
                        show();
                        _options.getPluginCall().success();
                    }
                }
                view.clearFocus();
                view.requestFocus();
                _options.getCallbacks().pageLoaded();
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                super.onReceivedError(view, request, error);
                _options.getCallbacks().pageLoadError();
            }
        });
    }


    @Override
    public void onBackPressed() {
        if(_webView.canGoBack() && TextUtils.equals(_options.getToolbarType(), "navigation")) {
            _webView.goBack();
        } else {
            this.closeDialog();
            super.onBackPressed();
        }
    }

    @Override
    public void closeDialog() {
        if(_webView == null) {
            return;
        }
        _options.getCallbacks().closed();
        _webView.setWebViewClient(new WebViewClient() {
            // NB: wait for about:blank before dismissing
            public void onPageFinished(WebView view, String url) {
                isInitialized = true;
                dismiss();
            }
        });
        _webView.loadUrl("about:blank");
    }
}

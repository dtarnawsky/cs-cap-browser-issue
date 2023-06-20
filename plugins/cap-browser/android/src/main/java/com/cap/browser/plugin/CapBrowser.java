package com.cap.browser.plugin;

import android.content.ComponentName;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.Log;
import android.webkit.CookieManager;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.Iterator;

import androidx.browser.customtabs.CustomTabsCallback;
import androidx.browser.customtabs.CustomTabsClient;
import androidx.browser.customtabs.CustomTabsIntent;
import androidx.browser.customtabs.CustomTabsServiceConnection;
import androidx.browser.customtabs.CustomTabsSession;

import org.json.JSONException;

@CapacitorPlugin(name = "CapBrowser")
public class CapBrowser extends Plugin {
    public static final String CUSTOM_TAB_PACKAGE_NAME = "com.android.chrome";  // Change when in stable
    private CustomTabsClient customTabsClient;
    private CustomTabsSession currentSession;
    private CustomDialog dialog = null;

    CustomTabsServiceConnection connection = new CustomTabsServiceConnection() {
        @Override
        public void onCustomTabsServiceConnected(ComponentName name, CustomTabsClient client) {
            customTabsClient = client;
            client.warmup(0);
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
        }
    };

    @PluginMethod()
    public void open(PluginCall call) {
        String url = call.getString("url");
        if(url == null || TextUtils.isEmpty(url)) {
            call.error("Invalid URL");
        }
        CustomTabsIntent.Builder builder = new CustomTabsIntent.Builder(getCustomTabsSession());
        builder.addDefaultShareMenuItem();
        CustomTabsIntent tabsIntent = builder.build();
        tabsIntent.intent.putExtra(Intent.EXTRA_REFERRER,
                Uri.parse(Intent.URI_ANDROID_APP_SCHEME + "//" + getContext().getPackageName()));
        tabsIntent.intent.putExtra(android.provider.Browser.EXTRA_HEADERS, this.getHeaders(call));
        tabsIntent.launchUrl(getContext(), Uri.parse(url));

        call.success();
    }

    @PluginMethod()
    public void openWebView(PluginCall call) {
        String url = call.getString("url");
        if(url == null || TextUtils.isEmpty(url)) {
            call.error("Invalid URL");
        }
        final String toolbarType = call.getString("toolbarType", "");
        final Options options = new Options();
        options.setUrl(url);
        options.setHeaders(call.getObject("headers"));
        options.setTitle(call.getString("title", "New Window"));
        options.setShareDisclaimer(call.getObject("shareDisclaimer", null));
        options.setShareSubject(call.getString("shareSubject", null));
        options.setToolbarType(call.getString("toolbarType", ""));
        options.setPresentAfterPageLoad(call.getBoolean("isPresentAfterPageLoad", false));
        options.setPluginCall(call);
        options.setActivity(getActivity());
        options.setCallbacks(new WebViewCallbacks() {
            @Override
            public void urlChangeEvent(String url, String cookies) {
                JSObject urlchangeeventParams = new JSObject();
                urlchangeeventParams.put("url", url);
                urlchangeeventParams.put("cookies", cookies);
                notifyListeners("urlChangeEvent", urlchangeeventParams);
            }

            @Override
            public void downloadObsPdf(String url, String jsonString, String token) {
                CookieManager cookieManager = CookieManager.getInstance();
                String cookies = cookieManager.getCookie(url.replace("blob:", ""));
                if(cookies != null) {
                    cookies = cookies.replaceAll(" ", "");
                }
                    JSObject downloadObsPdfParams = new JSObject();
                try {
                    downloadObsPdfParams.put("body", new JSObject(jsonString));
                    downloadObsPdfParams.put("token", token);
                    downloadObsPdfParams.put("cookies", cookies);
                    notifyListeners("downloadObsPdf", downloadObsPdfParams);
                } catch (JSONException jsonException) {
                    Log.e("CapBrowser", "Error parsing jsonString: " + jsonException.getMessage(), jsonException);
                    notifyListeners("downloadObsPdf", downloadObsPdfParams);
                }

            }

            @Override
            public void pageLoaded() {
                notifyListeners("browserPageLoaded", new JSObject());
            }

            @Override
            public void pageLoadError() {
                notifyListeners("pageLoadError", new JSObject());
            }

            @Override
            public void doneBtnClicked() {
                notifyListeners("doneBtnClicked", new JSObject());
            }

            @Override
            public void closed() {
                notifyListeners("close", new JSObject());
            }
        });

        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if(TextUtils.equals(toolbarType, "blank")) {
                    PlainWebViewDialog plainWebViewDialog = new PlainWebViewDialog(getContext(), android.R.style.Theme_NoTitleBar, options);
                    plainWebViewDialog.presentWebView();
                    dialog = plainWebViewDialog;
                } else {
                    WebViewDialog webViewDialog = new WebViewDialog(getContext(), android.R.style.Theme_NoTitleBar, options);
                    webViewDialog.presentWebView();
                    dialog = webViewDialog;
                }
            }
        });
    }

    @PluginMethod()
    public void close(final PluginCall call) {
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (dialog != null) {
                    dialog.closeDialog();
                    dialog = null;
                } else {
                    Intent intent = new Intent(getContext(), getBridge().getActivity().getClass());
                    intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    getContext().startActivity(intent);
                }
                call.success();
            }
        });
    }

    private Bundle getHeaders(PluginCall pluginCall) {
        JSObject headersProvided = pluginCall.getObject("headers");
        Bundle headers = new Bundle();
        if(headersProvided != null) {
            Iterator<String> keys = headersProvided.keys();
            while(keys.hasNext()) {
                String key = keys.next();
                headers.putString(key, headersProvided.getString(key));
            }
        }
        return headers;
    }

    protected void handleOnResume() {
        boolean ok = CustomTabsClient.bindCustomTabsService(getContext(), CUSTOM_TAB_PACKAGE_NAME, connection);
        if (!ok) {
            Log.e(getLogTag(), "Error binding to custom tabs service");
        }
    }

    protected void handleOnPause() {
        getContext().unbindService(connection);
    }

    public CustomTabsSession getCustomTabsSession() {
        if (customTabsClient == null) {
            return null;
        }

        if (currentSession == null) {
            currentSession = customTabsClient.newSession(new CustomTabsCallback(){
                @Override
                public void onNavigationEvent(int navigationEvent, Bundle extras) {
                    switch (navigationEvent) {
                        case NAVIGATION_FINISHED:
                            notifyListeners("browserPageLoaded", new JSObject());
                            break;
                    }
                }
            });
        }
        return currentSession;
    }
}

package com.cap.browser.plugin;

public interface WebViewCallbacks {
    public void urlChangeEvent(String url, String cookies);
    public void downloadObsPdf(String url, String jsonString, String token);
    public void pageLoaded();
    public void pageLoadError();
    public void doneBtnClicked();
    public void closed();
}

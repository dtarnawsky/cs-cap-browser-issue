package com.cap.browser.plugin;

import android.Manifest;
import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Environment;
import android.os.Message;
import android.os.Parcelable;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ImageButton;
import android.widget.TextView;

import com.cap.browser.plugin.capbrowser.R;

import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.ActivityResultRegistry;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.widget.Toolbar;
import androidx.core.app.ActivityCompat;
import androidx.core.content.FileProvider;

public class WebViewDialog extends Dialog implements CustomDialog {
    private static final String ACTIVITY_RESULT_FILECHOOSER = "AR_fileChooser";
    private static final String ACTIVITY_RESULT_PERMISSION = "AR_permission";
    private static final int MAX_TITLE_LENGTH = 25;

    private final ActivityResultRegistry _registry;
    private ActivityResultLauncher<Intent> _fileChooserLauncher;
    private ActivityResultLauncher _permissionLauncher;
    private ValueCallback<Uri[]> filePathCallback;
    private WebChromeClient.FileChooserParams fileChooserParamsCallback;
    private boolean isCameraGranted = false;
    private String imageFilePath;
    private WebView _webView;
    private Toolbar _toolbar;
    private Options _options;
    private boolean isInitialized = false;
    private Set<String> url_schemes = new HashSet<String>(Arrays.asList(new String[]{"heqmobile"}));

    public WebViewDialog(Context context, int theme, Options options) {
        super(context, theme);
        this._options = options;
        this.isInitialized = false;
        this._registry = options.getActivity().getActivityResultRegistry();
    }

    public void presentWebView() {
//        _options.getActivity().setRequestedOrientation(ActivityInfo.);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setCancelable(true);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        setContentView(R.layout.activity_browser);
        getWindow().setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);

        this._webView = findViewById(R.id.browser_view);

        _webView.getSettings().setJavaScriptEnabled(true);
        _webView.addJavascriptInterface(new JavascriptInterface(_webView, _options), "BcbsmApp");
        _webView.getSettings().setJavaScriptCanOpenWindowsAutomatically(true);
        _webView.getSettings().setDatabaseEnabled(true);
        _webView.getSettings().setDomStorageEnabled(true);
        _webView.getSettings().setPluginState(android.webkit.WebSettings.PluginState.ON);
        _webView.getSettings().setLoadWithOverviewMode(true);
        _webView.getSettings().setUseWideViewPort(true);

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
        _webView.requestFocus();
        _webView.requestFocusFromTouch();

        setupToolbar();
        setWebViewClient();
        setWebChromeClient();

        _fileChooserLauncher = _registry.register(ACTIVITY_RESULT_FILECHOOSER,
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    List<Uri> uris = new ArrayList<>();

                    if (result.getResultCode() == Activity.RESULT_OK) {
                        Intent data = result.getData();

                        if (data != null && data.getClipData() != null) { // Multiple Items Selected
                            for (int i = 0; i < data.getClipData().getItemCount(); i++) {
                                uris.add(data.getClipData().getItemAt(i).getUri());
                            }
                        } else if (data != null && data.getData() != null) { // Single Item Selected
                            uris.add(data.getData());
                        } else if (imageFilePath != null) { // Camera Image
                            uris.add(Uri.parse(imageFilePath));
                        }
                    }

                    filePathCallback.onReceiveValue(uris.toArray(new Uri[0]));
                    filePathCallback = null;
                });

        _permissionLauncher = _registry.register(ACTIVITY_RESULT_PERMISSION,
                new ActivityResultContracts.RequestMultiplePermissions(),
                permissions -> {
                    if (permissions != null && permissions.containsKey(Manifest.permission.CAMERA)) {
                        isCameraGranted = permissions.get(Manifest.permission.CAMERA).booleanValue();
                    }

                    launchFileChooser();
                });

        if(!this._options.isPresentAfterPageLoad()) {
            show();
            _options.getPluginCall().success();
        }
    }

    private void setTitle(String newTitleText) {
        TextView textView = (TextView) _toolbar.findViewById(R.id.titleText);
        if(!TextUtils.isEmpty(newTitleText)) {
            newTitleText = (newTitleText.length() > MAX_TITLE_LENGTH) ? newTitleText.substring (0 , MAX_TITLE_LENGTH).concat ("...") : newTitleText;
            textView.setText(newTitleText);
        }
    }

    private void setupToolbar() {
        _toolbar = this.findViewById(R.id.tool_bar);
        if(!TextUtils.isEmpty(_options.getTitle())) {
            this.setTitle(_options.getTitle());
        } else {
            try {
                URI uri = new URI(_options.getUrl());
                this.setTitle(uri.getHost());
            } catch (URISyntaxException e) {
                this.setTitle(_options.getTitle());
            }
        }

        View backButton = _toolbar.findViewById(R.id.backButton);
        backButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if(_webView.canGoBack()) {
                    _webView.goBack();
                }
            }
        });

        View forwardButton = _toolbar.findViewById(R.id.forwardButton);
        forwardButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if(_webView.canGoForward()) {
                    _webView.goForward();
                }
            }
        });

        View closeButton = _toolbar.findViewById(R.id.closeButton);
        closeButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                _options.getCallbacks().doneBtnClicked();
                dismiss();
            }
        });

        if(TextUtils.equals(_options.getToolbarType(), "activity")) {
            _toolbar.findViewById(R.id.forwardButton).setVisibility(View.GONE);
            _toolbar.findViewById(R.id.backButton).setVisibility(View.GONE);
            //TODO: Add share button functionality
        } else if(TextUtils.equals(_options.getToolbarType(), "navigation")) {
            //TODO: Remove share button when implemented
        } else if(TextUtils.equals(_options.getToolbarType(), "blank")){
            _toolbar.setVisibility(View.GONE);
        } else {
            _toolbar.findViewById(R.id.forwardButton).setVisibility(View.GONE);
            _toolbar.findViewById(R.id.backButton).setVisibility(View.GONE);
        }
    }

    private void updateButtons() {
        ImageButton backButton = _toolbar.findViewById(R.id.backButton);
        if(_webView.canGoBack()) {
            backButton.setImageResource(R.drawable.arrow_back_enabled);
            backButton.setEnabled(true);
        } else {
            backButton.setImageResource(R.drawable.arrow_back_disabled);
            backButton.setEnabled(false);
        }

        ImageButton forwardButton = _toolbar.findViewById(R.id.forwardButton);
        if(_webView.canGoForward()) {
            forwardButton.setImageResource(R.drawable.arrow_forward_enabled);
            forwardButton.setEnabled(true);
        } else {
            forwardButton.setImageResource(R.drawable.arrow_forward_disabled);
            forwardButton.setEnabled(false);
        }
    }

    private void launchFileChooser() {
        ArrayList<Parcelable> extraIntents = new ArrayList<>();

        if (isCameraGranted) {
            extraIntents.add(getImageCaptureIntent());
        }

        Intent getContentIntent = getGetContentIntent();
        Intent chooserIntent = new Intent(Intent.ACTION_CHOOSER);
        chooserIntent.putExtra(Intent.EXTRA_INTENT, getContentIntent);
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, extraIntents.toArray(new Parcelable[]{}));

        _fileChooserLauncher.launch(chooserIntent);
    }

    private Intent getGetContentIntent() {
        Intent getContentIntent = new Intent(Intent.ACTION_GET_CONTENT);
        getContentIntent.addCategory(Intent.CATEGORY_OPENABLE);
        getContentIntent.setType("*/*");

        if (fileChooserParamsCallback != null && fileChooserParamsCallback.getMode() == WebChromeClient.FileChooserParams.MODE_OPEN_MULTIPLE) {
            getContentIntent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        }

        if (fileChooserParamsCallback != null && fileChooserParamsCallback.getAcceptTypes().length > 0) {
            getContentIntent.putExtra(Intent.EXTRA_MIME_TYPES, fileChooserParamsCallback.getAcceptTypes());
        }

        return getContentIntent;
    }

    private Intent getImageCaptureIntent() {
        File imageFile;

        try {
            imageFile = createImageFile();
        } catch (IOException e) {
            return null;
        }

        imageFilePath = "file:" + imageFile.getAbsolutePath();
        Intent imageCaptureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
        Uri uriImageFile = FileProvider.getUriForFile(_options.getActivity(), getContext().getPackageName() + ".fileprovider", imageFile);
        imageCaptureIntent.putExtra(MediaStore.EXTRA_OUTPUT, uriImageFile);

        return imageCaptureIntent;
    }

    private File createImageFile() throws IOException {
        // Create an image file name
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
        String imageFileName = "JPEG_" + timeStamp + ".jpg";
        File storageDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES);
        File imageFile = new File(
                storageDir,      /* directory */
                imageFileName  /* filename */
        );
        return imageFile;
    }

    /* This method has been introduced to detect window.open(_blank)
       from inside the Android WebView, only for PrintView in ACI portal. */
    private void setWebChromeClient() {
        _webView.setWebChromeClient(new WebChromeClient() {

            @Override
            public boolean onCreateWindow(WebView view, boolean isDialog, boolean isUserGesture, Message resultMsg) {
                WebView childView = new WebView(view.getContext());
                final WebSettings settings = childView.getSettings();
                settings.setSupportMultipleWindows(true);
                WebView.WebViewTransport transport = (WebView.WebViewTransport) resultMsg.obj;
                childView.setWebChromeClient(this);
                transport.setWebView(childView);
                resultMsg.sendToTarget();
                webViewPagePrint();
                return true;
            }

            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> filePath, FileChooserParams fileChooserParams) {

                if (filePathCallback != null) {
                    filePathCallback.onReceiveValue(null);
                }
                filePathCallback = filePath;
                fileChooserParamsCallback = fileChooserParams;

                if (ActivityCompat.checkSelfPermission(_options.getActivity().getApplicationContext(), Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                    if (!ActivityCompat.shouldShowRequestPermissionRationale(_options.getActivity(), Manifest.permission.CAMERA)) {
                        //ActivityCompat.requestPermissions(_options.getActivity(), new String[]{Manifest.permission.CAMERA}, 1);
                        _permissionLauncher.launch(new String[] {Manifest.permission.CAMERA});
                        return true;
                    }
                } else {
                    isCameraGranted = true;
                }

                launchFileChooser();
                return true;
            }



            /* The below method will trigger the Pop-Up Print Preview from inside the Android WebView. */
            private void webViewPagePrint() {
                PrintManager printManager = (PrintManager) _webView.getContext().getSystemService(Context.PRINT_SERVICE);
                String jobName = _webView.getContext().getString(R.string.app_name);
                PrintDocumentAdapter printAdapter = _webView.createPrintDocumentAdapter("Pay My Bill Receipt");
                printManager.print(jobName, printAdapter,
                        null);
            }
        });
    }

    private void setWebViewClient() {
        _webView.setWebViewClient(new WebViewClient() {

            @Override
            public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) { 
                CookieManager cookieManager = CookieManager.getInstance();
                String cookies = cookieManager.getCookie(url.replace("blob:", ""));
                if(cookies != null) {
                    cookies = cookies.replaceAll(" ", "");
                }
                _options.getCallbacks().urlChangeEvent(url, cookies);
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                /**
                 *  Post requests might not trigger url change events with respect to this shouldOverrideUrlLoading method.
                 * */
                if (
                        request.getUrl().toString().startsWith("tel:") ||
                                request.getUrl().toString().startsWith("mailto:") ||
                                request.getUrl().toString().startsWith("sms:")
                ) {
                    Intent intent = new Intent(Intent.ACTION_VIEW, request.getUrl());
                    _options.getActivity().startActivity(intent);
                    return true;
                }
                else if(url_schemes.contains(request.getUrl().getScheme())) {
                    Intent intent = new Intent(Intent.ACTION_VIEW, request.getUrl());
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                    _options.getActivity().startActivity(intent);
                    closeDialog();
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
                updateButtons();
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
                // _options.getCallbacks().urlChangeEvent(url);
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

                /* The below condition is explicit to handle Print functionality in responsive. */
                WebSettings settings = view.getSettings();
                settings.setSupportMultipleWindows(false);
                if(url.contains("/billpayhistory") || url.contains("/confirmation") || url.contains("/Reimbursements")) {
                    settings.setSupportMultipleWindows(true);
                }

                updateButtons();
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
                _options.getCallbacks().closed();
                dismiss();
            }
        });
        _webView.loadUrl("about:blank");
    }
}
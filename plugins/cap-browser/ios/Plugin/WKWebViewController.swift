//
//  WKWebViewController.swift
//  Sample
//
//  Created by Meniny on 2018-01-20.
//  Copyright © 2018年 Meniny. All rights reserved.
//

import UIKit
import WebKit

fileprivate let estimatedProgressKeyPath = "estimatedProgress"
fileprivate let titleKeyPath = "title"
fileprivate let cookieKey = "Cookie"
fileprivate let windowprint = "print"
fileprivate let downloadObsPdf = "downloadObsPdf"

fileprivate struct UrlsHandledByApp {
    public static var hosts = ["itunes.apple.com"]
    public static var schemes = ["tel", "mailto", "sms"]
    public static var external_app_schemes = ["heqmobile"]
    public static var blank = true
}

@objc public protocol WKWebViewControllerDelegate {
    @objc optional func webViewController(_ controller: WKWebViewController, canDismiss url: URL) -> Bool
    
    @objc optional func webViewController(_ controller: WKWebViewController, didStart url: URL)
    @objc optional func webViewController(_ controller: WKWebViewController, didFinish url: URL)
    @objc optional func webViewController(_ controller: WKWebViewController, didFail url: URL, withError error: Error)
    @objc optional func webViewController(_ controller: WKWebViewController, decidePolicy url: URL, navigationType: NavigationType) -> Bool
}

open class WKWebViewController: UIViewController, WKScriptMessageHandler {
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public init(source: WKWebSource?) {
        super.init(nibName: nil, bundle: nil)
        self.source = source
        self.initWebview()
    }
    
    public init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        self.source = .remote(url)
        self.initWebview()
    }
    
    public init(url: URL, headers: [String: String]) {
        super.init(nibName: nil, bundle: nil)
        
        if url.absoluteString.hasPrefix("file") {
            self.source = .file(url, access: url)
        } else {
            self.source = .remote(url)
        }
        
        self.setHeaders(headers: headers)
        self.initWebview()
    }
    
    open var hasDynamicTitle = false
    open var source: WKWebSource?
    /// use `source` instead
    open internal(set) var url: URL?
    open var tintColor: UIColor?
    open var allowsFileURL = true
    open var delegate: WKWebViewControllerDelegate?
    open var bypassedSSLHosts: [String]?
    open var cookies: [HTTPCookie]?
    open var headers: [String: String]?
    open var capBrowserPlugin: CapBrowser?
    var shareDisclaimer: [String: Any]?
    var shareSubject: String?
    var activityViewController: UIActivityViewController?
    var didpageInit = false
    var viewHeightLandscape: CGFloat?
    var viewHeightPortrait: CGFloat?
    var currentViewHeight: CGFloat?
    var toolbarType: String?
    
    func setHeaders(headers: [String: String]) {
        self.headers = headers
        let userAgent = self.headers?["User-Agent"]
        self.headers?.removeValue(forKey: "User-Agent")
        if userAgent != nil {
            self.customUserAgent = userAgent
        }
    }
    
    internal var customUserAgent: String? {
        didSet {
            guard let agent = userAgent else {
                return
            }
            webView?.customUserAgent = agent
        }
    }
    
    open var userAgent: String? {
        didSet {
            guard let originalUserAgent = originalUserAgent, let userAgent = userAgent else {
                return
            }
            webView?.customUserAgent = [originalUserAgent, userAgent].joined(separator: " ")
        }
    }
    
    open var pureUserAgent: String? {
        didSet {
            guard let agent = pureUserAgent else {
                return
            }
            webView?.customUserAgent = agent
        }
    }
    
    open var websiteTitleInNavigationBar = true
    open var doneBarButtonItemPosition: NavigationBarPosition = .right
    open var leftNavigaionBarItemTypes: [BarButtonItemType] = []
    open var rightNavigaionBarItemTypes: [BarButtonItemType] = []
    open var toolbarItemTypes: [BarButtonItemType] = [.back, .forward, .reload, .activity]
    
    open var backBarButtonItemImage: UIImage?
    open var forwardBarButtonItemImage: UIImage?
    open var reloadBarButtonItemImage: UIImage?
    open var stopBarButtonItemImage: UIImage?
    open var activityBarButtonItemImage: UIImage?

    fileprivate var webView: WKWebView?
    fileprivate var progressView: UIProgressView?
    
    fileprivate var previousNavigationBarState: (tintColor: UIColor, hidden: Bool) = (.black, false)
    fileprivate var previousToolbarState: (tintColor: UIColor, hidden: Bool) = (.black, false)
    
    fileprivate var originalUserAgent: String?
    
    lazy fileprivate var backBarButtonItem: UIBarButtonItem = {
        let bundle = Bundle(for: WKWebViewController.self)
        return UIBarButtonItem(image: backBarButtonItemImage ?? UIImage(named: "Back", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(backDidClick(sender:)))
    }()
    
    lazy fileprivate var forwardBarButtonItem: UIBarButtonItem = {
        let bundle = Bundle(for: WKWebViewController.self)
        return UIBarButtonItem(image: forwardBarButtonItemImage ?? UIImage(named: "Forward", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(forwardDidClick(sender:)))
    }()
    
    lazy fileprivate var reloadBarButtonItem: UIBarButtonItem = {
        if let image = reloadBarButtonItemImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(reloadDidClick(sender:)))
        } else {
            return UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadDidClick(sender:)))
        }
    }()
    
    lazy fileprivate var stopBarButtonItem: UIBarButtonItem = {
        if let image = stopBarButtonItemImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(stopDidClick(sender:)))
        } else {
            return UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(stopDidClick(sender:)))
        }
    }()
    
    lazy fileprivate var activityBarButtonItem: UIBarButtonItem = {
        if let image = activityBarButtonItemImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(activityDidClick(sender:)))
        } else {
            return UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(activityDidClick(sender:)))
        }
    }()
    
    lazy fileprivate var doneBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneDidClick(sender:)))
    }()
    
    lazy fileprivate var flexibleSpaceBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }()
    
    deinit {
        webView?.removeObserver(self, forKeyPath: estimatedProgressKeyPath)
        if websiteTitleInNavigationBar {
            webView?.removeObserver(self, forKeyPath: titleKeyPath)
        }
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
    }
    
    override open func viewDidLoad(){
        super.viewDidLoad()
        if self.webView == nil {
            self.initWebview()
        }
    }
    
    open func initWebview() {
        
        self.view.backgroundColor = UIColor.white
        
        let webConfiguration = WKWebViewConfiguration()
        let script = WKUserScript(source: "window.print = function() { window.webkit.messageHandlers.print.postMessage('print') }", injectionTime: WKUserScriptInjectionTime.atDocumentEnd, forMainFrameOnly: true)
        webConfiguration.userContentController.addUserScript(script)
        webConfiguration.userContentController.add(self, name: windowprint)
        webConfiguration.userContentController.add(self, name: downloadObsPdf)
        webConfiguration.allowsAirPlayForMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = .all
        let webView = WKWebView(frame: self.view.bounds, configuration: webConfiguration)
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isMultipleTouchEnabled = true
        
        webView.addObserver(self, forKeyPath: estimatedProgressKeyPath, options: .new, context: nil)
        if websiteTitleInNavigationBar {
            webView.addObserver(self, forKeyPath: titleKeyPath, options: .new, context: nil)
        }
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url) , options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward) , options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack) , options: .new, context: nil)
        
        self.view = webView
        self.webView = webView
        
        /* Adding touch event to detect form open - used to remove form submits with _blank */
        self.webView?.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action:#selector(self.removeTargetBlanks))
        gesture.delegate = self
        self.webView?.addGestureRecognizer(gesture)
        
        self.webView?.customUserAgent = self.customUserAgent ?? self.userAgent ?? self.originalUserAgent
        
        self.navigationItem.title = self.navigationItem.title ?? self.source?.absoluteString
        
        if let navigation = self.navigationController {
            self.previousNavigationBarState = (navigation.navigationBar.tintColor, navigation.navigationBar.isHidden)
            self.previousToolbarState = (navigation.toolbar.tintColor, navigation.toolbar.isHidden)
        }
        
        if let s = self.source {
            self.load(source: s)
        } else {
            print("[\(type(of: self))][Error] Invalid url")
        }
    }
    
    @objc func removeTargetBlanks() {
        self.webView?.evaluateJavaScript("Array.from(document.querySelectorAll('input[formtarget=\"_blank\"]')).forEach(link => link.removeAttribute('formtarget'));") { (result, error) in
            if error != nil {
                print("Failed deleting form target blanks")
            }
        }
    }
    
    open func setupViewElements() {
        self.setUpProgressView()
        self.setUpConstraints()
        self.addBarButtonItems()
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {}
    
    open override func viewWillLayoutSubviews() {}
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupViewElements()
        setUpState()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rollbackState()
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case estimatedProgressKeyPath?:
            guard let estimatedProgress = self.webView?.estimatedProgress else {
                return
            }
            self.progressView?.alpha = 1
            self.progressView?.setProgress(Float(estimatedProgress), animated: true)
            
            if estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView?.alpha = 0
                }, completion: {
                    finished in
                    self.progressView?.setProgress(0, animated: false)
                })
            }
        case titleKeyPath?:
            if self.hasDynamicTitle {
                self.navigationItem.title = webView?.url?.host
            }
        case "URL":
           var cookieData="";
            let dataStore = WKWebsiteDataStore.default()
            dataStore.httpCookieStore.getAllCookies({ (cookies) in
                for cookie in cookies {
                    cookieData += cookie.name + "=" + cookie.value + ";";
                }
                self.capBrowserPlugin?.notifyListeners("urlChangeEvent", data: ["url" : self.webView?.url?.absoluteString, "cookies": cookieData])
            })
            let disableBackButton = webView?.url?.absoluteString
            if(disableBackButton?.range(of: "/acisuccess" , options: .caseInsensitive) != nil || disableBackButton?.range(of: "/acifailure", options: .caseInsensitive) != nil || disableBackButton?.range(of: "/acitimeout", options: .caseInsensitive) != nil) {
                backBarButtonItem.isEnabled = false
                forwardBarButtonItem.isEnabled = false
            }
                else {
                backBarButtonItem.isEnabled = webView?.canGoBack ?? false
                forwardBarButtonItem.isEnabled = webView?.canGoForward ?? false
            }
        case "canGoBack":
            updateBarButtonItems()
        case "canGoForward":
            updateBarButtonItems()
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// MARK: - Public Methods
public extension WKWebViewController {
    
    func load(source s: WKWebSource) {
        switch s {
        case .remote(let url):
            self.load(remote: url)
        case .file(let url, access: let access):
            self.load(file: url, access: access)
        case .string(let str, base: let base):
            self.load(string: str, base: base)
        }
    }
    
    func load(remote: URL) {
        webView?.load(createRequest(url: remote))
    }
    
    func load(file: URL, access: URL) {
        webView?.loadFileURL(file, allowingReadAccessTo: access)
    }
    
    func load(string: String, base: URL? = nil) {
        webView?.loadHTMLString(string, baseURL: base)
    }
    
    func goBackToFirstPage() {
        if let firstPageItem = webView?.backForwardList.backList.first {
            webView?.go(to: firstPageItem)
        }
    }
}

// MARK: - Fileprivate Methods
fileprivate extension WKWebViewController {
    var availableCookies: [HTTPCookie]? {
        return cookies?.filter {
            cookie in
            var result = true
            let url = self.source?.remoteURL
            if let host = url?.host, !cookie.domain.hasSuffix(host) {
                result = false
            }
            if cookie.isSecure && url?.scheme != "https" {
                result = false
            }
            
            return result
        }
    }
    func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // Set up headers
        if let headers = headers {
            for (field, value) in headers {
                request.addValue(value, forHTTPHeaderField: field)
            }
        }
        
        // Set up Cookies
        if let cookies = availableCookies, let value = HTTPCookie.requestHeaderFields(with: cookies)[cookieKey] {
            request.addValue(value, forHTTPHeaderField: cookieKey)
        }
        
        return request
    }
    
    func setUpProgressView() {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.trackTintColor = UIColor(white: 1, alpha: 0)
        self.progressView = progressView
        //        updateProgressViewFrame()
    }
    
    func setUpConstraints() {
        if !(self.navigationController?.navigationBar.isHidden)! {
            self.progressView?.frame.origin.y = CGFloat((self.navigationController?.navigationBar.frame.height)!)
            self.navigationController?.navigationBar.addSubview(self.progressView!)
            webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        }
    }
    
    func addBarButtonItems() {
        func barButtonItem(_ type: BarButtonItemType) -> UIBarButtonItem? {
            switch type {
            case .back:
                return backBarButtonItem
            case .forward:
                return forwardBarButtonItem
            case .reload:
                return reloadBarButtonItem
            case .stop:
                return stopBarButtonItem
            case .activity:
                return activityBarButtonItem
            case .done:
                return doneBarButtonItem
            case .flexibleSpace:
                return flexibleSpaceBarButtonItem
            case .fixedSpace:
                let fixedSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.fixedSpace, target: nil, action: nil)
                fixedSpace.width = 40.0
                return fixedSpace
            case .custom(let icon, let title, let action):
                let item: BlockBarButtonItem
                if let icon = icon {
                    item = BlockBarButtonItem(image: icon, style: .plain, target: self, action: #selector(customDidClick(sender:)))
                } else {
                    item = BlockBarButtonItem(title: title, style: .plain, target: self, action: #selector(customDidClick(sender:)))
                }
                item.block = action
                return item
            }
        }
        
//        if presentingViewController != nil {
            switch doneBarButtonItemPosition {
            case .left:
                if !leftNavigaionBarItemTypes.contains(where: { type in
                    switch type {
                    case .done:
                        return true
                    default:
                        return false
                    }
                }) {
                    leftNavigaionBarItemTypes.insert(.done, at: 0)
                }
            case .right:
                if !rightNavigaionBarItemTypes.contains(where: { type in
                    switch type {
                    case .done:
                        return true
                    default:
                        return false
                    }
                }) {
                    rightNavigaionBarItemTypes.insert(.done, at: 0)
                }
            case .none:
                break
            }
//        }
        
        navigationItem.leftBarButtonItems = leftNavigaionBarItemTypes.map {
            barButtonItemType in
            if let barButtonItem = barButtonItem(barButtonItemType) {
                return barButtonItem
            }
            return UIBarButtonItem()
        }
        
        navigationItem.rightBarButtonItems = rightNavigaionBarItemTypes.map {
            barButtonItemType in
            if let barButtonItem = barButtonItem(barButtonItemType) {
                return barButtonItem
            }
            return UIBarButtonItem()
        }
        
        if toolbarItemTypes.count > 0 {
            if toolbarType != "navigation" {
                for index in 0..<toolbarItemTypes.count - 1 {
                    toolbarItemTypes.insert(.flexibleSpace, at: 2 * index + 1)
                }
            }
        }
        
        setToolbarItems(toolbarItemTypes.map {
            barButtonItemType -> UIBarButtonItem in
            if let barButtonItem = barButtonItem(barButtonItemType) {
                return barButtonItem
            }
            return UIBarButtonItem()
        }, animated: true)
    }
    
    func updateBarButtonItems() {
         let disableBackButton = webView?.url?.absoluteString
                 if(disableBackButton?.range(of: "/acisuccess" , options: .caseInsensitive) != nil || disableBackButton?.range(of: "/acifailure", options: .caseInsensitive) != nil || disableBackButton?.range(of: "/acitimeout", options: .caseInsensitive) != nil) {
                    backBarButtonItem.isEnabled = false
                    forwardBarButtonItem.isEnabled = false
                }
                    else {
                    backBarButtonItem.isEnabled = webView?.canGoBack ?? false
                    forwardBarButtonItem.isEnabled = webView?.canGoForward ?? false
                }
        
        let updateReloadBarButtonItem: (UIBarButtonItem, Bool) -> UIBarButtonItem = {
            [unowned self] barButtonItem, isLoading in
            switch barButtonItem {
            case self.reloadBarButtonItem:
                fallthrough
            case self.stopBarButtonItem:
                return isLoading ? self.stopBarButtonItem : self.reloadBarButtonItem
            default:
                break
            }
            return barButtonItem
        }
        
        let isLoading = webView?.isLoading ?? false
        toolbarItems = toolbarItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
        
        navigationItem.leftBarButtonItems = navigationItem.leftBarButtonItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
        
        navigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
    }
    
    func setUpState() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.setToolbarHidden(toolbarItemTypes.count == 0, animated: true)
    }
    
    func rollbackState() {
        progressView?.progress = 0
        
        navigationController?.setToolbarHidden(previousToolbarState.hidden, animated: true)
        navigationController?.setNavigationBarHidden(previousNavigationBarState.hidden, animated: true)
    }
    
    func checkRequestCookies(_ request: URLRequest, cookies: [HTTPCookie]) -> Bool {
        if cookies.count <= 0 {
            return true
        }
        guard let headerFields = request.allHTTPHeaderFields, let cookieString = headerFields[cookieKey] else {
            return false
        }
        
        let requestCookies = cookieString.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=", maxSplits: 1).map(String.init)
        }
        
        var valid = false
        for cookie in cookies {
            valid = requestCookies.filter {
                $0[0] == cookie.name && $0[1] == cookie.value
                }.count > 0
            if !valid {
                break
            }
        }
        return valid
    }
    
    func openURLWithApp(_ url: URL) -> Bool {
        let application = UIApplication.shared
        if application.canOpenURL(url) {
            return application.openURL(url)
        }
        
        return false
    }
    
    func handleURLWithApp(_ url: URL, targetFrame: WKFrameInfo?) -> Bool {
        let hosts = UrlsHandledByApp.hosts
        let schemes = UrlsHandledByApp.schemes
        let appSchemes = UrlsHandledByApp.external_app_schemes
        let blank = UrlsHandledByApp.blank
        
        var tryToOpenURLWithApp = false
        if let host = url.host, hosts.contains(host) {
            tryToOpenURLWithApp = true
        }
        if let scheme = url.scheme, schemes.contains(scheme) || appSchemes.contains(scheme) {
            tryToOpenURLWithApp = true
        }
        if blank && targetFrame == nil {
            tryToOpenURLWithApp = true
        }
        
        if tryToOpenURLWithApp {
            if let scheme = url.scheme, !schemes.contains(scheme) {
                dismiss(animated: true, completion: nil)
            }
            return openURLWithApp(url)
        }
        
        return false
    }
    
    @objc func backDidClick(sender: AnyObject) {
        webView?.goBack()
    }
    
    @objc func forwardDidClick(sender: AnyObject) {
        webView?.goForward()
    }
    
    @objc func reloadDidClick(sender: AnyObject) {
        webView?.stopLoading()
        if webView?.url != nil {
            webView?.reload()
        } else if let s = self.source {
            self.load(source: s)
        }
    }
    
    @objc func stopDidClick(sender: AnyObject) {
        webView?.stopLoading()
    }
    
    @objc func activityDidClick(sender: AnyObject) {
        guard var s = self.source else {
            return
        }
        let myGroup = DispatchGroup()
        let url = self.webView?.url
        
        /* The below code is only for PDFs inside a remote weburl*/
        if url?.absoluteString.hasSuffix(".pdf") == true, url?.absoluteString.hasPrefix("https") == true {
            
            /* This prevents the shareSheet from being shown up ahead of downloading the pdf from remote webUrl */
                myGroup.enter()
            
            /* Downloading PDF from remote webUrl */
               let task = URLSession.shared.dataTask(with: url!) { data, response, error in
                guard let data = data, error == nil else {
                    return
                }
                guard let httpURLResponse = response as? HTTPURLResponse
                          else {
                            return
                          }
                
                /* Saving the downloaded PDF to local storage */
                do {
                    let fileName = httpURLResponse.suggestedFilename,
                    url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName!)
                    try data.write(to: url, options: .atomic)
                    s = WKWebSource.file(url, access: url)
                    /* This will let the shareSheet code execution to go through once the PDF is downloaded to local. */
                    myGroup.leave()
                } catch {
                    print(error)
                    return
                }
                }
                task.resume()
            }
        
        /* notify() will wait until enter() and leave() are balanced out before further execution.
         Will let the execution go if neither of those methods are triggered. */
        myGroup.notify(queue: DispatchQueue.main) {
            let items: [Any]
            switch s {
            case .remote(let u):
                items = [u]
            case .file(let u, access: _):
                items = [u]
            case .string(let str, base: _):
                items = [str]
            }
            self.showDisclaimer(items: items, sender: sender)
        }
    }
    
    func showDisclaimer(items: [Any], sender: AnyObject) {
        let showDisclaimer: Bool = self.shareDisclaimer != nil
        if(showDisclaimer) {
            let alert = UIAlertController(
                title: self.shareDisclaimer?["title"] as? String ?? "Title",
                message: self.shareDisclaimer?["message"] as? String ?? "Message",
                preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: self.shareDisclaimer?["confirmBtn"] as? String ?? "Confirm", style: UIAlertAction.Style.default, handler: { action in
                self.shareDisclaimer = nil
                self.capBrowserPlugin?.notifyListeners("confirmBtnClicked", data: nil)
                self.activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
                self.activityViewController?.setValue(self.shareSubject ?? self.title, forKey: "subject")
                self.activityViewController?.popoverPresentationController?.barButtonItem = (sender as! UIBarButtonItem)
                self.activityViewController?.completionWithItemsHandler = {(activityType: UIActivity.ActivityType?, completed: Bool, returnedItems: [Any]?, error: Error?) in
                    self.activityViewController?.setValue(self.shareSubject ?? self.title, forKey: "subject")
                    if !completed {
                        self.capBrowserPlugin?.notifyListeners("shareResult", data: ["isSuccess": false])
                        self.activityViewController?.setValue(self.shareSubject ?? self.title, forKey: "subject")
                        return
                    }
                    self.capBrowserPlugin?.notifyListeners("shareResult", data: ["isSuccess": true])
                }
                self.present(self.activityViewController!, animated: true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: self.shareDisclaimer?["cancelBtn"] as? String ?? "Cancel", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            self.activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            self.activityViewController?.setValue(self.shareSubject ?? self.title, forKey: "subject")
            self.activityViewController?.popoverPresentationController?.barButtonItem = (sender as! UIBarButtonItem)
            self.activityViewController?.completionWithItemsHandler = {(activityType: UIActivity.ActivityType?, completed: Bool, returnedItems: [Any]?, error: Error?) in
                self.activityViewController?.setValue(self.shareSubject ?? self.title, forKey: "subject")
                if !completed {
                    self.capBrowserPlugin?.notifyListeners("shareResult", data: ["isSuccess": false])
                    self.activityViewController?.setValue(self.shareSubject ?? self.title, forKey: "subject")
                    return
                }
                self.capBrowserPlugin?.notifyListeners("shareResult", data: ["isSuccess": true])
            }
            self.present(self.activityViewController!, animated: true, completion: nil)
        }
    }
    
    @objc func doneDidClick(sender: AnyObject) {
        var canDismiss = true
        if let url = self.source?.url {
            canDismiss = delegate?.webViewController?(self, canDismiss: url) ?? true
        }
        if canDismiss {
//            UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
            self.capBrowserPlugin?.notifyListeners("doneBtnClicked", data: nil)
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func customDidClick(sender: BlockBarButtonItem) {
        sender.block?(self)
    }
    
    func canRotate() -> Void {}
}

// MARK: - UIGestureRecognizerDelegate
extension WKWebViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        if gestureRecognizer.isKind(of: UITapGestureRecognizer.self) {
            self.removeTargetBlanks()
        }
        return true
    }
}

// MARK: - WKUIDelegate
extension WKWebViewController: WKUIDelegate {
}

// MARK: - WKNavigationDelegate
extension WKWebViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let u = webView.url {
            self.url = u
            delegate?.webViewController?(self, didStart: u)
        }
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !didpageInit && self.capBrowserPlugin?.isPresentAfterPageLoad == true {
            self.capBrowserPlugin?.presentView()
        }
        
        if !didpageInit && self.capBrowserPlugin?.clearHistoryOnLoad == true {
            webView.backForwardList.perform(Selector(("_removeAllItems")))
        }
        
        didpageInit = true
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let url = webView.url {
            self.url = url
            delegate?.webViewController?(self, didFinish: url)
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let url = webView.url {
            self.url = url
            delegate?.webViewController?(self, didFail: url, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let url = webView.url {
            self.url = url
            delegate?.webViewController?(self, didFail: url, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let bypassedSSLHosts = bypassedSSLHosts, bypassedSSLHosts.contains(challenge.protectionSpace.host) {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == windowprint) {
            let webviewPrint = webView?.viewPrintFormatter()
            let printController = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo(dictionary:nil)
            printInfo.orientation = UIPrintInfo.Orientation.portrait
            printController.printFormatter = webviewPrint
            printController.printInfo = printInfo
            printController.showsNumberOfCopies = true
            printController.present(animated: true, completionHandler: nil)
        }
        
        if (message.name == downloadObsPdf) {
            guard let dict = message.body as? [String: AnyObject],
                  let token = dict["token"] as? String,
                  let data = dict["body"] as? [String: AnyObject]
            else { return }

            var cookieData="";
            let dataStore = WKWebsiteDataStore.default()
            dataStore.httpCookieStore.getAllCookies({ (cookies) in
                for cookie in cookies {
                    cookieData += cookie.name + "=" + cookie.value + ";";
                }
                self.capBrowserPlugin?.notifyListeners("downloadObsPdf", data: ["body": data, "token": token, "cookies": cookieData])
            })
        }
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // This mwthod triggers the window.open from webview
            webView.load(navigationAction.request)
            return nil
      }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var actionPolicy: WKNavigationActionPolicy = .allow
        defer {
            decisionHandler(actionPolicy)
        }
        
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            actionPolicy = .cancel
            return
        }
        
        guard let u = navigationAction.request.url else {
            print("Cannot handle empty URLs")
            return
        }
        
        if !self.allowsFileURL && u.isFileURL {
            print("Cannot handle file URLs")
            return
        }
        
        if handleURLWithApp(u, targetFrame: navigationAction.targetFrame) {
            actionPolicy = .cancel
            return
        }
        
        if u.host == self.source?.url?.host, let cookies = availableCookies, !checkRequestCookies(navigationAction.request, cookies: cookies) {
            self.load(remote: u)
            actionPolicy = .cancel
            return
        }
        
        if let navigationType = NavigationType(rawValue: navigationAction.navigationType.rawValue), let result = delegate?.webViewController?(self, decidePolicy: u, navigationType: navigationType) {
            actionPolicy = result ? .allow : .cancel
        }
    }
}

class BlockBarButtonItem: UIBarButtonItem {
    
    var block: ((WKWebViewController) -> Void)?
}

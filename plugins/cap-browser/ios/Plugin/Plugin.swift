import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 */
@objc(CapBrowser)
public class CapBrowser: CAPPlugin {
    var navigationWebViewController: UINavigationController?
    private var privacyScreen: UIImageView?
    private var isSetupDone = false
    var currentPluginCall: CAPPluginCall?
    var isPresentAfterPageLoad = false
    var clearHistoryOnLoad = true
    
    private func setup(){
        self.isSetupDone = true

        #if swift(>=4.2)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        #else
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name:.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive(_:)), name:.UIApplicationWillResignActive, object: nil)
        #endif

        NotificationCenter.default.addObserver(self, selector: #selector(idVaultLocked(_:)), name: Notification.Name("idVaultLocked"), object: nil)
    }

    @objc func idVaultLocked(_ notification: NSNotification) {
        DispatchQueue.main.async {
         self.navigationWebViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    func presentView() {
        self.bridge?.viewController?.present(self.navigationWebViewController!, animated: true, completion: {
            self.currentPluginCall?.resolve()
        })
    }
    
    @objc func openWebView(_ call: CAPPluginCall) {
        if !self.isSetupDone {
            self.setup()
        }
        self.currentPluginCall = call
        
        guard let urlString = call.getString("url") else {
            call.reject("Must provide a URL to open")
            return
        }
        
        if urlString.isEmpty {
            call.reject("URL must not be empty")
            return
        }
        
        var headers: [String: String] = ["User-Agent": ""]
        if call.options["headers"] != nil {
            headers = call.options?["headers"] as! [String: String]
        }
        
        var disclaimerContent = call.getObject("shareDisclaimer")
        let toolbarType = call.getString("toolbarType")
        if toolbarType != "activity" {
            disclaimerContent = nil
        }
        
        self.isPresentAfterPageLoad = call.getBool("isPresentAfterPageLoad", false)
        self.clearHistoryOnLoad = call.getBool("clearHistoryOnLoad", true)
        
        DispatchQueue.main.async {
            let url = URL(string: urlString)
            let webViewController: WKWebViewController?
            
            if self.isPresentAfterPageLoad {
                webViewController = WKWebViewController.init(url: url!, headers: headers )
            } else {
                webViewController = WKWebViewController.init()
                webViewController?.setHeaders(headers: headers )
            }
            
            if url!.absoluteString.hasPrefix("file") {
                webViewController?.source = .file(url!, access: url!)
            } else {
                webViewController?.source = .remote(url!)
            }
            
            webViewController?.leftNavigaionBarItemTypes = self.getToolbarItems(toolbarType: toolbarType ?? "")
            
            webViewController?.toolbarItemTypes = []
            webViewController?.doneBarButtonItemPosition = .right
            webViewController?.capBrowserPlugin = self
            webViewController?.title = call.getString("title") ?? ""
            webViewController?.shareSubject = call.getString("shareSubject")
            webViewController?.shareDisclaimer = disclaimerContent
            webViewController?.toolbarType = toolbarType
            self.navigationWebViewController = UINavigationController.init(rootViewController: webViewController!)
            self.navigationWebViewController?.navigationBar.isTranslucent = false
            self.navigationWebViewController?.toolbar.isTranslucent = false
            self.navigationWebViewController?.navigationBar.backgroundColor = .white
            self.navigationWebViewController?.toolbar.backgroundColor = .white
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.navigationWebViewController?.modalPresentationStyle = .fullScreen
             } else {
                 self.navigationWebViewController?.modalPresentationStyle = .popover
            }
            
            if #available(iOS 15, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                self.navigationWebViewController?.navigationBar.standardAppearance = navBarAppearance
                self.navigationWebViewController?.navigationBar.scrollEdgeAppearance = self.navigationWebViewController?.navigationBar.standardAppearance
                
                let toolBarAppearance = UIToolbarAppearance()
                toolBarAppearance.configureWithOpaqueBackground()
                self.navigationWebViewController?.toolbar.standardAppearance = toolBarAppearance
                self.navigationWebViewController?.toolbar.scrollEdgeAppearance = self.navigationWebViewController?.toolbar.standardAppearance
            }
            
            if call.getBool("presentFullScreen", true) {
                self.navigationWebViewController?.modalPresentationStyle = .fullScreen
            }
            
            if toolbarType == "blank" {
                self.navigationWebViewController?.navigationBar.isHidden = true
            }
            
            if !self.isPresentAfterPageLoad {
                self.presentView()
            }
        }
    }
    
    func getToolbarItems(toolbarType: String) -> [BarButtonItemType] {
        var result: [BarButtonItemType] = []
        if toolbarType == "activity" {
            result.append(.activity)
        } else if toolbarType == "navigation" {
            result.append(.back)
            result.append(.forward)
        }
        return result
    }
    
    @objc func open(_ call: CAPPluginCall) {
        if !self.isSetupDone {
            self.setup()
        }
        
        self.currentPluginCall = call
        
        guard let urlString = call.getString("url") else {
            call.reject("Must provide a URL to open")
            return
        }
        
        if urlString.isEmpty {
            call.reject("URL must not be empty")
            return
        }
        
        let headers = call.options["headers"] as! [String: String]
        
        self.isPresentAfterPageLoad = call.getBool("isPresentAfterPageLoad", false)
        self.clearHistoryOnLoad = call.getBool("clearHistoryOnLoad", true)
        
        DispatchQueue.main.async {
            let url = URL(string: urlString)
            let webViewController: WKWebViewController?
            
            if self.isPresentAfterPageLoad {
                webViewController = WKWebViewController.init(url: url!, headers: headers )
            } else {
                webViewController = WKWebViewController.init()
                webViewController?.setHeaders(headers: headers )
            }
            
            if url!.absoluteString.hasPrefix("file") {
                webViewController?.source = .file(url!, access: url!)
            } else {
                webViewController?.source = .remote(url!)
            }
            
            webViewController?.leftNavigaionBarItemTypes = [.reload]
            if call.getBool("hideActivityBtn", false) {
                webViewController?.toolbarItemTypes = [.back, .fixedSpace, .forward, .flexibleSpace]
            }else {
                webViewController?.toolbarItemTypes = [.back, .fixedSpace, .forward, .flexibleSpace, .activity]
            }
            webViewController?.capBrowserPlugin = self
            webViewController?.hasDynamicTitle = true
            webViewController?.toolbarType = "navigation"
            self.navigationWebViewController = UINavigationController.init(rootViewController: webViewController!)
            self.navigationWebViewController?.navigationBar.isTranslucent = false
            self.navigationWebViewController?.toolbar.isTranslucent = false
            self.navigationWebViewController?.navigationBar.backgroundColor = .white
            self.navigationWebViewController?.toolbar.backgroundColor = .white
            self.navigationWebViewController?.modalPresentationStyle = .fullScreen
            
            if #available(iOS 15, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                self.navigationWebViewController?.navigationBar.standardAppearance = navBarAppearance
                self.navigationWebViewController?.navigationBar.scrollEdgeAppearance = self.navigationWebViewController?.navigationBar.standardAppearance
                
                let toolBarAppearance = UIToolbarAppearance()
                toolBarAppearance.configureWithOpaqueBackground()
                self.navigationWebViewController?.toolbar.standardAppearance = toolBarAppearance
                self.navigationWebViewController?.toolbar.scrollEdgeAppearance = self.navigationWebViewController?.toolbar.standardAppearance
            }
            
            if !self.isPresentAfterPageLoad {
                self.presentView()
            }
        }
    }
    
    @objc func close(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
         self.navigationWebViewController?.dismiss(animated: true, completion: nil)
            call.resolve()
        }
    }
    
    @objc func appDidBecomeActive(_ notification: NSNotification) {
    }
    
    @objc func appWillResignActive(_ notification: NSNotification) {
    }
}

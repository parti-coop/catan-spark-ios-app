//
//  UfoWebView.swift
//  PartiApp
//
//  Created by shkim on 12/24/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit
import WebKit
import Regex

protocol UfoWebDelegate : NSObjectProtocol
{
  func onWebPageStarted(_ urlString: String?)
  func onWebPageFinished(_ urlString: String?)
  func onWebPageNetworkError(_ urlString: String?)
  func onWebPageFinally(_ urlString: String?)
  func handleAction(_ action: String, withJSON json: [String:Any]?)
  func handleStartSocialSignIn(_ provider: String)
  func handleCallbackSocialSignIn(_ provider: String)
}

class UfoWebView : WKWebView, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate
{
  private static let URL_MOBILE_APP_START = ApiMan.getBaseUrl() + "mobile_app/start"

  private static let CATAN_USER_AGENT = " CatanSparkIOS/3";
  public var ufoDelegate: UfoWebDelegate?
  
  private var m_wasOfflinePageShown: Bool = false
  private var m_customUserAgent: String? = nil
  private var m_basePageUrlString: String? = nil
  private var m_currentUrlString: String? = nil

  public init() {
    let wkconf = WKWebViewConfiguration()
    super.init(frame:CGRect.zero, configuration:wkconf)
    wkconf.userContentController.add(self, name:"ufop")
    self.navigationDelegate = self
    self.uiDelegate = self
    self.scrollView.bounces = false
    self.allowsLinkPreview = false
    self.allowsBackForwardNavigationGestures = false

    loadHTMLString("<html></html>", baseURL: nil)
    evaluateJavaScript("navigator.userAgent") { [weak self] (result, error) in
      if let strongSelf = self, let userAgent = result as? String {
        strongSelf.customUserAgent = userAgent + UfoWebView.CATAN_USER_AGENT
        strongSelf.m_customUserAgent = strongSelf.customUserAgent
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func showOfflinePage() {
    loadLocalHtml("offline")
    m_wasOfflinePageShown = true
  }

  func onNetworkReady() {
    if m_wasOfflinePageShown, let lastOnlineUrlString = m_currentUrlString  {
      m_wasOfflinePageShown = false
      log.debug("Recover online: \(lastOnlineUrlString)")
      loadRemoteUrl(lastOnlineUrlString)
    }
  }

  func onNetworkOffline() {
    if !m_wasOfflinePageShown {
      m_wasOfflinePageShown = true
      log.debug("Offline!")
      showOfflinePage()
    }
  }

  func loadLocalHtml(_ filename: String) {
    let path = Bundle.main.path(forResource: filename, ofType: "html")
    let fileUrl = URL.init(fileURLWithPath: path!)
    super.loadFileURL(fileUrl, allowingReadAccessTo: Bundle.main.bundleURL)
  }
  
  func loadPushNotifiedRemoteUrl(_ targetUrlString: String) {
    loadRemoteUrl(targetUrlString, customHeaders: ["X-Catan-Push-Notified" : "true"])
  }

  func loadRemoteUrl(_ targetUrlString: String? = nil, customHeaders: [String: String] = [:]) {
    log.debug("loadRemoteUrl: \(targetUrlString ?? "nil")")
    m_wasOfflinePageShown = false
    guard let targetUrlString = targetUrlString else {
      loadRequest(UfoWebView.URL_MOBILE_APP_START)
      return
    }

    if !isControllUrl(targetUrlString) && (m_wasOfflinePageShown || (m_currentUrlString ?? "").isEmpty) {
      let escapedString = targetUrlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
      loadRequest("\(UfoWebView.URL_MOBILE_APP_START)?after=\(escapedString)", customHeaders: customHeaders)
      return
    }

    loadRequest(targetUrlString, customHeaders: customHeaders)
  }

  fileprivate func loadRequest(_ urlString: String, customHeaders: [String: String] = [:]) {
    guard let url = URL(string: urlString) else { return }
    let req = NSMutableURLRequest(url: url)
    for customHeader in customHeaders {
      req.addValue(customHeader.value, forHTTPHeaderField: customHeader.key)
    }
    super.load(req as URLRequest)
  }

  private func postJs(_ action: String, json jsonString: String?) {
    guard let ufoDelegate = ufoDelegate else { return }

    var json: [String: Any]? = nil
    if !Util.isNilOrEmpty(jsonString) {
      do {
        let data = jsonString!.data(using: .utf8)
        let jsonRaw = try JSONSerialization.jsonObject(with:data!, options: .allowFragments)
        json = jsonRaw as? [String: Any]
      } catch {
        log.warning("post: JSON parse failed: \(jsonString!)")
      }
    }

    ufoDelegate.handleAction(action, withJSON:json)
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == "ufop" {
      let body = message.body as? NSDictionary
      let method = body?["method"] as? String
      let arg0 = body?["arg0"] as? String
      let arg1 = body?["arg1"] as? String

      if "changeBasePageUrl" == method {
        log.debug("changeBasePageUrl")
        guard let urlString = arg0 else { return }
        m_basePageUrlString = urlString
      } else if "changeCurrentUrl" == method {
        log.debug("changeCurrentUrl")
        guard let urlString = arg0 else { return }
        m_currentUrlString = urlString
      } else if "goBack" == method {
        let urlString = m_basePageUrlString ?? Config.apiBaseUrl
        if urlString == self.backForwardList.backItem?.initialURL.absoluteString {
          goBack()
        } else {
          loadRemoteUrl(urlString)
        }
      } else if "startSocialSignIn" == method {
        guard let provider = arg0 else { return }
        ufoDelegate?.handleStartSocialSignIn(provider)
      } else if "callbackSocialSignIn" == method {
        guard let provider = arg0 else { return }
        ufoDelegate?.handleCallbackSocialSignIn(provider)
      } else if "post" == method {
        postJs(arg0 ?? "", json: arg1)
      } else {
        log.warning("Unknown ufo method: \(method ?? "nil")")
      }
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let urlString = webView.url?.absoluteString ?? "nil"
    log.debug("didFinishNavigation: \(urlString)")
    ufoDelegate?.onWebPageFinished(urlString)
    ufoDelegate?.onWebPageFinally(urlString)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    let nserr = error as NSError

    let urlString = webView.url?.absoluteString
    log.debug("didFailProvisionalNavigation: \(urlString ?? "nil") \(nserr.code)")

    switch (nserr.code)
    {
    case 102,// frame load interrupted
      NSURLErrorCancelled:
      break

    case NSURLErrorUnsupportedURL,
      NSURLErrorTimedOut,
      NSURLErrorCannotFindHost,
      NSURLErrorCannotConnectToHost,
      NSURLErrorNetworkConnectionLost,
      NSURLErrorDNSLookupFailed,
      NSURLErrorResourceUnavailable,
      NSURLErrorNotConnectedToInternet,
      NSURLErrorRedirectToNonExistentLocation:
      ufoDelegate?.onWebPageNetworkError(urlString)
      break

    default:
      break
    }

    ufoDelegate?.onWebPageFinally(urlString)
  }

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    let alertController = UIAlertController(title:nil, message:message, preferredStyle:.alert)
    alertController.addAction(UIAlertAction(title:Util.getLocalizedString("ok"),
      style:.cancel, handler: { _ in completionHandler() }))
    ViewController.instance.present(alertController, animated:true, completion:nil)
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    let alertController = UIAlertController(title:nil, message:message, preferredStyle:.alert)
    alertController.addAction(UIAlertAction(title:Util.getLocalizedString("yes"),
      style:.`default`, handler: { _ in completionHandler(true) }))
    alertController.addAction(UIAlertAction(title:Util.getLocalizedString("no"),
      style:.cancel, handler: { _ in completionHandler(false) }))
    ViewController.instance.present(alertController, animated:true, completion:nil)
  }

    // WKWebView에서 자바스크립트로 window.open(), window.close() 하는 경우 처리
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    loadRemoteUrl(navigationAction.request.url?.absoluteString)
    return nil
  }

#if DEBUG
  // Allow self-signed https
  func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    guard let serverTrust = challenge.protectionSpace.serverTrust else {
      return completionHandler(.useCredential, nil)
    }

    let exceptions = SecTrustCopyExceptions(serverTrust)
    SecTrustSetExceptions(serverTrust, exceptions)
    completionHandler(.useCredential, URLCredential(trust: serverTrust))
  }
#endif

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    var request = navigationAction.request
    guard let requestUrl = request.url else {
      // failed to get url
      decisionHandler(.cancel)
      return
    }
    let requestUrlString = requestUrl.absoluteString

    log.debug("willNavigate \(request.httpMethod ?? "?"): \(requestUrlString)")

    if requestUrlString == "about:blank" {
      decisionHandler(.allow)
      return
    }

    if requestUrlString.hasPrefix("ufo:") {
      let index = requestUrlString.index(requestUrlString.startIndex, offsetBy: 4)
      handleUfoLink(String(requestUrlString.suffix(from: index)))
      decisionHandler(.cancel)
      return
    }
    
    if requestUrlString.hasPrefix("mailto:") {
      UIApplication.shared.open(requestUrl, options: [:], completionHandler: nil)
      decisionHandler(.cancel)
      return
    }
    
    if requestUrlString.hasPrefix("http") {
      if let targetFrm = navigationAction.targetFrame, targetFrm.isMainFrame == false {
        allowHttpNavigationAction(decisionHandler, requestUrlString: requestUrlString)
        return
      }

      if request.httpMethod != "GET" {
        allowHttpNavigationAction(decisionHandler, requestUrlString: requestUrlString)
        return
      }

      // 이미 프로세싱되어 있는지 확인한다
      if request.value(forHTTPHeaderField: "x-catan-spark-app") == "processed" {
          allowHttpNavigationAction(decisionHandler, requestUrlString: requestUrlString)
          return
      }
      guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
          allowHttpNavigationAction(decisionHandler, requestUrlString: requestUrlString)
          return
      }
      mutableRequest.setValue("processed", forHTTPHeaderField: "x-catan-spark-app")
      webView.customUserAgent = self.m_customUserAgent

      // [ 빠띠 내의 주소인지 확인하고 처리 ]
      // 빠띠 내의 주소면 무조건 현재 웹뷰에서 처리
      //
      // [ _blank처리 ]
      //
      // webView(_ webView, createWebViewWith: WKWebViewConfiguration, for: WKNavigationAction, windowFeatures: WKWindowFeatures) 보다 먼저 처리됨
      //
      // WKNavigationAction#targetFrame
      // The target frame, or nil if this is a new window navigation.
      //
      // https://developer.apple.com/documentation/webkit/wknavigationaction/1401918-targetframe
      let isPartiPage = requestUrl.absoluteString =~ Config.apiBaseUrlRegex.r
      if navigationAction.targetFrame != nil || isPartiPage {
        // 앱 내의 웹뷰에서 계속 진행합니다.
        // ex) webView.load(mutableRequest as URLRequest)
        if self.m_customUserAgent != request.value(forHTTPHeaderField: "User-Agent") {
          // user agent가 맞지 않으므로 새로운 요청을 시작한다
          log.debug("Start new request with new user agent : \(requestUrlString) : user agent - \(self.m_customUserAgent ?? "")");
          mutableRequest.setValue(self.m_customUserAgent, forHTTPHeaderField: "User-Agent")
          restartHttpNavigationAction(decisionHandler, request: mutableRequest)
          return
        } else {
          allowHttpNavigationAction(decisionHandler, requestUrlString: requestUrlString)
          return
        }
      } else {
        // 외부 브라우저를 엽니다. (사파리)
        UIApplication.shared.open(requestUrl, options: [:], completionHandler: nil)
        decisionHandler(.cancel)
        return
      }
    }

    if UIApplication.shared.canOpenURL(requestUrl) {
      //urlscheme, tel, mailto, etc.
      UIApplication.shared.open(requestUrl, options: [:], completionHandler: nil)
      decisionHandler(.cancel)
      return;
    }
    // unknown scheme
    decisionHandler(.allow)
  }

  fileprivate func allowHttpNavigationAction(_ decisionHandler: @escaping (WKNavigationActionPolicy) -> Void, requestUrlString: String) {
    ufoDelegate?.onWebPageStarted(requestUrlString)
    decisionHandler(.allow)
  }

  fileprivate func restartHttpNavigationAction(_ decisionHandler: @escaping (WKNavigationActionPolicy) -> Void, request: NSMutableURLRequest) {
    load(request as URLRequest)
    decisionHandler(.cancel)
  }

  func evalJs(_ jsStr: String) {
    evaluateJavaScript(jsStr)
  }

  func handleUfoLink(_ ufoCommand: String) {
    let rngSlash_: Range<String.Index>? = ufoCommand.range(of: "/")

    var action: String!
    var param: String?
    if let rngSlash = rngSlash_ {
      let slashLeft = ufoCommand.index(rngSlash.lowerBound, offsetBy: -1)
      action = String(ufoCommand[...slashLeft])
      param = String(ufoCommand[rngSlash.lowerBound...])
    } else {
      action = ufoCommand
      param = nil
    }

    if action == "post" {
      postJs(param ?? "", json:nil)
        } else if action == "eval" {
      if param != nil {
        evalJs(param!)
      }
    } else  {
      log.warning("Unhandled action: \(action) param=\(param ?? "nil")")
    }
  }

  func isControllUrl(_ urlString: String?) -> Bool {
    return urlString == nil || UfoWebView.URL_MOBILE_APP_START == urlString || urlString == "about:blank"
  }
  
  func clearHistory() {
    m_basePageUrlString = nil
    m_currentUrlString = nil
  }
  
  func isCancelableLoading() -> Bool {
    return !isControllUrl(url?.absoluteString)
  }
}

//
//  ViewController.swift
//  PartiApp
//
//  Created by shkim on 12/22/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit

import MBProgressHUD
import Network
import GoogleSignIn
import FirebaseMessaging
import Firebase
import FirebaseCrashlytics
import WebKit
import NVActivityIndicatorView
import GoogleSignIn
import FBSDKCoreKit
import FBSDKLoginKit
import SystemConfiguration

var myContext = 0

class ViewController: UIViewController, UIDocumentInteractionControllerDelegate
  ,UfoWebDelegate, ApiResultDelegate
{
  private static let KEY_AUTHKEY = "xAK"
  static var instance: ViewController!

  @objc var m_webView: UfoWebView!
  var m_progressView: UIProgressView!

  var m_timeHideQueued: DispatchTime = .now()

  var m_downloadProgress: UIProgressView?
  var m_downloadAlertCtlr: UIAlertController?
  var m_curDownloadFilename: String?
  var m_curDownloadedFileUrl: URL?

  var m_reachable: Reachable?
  var m_isConnectedNetwork = false
  
  var m_indicator: NVActivityIndicatorView!
  
  var m_docIC = UIDocumentInteractionController.init()

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  private func showToast(_ msg: String) {
    let toast = MBProgressHUD.showAdded(to: view, animated: true)
    toast.mode = MBProgressHUDMode.text
    toast.label.text = msg
    toast.offset = CGPoint(x: 0, y: MBProgressMaxOffset)
    toast.hide(animated: true, afterDelay: 3)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    ViewController.instance = self

#if DEBUG
    ApiMan.setDevMode()
    showToast("개발자모드")
#endif

    setupReachability()
    setupWebView()
    setupProgressBar()

    m_progressView.isHidden = true
    m_webView.loadRemoteUrl()
    
    setupGoogleSignIn()
    setupFacebookSignIn()
    
    self.m_docIC.delegate = self
  }

  fileprivate func setupWebView() {
    m_webView = UfoWebView()
    m_webView.ufoDelegate = self
    m_webView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(m_webView)
    
    self.view.addConstraint(NSLayoutConstraint(item: m_webView,
                                               attribute: .top,
                                               relatedBy: .equal,
//                                               toItem:self.topLayoutGuide,
                                               toItem: view.safeAreaLayoutGuide,
                                               attribute: .top,
                                               multiplier: 1.0,
                                               constant: 0))
    
//    var b = self.topLayoutGuide
//    var a = view.safeAreaLayoutGuide.topAnchor
//    b.

    self.view.addConstraint(NSLayoutConstraint(item: m_webView,
                                               attribute: .bottom,
                                               relatedBy: .equal,
                                               toItem: self.view,
                                               attribute: .bottom,
                                               multiplier: 1.0,
                                               constant: 0))

    self.view.addConstraint(NSLayoutConstraint(item: m_webView,
                                               attribute: .leading,
                                               relatedBy: .equal,
                                               toItem: self.view,
                                               attribute: .leading,
                                               multiplier: 1.0,
                                               constant: 0))

    self.view.addConstraint(NSLayoutConstraint(item:m_webView,
                                               attribute:.trailing,
                                               relatedBy:.equal,
                                               toItem:self.view,
                                               attribute:.trailing,
                                               multiplier:1.0,
                                               constant:0))
  }

  fileprivate func setupProgressBar() {
    //add progresbar to navigation bar
    m_progressView = UIProgressView(progressViewStyle: .default)
    m_progressView.translatesAutoresizingMaskIntoConstraints = false
    m_progressView.tintColor = #colorLiteral(red: 0.5882352941, green: 0.4352941176, blue: 0.8392156863, alpha: 1)
    m_progressView.trackTintColor = #colorLiteral(red: 0.9450980392, green: 0.9215686275, blue: 0.9843137255, alpha: 1)

    self.view.addSubview(m_progressView)
    m_progressView.topAnchor.constraint(equalTo: m_webView.topAnchor).isActive = true
    m_progressView.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
    m_progressView.heightAnchor.constraint(equalToConstant: 3).isActive = true

    m_webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: &myContext)
  }
  
  // Sign In
  private static let AUTH_PROVIDER_FACEBOOK = "facebook"
  private static let AUTH_PROVIDER_GOOGLE = "google_oauth2"
  
  fileprivate func setupGoogleSignIn() {
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.authGoogleClientId, serverClientID: Config.authGoogleServerClientId)
  }
  
  fileprivate func setupFacebookSignIn() {
    Settings.shared.appID = Config.authFacebookAppId
  }
  
  func handleStartSocialSignIn(_ provider: String) {
    if ViewController.AUTH_PROVIDER_FACEBOOK == provider {
      let login = LoginManager.init()
      // login.loginBehavior = LoginBehavior.browser
      self.isStatusBarHidden = true
      login.logIn(permissions: ["email"], from: self) { [weak self] (result, error) in
        guard let strongSelf = self else { return }
        
        strongSelf.isStatusBarHidden = false

        if let error = error {
          strongSelf.facebookSignInFailureCallback(error)
        } else if (result?.isCancelled ?? false) {
          strongSelf.facebookSignInCancelCallback()
        } else {
          _ = strongSelf.facebookSignInSuccessCallback()
        }
      }
    } else if(ViewController.AUTH_PROVIDER_GOOGLE == provider) {
      GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] result, error in
        guard error == nil else {
          googleSignInFailureCallback(error)
          return
        }
        
        guard let user = result?.user,
              let tokenString = user.idToken?.tokenString
        else {
          googleSignInFailureCallback(error)
          return
        }

        googleSignInSuccessCallback(tokenString)
      }
    }
  }
  
  var isStatusBarHidden = false {
    didSet{
      self.setNeedsStatusBarAppearanceUpdate()
    }
  }
  
  override var prefersStatusBarHidden: Bool {
    return isStatusBarHidden
  }
  
  func handleCallbackSocialSignIn(_ provider: String) {
    if ViewController.AUTH_PROVIDER_FACEBOOK == provider {
      if(facebookSignInSuccessCallback()) {
        return
      } else {
        socialAuthSignInFailureCallback()
      }
    } else if ViewController.AUTH_PROVIDER_GOOGLE == provider {
      socialAuthSignInFailureCallback()
    }
  }
  
  func googleSignInSuccessCallback(_ tokenString: String) {
    m_webView.evalJs("ufo.successAuth('\(ViewController.AUTH_PROVIDER_GOOGLE)', '\(String(describing: tokenString))')")
  }
  
  func googleSignInFailureCallback(_ error: Error?) {
    guard let gidError = error as? GIDSignInError else {
      socialAuthSignInFailureCallback(error)
      Crashlytics.crashlytics().record(error: NSError(domain: "Google Login Error - Known", code: -1))
      return
    }
    
    if gidError.code == .canceled {
      socialAuthSignInCancelCallback()
      return
    }
    
    socialAuthSignInFailureCallback(error)
    Crashlytics.crashlytics().record(error: NSError(domain: "Google Login Error", code: gidError.errorCode, userInfo: gidError.userInfo))
  }
  
  func facebookSignInSuccessCallback() -> Bool {
    guard let currentToken = AccessToken.current else { return false }
    m_webView.evalJs("ufo.successAuth('\(ViewController.AUTH_PROVIDER_FACEBOOK)', '\(currentToken.tokenString )')")
    return true
  }
  
  func facebookSignInFailureCallback(_ error: Error) {
    socialAuthSignInFailureCallback(error)
  }
  
  func facebookSignInCancelCallback() {
    socialAuthSignInCancelCallback()
  }
  
  fileprivate func socialAuthSignInCancelCallback() {
    showToast("로그인을 취소했습니다")
    m_webView.evalJs("ufo.failureAuth()")
  }
  
  fileprivate func socialAuthSignInFailureCallback(_ error: Error? = nil) {
    if let description = error?.localizedDescription {
      log.error("Sign-in Error \(description)")
    }
    showToast("다시 시도해 주세요")
    m_webView.evalJs("ufo.failureAuth()")
  }

  private func setupReachability() {
    self.m_reachable = Reachability()
    self.m_reachable?.startNetworkReachabilityObserver()
    [
      Notifications.Reachability.connected.name, Notifications.Reachability.notConnected.name
    ].forEach { notification in
      NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged(notification:)), name: notification, object: nil)
    }
  }
  
  @objc func reachabilityChanged(notification: Notification?) {
    guard let reachability = notification?.object as? Notifications.Reachability else {
      return
    }

    if reachability.name == Notifications.Reachability.connected.name {
      log.debug("RemoteHostReachable", context: self.m_reachable?.isConnected)
      m_webView.onNetworkReady()
    } else {
      m_webView.onNetworkOffline()
      log.debug("RemoteHostNotReachable", context: self.m_reachable?.isConnected)
    }
  }

  deinit {
    //stop network monitor
    m_reachable?.stopNetworkReachabilityObserver()
    //remove all observers
    m_webView.removeObserver(self, forKeyPath: "estimatedProgress")
    //remove progress bar from navigation bar
    m_progressView.removeFromSuperview()
  }

  func handlePushNotification(_ url: String) {
    let urlToGo: String
    if url.hasPrefix("/") {
      urlToGo = ApiMan.getBaseUrl() + String(url.dropFirst())
    } else {
      urlToGo = url
    }

    m_webView.loadPushNotifiedRemoteUrl(urlToGo)
  }
  
  func handleUniversalLink(_ url: String) {
    m_webView.loadRemoteUrl(url)
  }

  //observer
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

    guard let change = change else { return }
    if context != &myContext {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
      return
    }

    if keyPath == "estimatedProgress" {
      m_progressView.alpha = 0.6

      if m_webView.estimatedProgress < 1.0 {
        m_progressView.layer.removeAllAnimations()
      }

      m_progressView.setProgress(Float(m_webView.estimatedProgress), animated: true)

      if m_webView.estimatedProgress >= 1.0 {
        UIView.animate(withDuration: 0.3, delay: 0.3, options: [.curveEaseOut],
                       animations: { [weak self] in self?.m_progressView.alpha = 0.0 },
                       completion: { [weak self] _ in
                        if self?.m_progressView.progress ?? 0.0 >= 1.0 {
                          self?.m_progressView.setProgress(0.0, animated: false)
                        }
        })
        hideLoadingIndicator()
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
      } else {
        if m_webView.estimatedProgress >= 0.85 {
          hideLoadingIndicator()
        } else {
          delayedShowLoadingIndicator()
        }
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
      }
      return
    }
  }

  private func isShowWait() -> Bool {
    return false
  }

  func onWebPageStarted(_ url: String?) {
    log.debug("onWebPageStarted: \(url ?? "nil")")
  }

  func onWebPageFinished(_ url: String?) {
    log.debug("onWebPageFinished: \(url ?? "nil")")

    // 처음 뷰가 로딩될 때는 숨겨놓았다가
    // 첫 페이지가 표시 완료되고 난 후 부터는
    // 프로그레스를 보여 줍니다.
    if !m_webView.isControllUrl(url) {
        m_progressView.isHidden = false
    }
  }

  func onWebPageNetworkError(_ url: String?) {
    log.warning("onWebPageNetworkError: \(url ?? "nil")")
    if m_reachable?.isConnected ?? false {
      showToast("앗! 연결할 수 없습니다. 나중에 다시 시도해 주세요.")
    } else {
      log.warning("showOfflinePage onWebPageNetworkError: \(url ?? "nil")")
      m_webView.showOfflinePage()
    }
  }

  func onWebPageFinally(_ url: String?) {
    log.debug("onWebPageFinally: \(url ?? "nil")")
    hideLoadingIndicator()
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
  }

  private func getAuthKey() -> String? {
    let ud = UserDefaults.standard
    return ud.object(forKey: ViewController.KEY_AUTHKEY) as? String
  }

  func handleAction(_ action: String, withJSON json: [String : Any]?) {
    if action == "noAuth" {
      let authkey = getAuthKey()
      m_webView.evalJs("restoreAuth('\(authkey ?? "")')")
    } else if action == "saveAuth" {
      if let authkey = json?["auth"] as? String {
        let ud = UserDefaults.standard
        ud.set(authkey, forKey:ViewController.KEY_AUTHKEY)
        ud.synchronize()

        let pushToken = Messaging.messaging().fcmToken
        #if DEBUG
          let appId = "xyz.parti.catan.ios.debug"
        #else
          let appId = "xyz.parti.catan.ios"
        #endif
        AppDelegate.getApiManager().requestRegisterToken(self as ApiResultDelegate, authkey: authkey, pushToken: pushToken, appId: appId)

        Crashlytics.crashlytics().setUserID(authkey)
        
        m_webView.clearHistory()
      }

    } else if action == "logout" {
      let ud = UserDefaults.standard
      let lastAuthKey = ud.object(forKey: ViewController.KEY_AUTHKEY) as? String
      if lastAuthKey != nil {
        ud.removeObject(forKey: ViewController.KEY_AUTHKEY)
        ud.synchronize()

        let pushToken = Messaging.messaging().fcmToken
        if !Util.isNilOrEmpty(pushToken) {
          AppDelegate.getApiManager().requestDeleteToken(self as ApiResultDelegate, authkey: lastAuthKey!, pushToken: pushToken)
        }
      }
      
      // Facebook & Google logout
      LoginManager().logOut()
      GIDSignIn.sharedInstance.signOut()
    } else if action == "download" {
      handleDownload(json)
    } else if action == "reload" {
      if isConnectedToNetwork() {
        m_webView.onNetworkReady()
      } else {
        showToast("연결이 지연되고 있습니다")
      }
    } else if action == "share" {
      var activityItems = [Any]()
      
      guard let textShare = json?["text"] else { showToast("공유 설정에 오류가 있습니다"); return }
      activityItems.append(textShare)
      
      if let urlString = (json?["url"] as? String), !Util.isNilOrEmpty(urlString), let url = NSURL(string: urlString) {
        activityItems.append(url)
      }
      
      let copyUrlToclipboard = CopyUrlToClipboardActivity()
      let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: [copyUrlToclipboard])
      activityViewController.popoverPresentationController?.sourceView = self.view
      self.present(activityViewController, animated: true, completion: nil)
    } else {
      log.warning("unhandled post action: \(action)")
    }
  }
  
  func isConnectedToNetwork() -> Bool {
    guard let flags = getFlags() else { return false }
    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    return (isReachable && !needsConnection)
  }

  private func getFlags() -> SCNetworkReachabilityFlags? {
    guard let reachability = ipv4Reachability() ?? ipv6Reachability() else {
      return nil
    }
    var flags = SCNetworkReachabilityFlags()
    if !SCNetworkReachabilityGetFlags(reachability, &flags) {
      return nil
    }
    return flags
  }

  private func ipv6Reachability() -> SCNetworkReachability? {
    var zeroAddress = sockaddr_in6()
    zeroAddress.sin6_len = UInt8(MemoryLayout<sockaddr_in>.size)
    zeroAddress.sin6_family = sa_family_t(AF_INET6)

    return withUnsafePointer(to: &zeroAddress, {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    })
  }

  private func ipv4Reachability() -> SCNetworkReachability? {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    zeroAddress.sin_family = sa_family_t(AF_INET)

    return withUnsafePointer(to: &zeroAddress, {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    })
  }

  private func handleDownload(_ json: [String : Any]?) {
    let _postId = json?["post"] as? Int
    let _fileId = json?["file"] as? Int
    let _fileName = json?["name"] as? String

    guard let postId = _postId, let fileId = _fileId, let fileName = _fileName else {
      Util.showSimpleAlert("다운로드 파라메터가 올바르지 않습니다.")
      return
    }

    let docPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    //let prefix = Util.getMD5Hash("P\(postId)F\(fileId)_\(fileName)")
    //let destPath = "\(docPath)/\(prefix)_\(fileName)"
    let destPath = "\(docPath)/\(fileName)"
    log.debug("File download at: \(destPath)")

    // remove old file
    let destPathUrl = URL.init(fileURLWithPath: destPath)
    try? FileManager.default.removeItem(at: destPathUrl)

    AppDelegate.getApiManager().requestFileDownload(self, authkey: getAuthKey(), postId: postId, fileId: fileId, atLocalPath: destPath)
    m_curDownloadFilename = fileName

    m_downloadAlertCtlr = UIAlertController(title: Util.getLocalizedString("downloading"), message: nil, preferredStyle: .alert)

    m_downloadAlertCtlr!.addAction(UIAlertAction(title: Util.getLocalizedString("cancel"),
      style: .default, handler: { _ in
      AppDelegate.getApiManager().cancelDownload()
    }))

    self.present(m_downloadAlertCtlr!, animated: true, completion: {
      guard let alert = self.m_downloadAlertCtlr else {
        return
      }

      let margin: CGFloat = 15
      let rect = CGRect(x:margin, y:60, width:alert.view.frame.width - margin * 2 , height: 2)
      self.m_downloadProgress = UIProgressView(frame: rect)
        guard let downloadProgress = self.m_downloadProgress else { return }

      downloadProgress.tintColor = UIColor.blue
      alert.view.addSubview(downloadProgress)
    })

  }

  func onApi(_ jobId: Int, failedWithErrorMessage errMsg: String) -> Bool {
    switch (jobId)
    {
    case ApiMan.JOBID_DOWNLOAD_FILE:
      purgeDownloadedFile()
      hideDownloadingHud({ Util.showSimpleAlert(Util.getLocalizedString("download_fail")) })
      return true

    default:
      break
    }

    return false
  }

  func onApi(_ jobId: Int, finishedWithResult _param: Any?) {
    log.debug("Info: api \(jobId) succeeded")

    switch (jobId)
    {
    case ApiMan.JOBID_DOWNLOAD_FILE:
      let downInfo = _param as! HttpFileDownloadResult
      hideDownloadingHud({ self.openDownloadedFile(downInfo.localFileUrl!) })
      break

    default:
      return
    }
  }

  private func hideDownloadingHud(_ completion: (() -> Swift.Void)? = nil) {
    m_downloadProgress = nil
    m_downloadAlertCtlr?.dismiss(animated: true, completion: completion)
    m_downloadAlertCtlr = nil
  }

  func onApi(_ jobId: Int, downloadedSoFar current: Int64, ofTotal total: Int64) {
    m_downloadProgress?.progress = Float(current) / Float(total)
  }

  private func openDownloadedFile(_ fileUrl: URL) {
    log.debug("openDownloadedFile: \(fileUrl)")
    
    self.m_docIC.url = fileUrl
    self.m_docIC.uti = fileUrl.typeIdentifier ?? "public.data, public.content"
    self.m_docIC.name = fileUrl.localizedName ?? fileUrl.lastPathComponent
    if !self.m_docIC.presentPreview(animated: true) {
      self.m_docIC.presentOptionsMenu(from: self.view.frame, in: self.view, animated: true)
    }
  }

  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return self
  }

  private func purgeDownloadedFile() {
    m_curDownloadFilename = nil
    if let url = m_curDownloadedFileUrl {
      log.debug("delete downloaded file: \(url)")
      try? FileManager.default.removeItem(at: url)
      m_curDownloadedFileUrl = nil
    }
  }

  func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
    purgeDownloadedFile()
  }

  func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
    log.debug("didEndSendingToApplication")
  }
  
  func delayedShowLoadingIndicator() {
    if m_indicator == nil {
      m_indicator = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40.0, height: 40.0), type: NVActivityIndicatorType.ballPulse, color: UIColor.white, padding: 10)
      m_indicator.backgroundColor = #colorLiteral(red: 0.5882352941, green: 0.4352941176, blue: 0.8392156863, alpha: 1)
      m_indicator.layer.cornerRadius = 5
      m_indicator.layer.masksToBounds = true
      // add subview
      view.addSubview(m_indicator)
      // autoresizing mask
      m_indicator.translatesAutoresizingMaskIntoConstraints = false
      // constraints
      view.addConstraint(NSLayoutConstraint(item: m_indicator, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0))
      view.addConstraint(NSLayoutConstraint(item: m_indicator, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0))
      
      m_indicator.isUserInteractionEnabled = true
      let gesture:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(loadingIndicatorTapped(_:)))
      gesture.numberOfTapsRequired = 1
      m_indicator.addGestureRecognizer(gesture)
    }
    
    if m_webView.isCancelableLoading() {
      perform(#selector(showLoadingIndicator), with: nil, afterDelay: 4)
    }
  }
  
  @objc func showLoadingIndicator(){
    if !m_webView.isLoading { return }
    
    UIView.transition(with: m_indicator, duration: 0.4, options: .transitionCrossDissolve, animations: { [weak self] in
        self?.m_indicator.isHidden = false
        }, completion: nil)
    
    m_indicator.startAnimating()
  }

  func hideLoadingIndicator(){
    stopLoadingIndicator()
    if m_indicator != nil { m_indicator.isHidden = true }
  }
  
  func stopLoadingIndicator(){
    if m_indicator != nil { m_indicator.stopAnimating() }
  }
  
  @objc func loadingIndicatorTapped(_ sender: NVActivityIndicatorView) {
    if m_webView.isCancelableLoading() {
      m_webView.stopLoading()
    }
  }
}

extension URL {
  var typeIdentifier: String? {
    return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
  }
  var localizedName: String? {
    return (try? resourceValues(forKeys: [.localizedNameKey]))?.localizedName
  }
}

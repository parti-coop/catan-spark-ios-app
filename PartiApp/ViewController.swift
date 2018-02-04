//
//  ViewController.swift
//  PartiApp
//
//  Created by shkim on 12/22/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit

import MBProgressHUD
import TMReachability
import FirebaseMessaging
import Crashlytics
import WebKit

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

    var m_remoteHostReach: TMReachability?

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
  }

    fileprivate func setupWebView() {
        m_webView = UfoWebView()
        m_webView.ufoDelegate = self
        m_webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(m_webView)

        self.view.addConstraint(NSLayoutConstraint(item:m_webView,
                                                   attribute:.top,
                                                   relatedBy:.equal,
                                                   toItem:self.topLayoutGuide,
                                                   attribute:.bottom,
                                                   multiplier:1.0,
                                                   constant:0))

        self.view.addConstraint(NSLayoutConstraint(item:m_webView,
                                                   attribute:.bottom,
                                                   relatedBy:.equal,
                                                   toItem:self.view,
                                                   attribute:.bottom,
                                                   multiplier:1.0,
                                                   constant:0))

        self.view.addConstraint(NSLayoutConstraint(item:m_webView,
                                                   attribute:.leading,
                                                   relatedBy:.equal,
                                                   toItem:self.view,
                                                   attribute:.leading,
                                                   multiplier:1.0,
                                                   constant:0))

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

  private func setupReachability() {
    NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged(noti:)),
      name: NSNotification.Name.reachabilityChanged, object: nil)

        self.m_remoteHostReach = TMReachability.forInternetConnection()
    self.m_remoteHostReach?.startNotifier()
  }

  @objc func reachabilityChanged(noti: Notification?) {
    guard let reach = noti?.object as? TMReachability else {
      return
    }

    if reach.isReachable() {
      //print("RemoteHostReachable", reach.currentReachabilityString())
      m_webView.onNetworkReady()
    } else {
            m_webView.onNetworkOffline()
      //print("RemoteHostNotReachable", reach.currentReachabilityString())
    }
  }

    deinit {
        //remove all observers
        m_webView.removeObserver(self, forKeyPath: "estimatedProgress")
        //remove progress bar from navigation bar
        m_progressView.removeFromSuperview()
    }

  func safelyGoToUrl(_ url: String) {
    let urlToGo: String
    if url.hasPrefix("/") {
      urlToGo = ApiMan.getBaseUrl() + String(url.dropFirst())
    } else {
      urlToGo = url
    }

        m_webView.loadRemoteUrl(urlToGo)
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
            }
            return
        }
    }

  private func isShowWait() -> Bool {
        return false
  }

    func onWebPageStarted(_ url: String?) {
        print("onWebPageStarted: \(url ?? "nil")")
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }

  func onWebPageFinished(_ url: String?) {
    print("onWebPageFinished: \(url ?? "nil")")

        // 처음 뷰가 로딩될 때는 숨겨놓았다가
        // 첫 페이지가 표시 완료되고 난 후 부터는
        // 프로그레스를 보여 줍니다.
        if !m_webView.isControllUrl(url) {
            m_progressView.isHidden = false
        }
  }

    func onWebPageNetworkError(_ url: String?) {
        print("onWebPageNetworkError: \(url ?? "nil")")
        if m_remoteHostReach?.isReachable() ?? false {
            showToast("앗! 연결할 수 없습니다. 나중에 다시 시도해 주세요.")
        } else {
            m_webView.showOfflinePage()
        }
    }

    func onWebPageFinally(_ url: String?) {
        print("onWebPageFinally: \(url ?? "nil")")
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
        let appId = Bundle.main.bundleIdentifier!
        AppDelegate.getApiManager().requestRegisterToken(self as ApiResultDelegate, authkey: authkey, pushToken: pushToken, appId: appId)

        //Crashlytics.sharedInstance().setUserEmail("user@fabric.io")
        //Crashlytics.sharedInstance().setUserName("Test User")
        Crashlytics.sharedInstance().setUserIdentifier(authkey)
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
    } else if action == "download" {
      handleDownload(json)
        } else if action == "reload" {
            if isConnectedToNetwork() {
                m_webView.onNetworkReady()
            } else {
                showToast("연결이 지연되고 있습니다")
            }
        } else {
      print("unhandled post action: \(action)")
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
    print("File download at: \(destPath)")

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
    print("Info: api \(jobId) succeeded")

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
    print("openDownloadedFile: \(fileUrl)")
        let m_docIC: UIDocumentInteractionController = UIDocumentInteractionController.init(url: fileUrl)
    m_docIC.delegate = self
    m_docIC.name = m_curDownloadFilename
    m_curDownloadedFileUrl = fileUrl

        if !m_docIC.presentPreview(animated: true) {
            showToast("파일을 열 수 있는 앱이 없습니다.")
        }
//        m_docIC.presentOpenInMenu(from: CGRect.zero, in: m_webView, animated: true)
  }

  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return self
  }

  private func purgeDownloadedFile() {
    m_curDownloadFilename = nil
    if let url = m_curDownloadedFileUrl {
      print("delete downloaded file: \(url)")
      try? FileManager.default.removeItem(at: url)
      m_curDownloadedFileUrl = nil
    }
  }

  func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
    purgeDownloadedFile()
  }

  func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
    print("didEndSendingToApplication")
  }
}

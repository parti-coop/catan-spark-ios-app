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

class ViewController: UIViewController, UIDocumentInteractionControllerDelegate
	,UfoWebDelegate, ApiResultDelegate
{
	@IBOutlet weak var vwWaitScreen: UIView!

	private static let KEY_AUTHKEY = "xAK"
	static var instance: ViewController!

	var m_webView: UfoWebView!

	var m_isInitialWaitDone = false
	var m_nPageFinishCount = 0

	var m_timeHideQueued: DispatchTime = .now()

	var m_downloadingHud: MBProgressHUD?
	var m_curDownloadFilename: String?
	var m_curDownloadedFileUrl: URL?

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		ViewController.instance = self
		
#if DEBUG
		ApiMan.setDevMode()
	
		let toast = MBProgressHUD.showAdded(to: view, animated: true)
		toast.mode = MBProgressHUDMode.text
		toast.label.text = "개발자모드"
		toast.offset = CGPoint(x: 0, y: MBProgressMaxOffset)
		toast.hide(animated: true, afterDelay: 3)
#endif

		setupReachability()
		
		m_webView = UfoWebView()
		m_webView.ufoDelegate = self
		m_webView.translatesAutoresizingMaskIntoConstraints = false
		self.view.insertSubview(m_webView, belowSubview:self.vwWaitScreen)

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
	
		m_webView.loadRemoteUrl(ApiMan.getBaseUrl() + "mobile_app/start")
	}
	
	private func setupReachability() {
		NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged(noti:)),
			name: NSNotification.Name.reachabilityChanged, object: nil)

		let remoteHostReach = TMReachability(hostname: "google.com")
		remoteHostReach?.startNotifier()
	}
	
	@objc func reachabilityChanged(noti: Notification?) {
		guard let reach = noti?.object as? TMReachability else {
			return
		}

		if reach.isReachable() {
			//print("RemoteHostReachable", reach.currentReachabilityString())
			m_webView.onNetworkReady()
		} else {
			//print("RemoteHostNotReachable", reach.currentReachabilityString())
		}
	}

	func gotoUrl(_ url: String) {
		let urlToGo: String
		if url.hasPrefix("/") {
			urlToGo = ApiMan.getBaseUrl() + String(url.dropFirst())
		} else {
			urlToGo = url
		}
		
		m_webView.loadRemoteUrl(urlToGo)
	}
	
	private func isShowWait() -> Bool {
		return !vwWaitScreen.isHidden
	}
	
	func showWaitMark(_ show: Bool) {
		print("showWaitMark:\(show)")
		
		let hide = !show
		if vwWaitScreen.isHidden != hide {
			vwWaitScreen.isHidden = hide
		}
		
		if show {
			// set auto-hide timeout
			let now = DispatchTime.now()
			m_timeHideQueued = now
			DispatchQueue.main.asyncAfter(deadline: now + .seconds(5)) {
				guard self.m_timeHideQueued == now else {
					return
				}
				
				self.showWaitMark(false)
			}
		}
	}
	
	func onWebPageFinished(_ url: String) {
		print("onWebPageFinished: \(url)")
		
		if m_isInitialWaitDone == false && isShowWait() {
			m_nPageFinishCount += 1
			if m_nPageFinishCount >= 2 {
				print("InitialWait done")
				m_isInitialWaitDone = true
				showWaitMark(false)
				
				m_webView.setAutoWait(true)
			}
		}
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
			if m_isInitialWaitDone == false {
				m_nPageFinishCount -= 1
			}
			
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
		} else {
			print("unhandled post action: \(action)")
		}
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
		m_downloadingHud = MBProgressHUD.showAdded(to: view, animated: true)
		m_downloadingHud?.backgroundView.style = .solidColor
		m_downloadingHud?.backgroundView.color = UIColor(white:0, alpha:0.4)
		m_downloadingHud?.mode = MBProgressHUDMode.determinateHorizontalBar
		m_downloadingHud?.label.text = Util.getLocalizedString("downloading")
		m_downloadingHud?.detailsLabel.text = m_curDownloadFilename
	}
	
	private func hideDownloadingHud() {
		m_downloadingHud?.hide(animated: true)
		m_downloadingHud = nil
	}
	
	func onApi(_ jobId: Int, failedWithErrorMessage errMsg: String) -> Bool {
		switch (jobId)
		{
		case ApiMan.JOBID_DOWNLOAD_FILE:
			hideDownloadingHud()
			Util.showSimpleAlert("다운로드에 실패하였습니다.")
			return true
			
		default:
			break
		}
		
		return false
	}
	
	func onApi(_ jobId: Int, finishedWithResult _param: Any?) {
		print("TODO: api \(jobId) succeeded")
		
		switch (jobId)
		{
		case ApiMan.JOBID_DOWNLOAD_FILE:
			hideDownloadingHud()
			let downInfo = _param as! HttpFileDownloadResult
			openDownloadedFile(downInfo.localFileUrl!)
			break
		
		default:
			return
		}
	}
	
	func onApi(_ jobId: Int, downloadedSoFar current: Int64, ofTotal total: Int64) {
		let prgs = Float(current) / Float(total)
		m_downloadingHud?.progress = prgs
	}
	
	private func openDownloadedFile(_ fileUrl: URL) {
		print("openDownloadedFile: \(fileUrl)")
		let m_docIC: UIDocumentInteractionController = UIDocumentInteractionController.init(url: fileUrl)
        m_docIC.delegate = self
        m_docIC.name = m_curDownloadFilename
        m_curDownloadFilename = nil
        m_curDownloadedFileUrl = fileUrl

        m_docIC.presentPreview(animated: true)
	}
	
	func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
		return self
	}
	
	func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
		if let url = m_curDownloadedFileUrl {
			print("delete downloaded file: \(url)")
			try? FileManager.default.removeItem(at: url)
			m_curDownloadedFileUrl = nil
		}
 	}
	
 	func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
		print("didEndSendingToApplication")
	}
}

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
	func onWebPageFinished(_ url: String)
	func handleAction(_ action: String, withJSON json: [String:Any]?)
}

class UfoWebView : WKWebView, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate
{
	private static let HEADERKEY_CATAN_AGENT = "catan-agent"
	private static let HEADERKEY_CATAN_VERSION = "catan-version"

	public var ufoDelegate: UfoWebDelegate?
	
	private var m_lastOnlineUrl: String? = nil
	private var m_wasOffline: Bool = false
	
	private var m_isAutomaticShowHideWait: Bool = false
	
	public init() {
		let wkconf = WKWebViewConfiguration()
		super.init(frame:CGRect.zero, configuration:wkconf)
		wkconf.userContentController.add(self, name:"ufop")
		self.navigationDelegate = self
		self.uiDelegate = self
		self.scrollView.bounces = false
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func showOfflinePage() {
		loadLocalHtml("offline")
		m_wasOffline = true
	}
	
	func onNetworkReady() {
		if m_wasOffline, let lastOnlineUrl = m_lastOnlineUrl {
			m_wasOffline = false
			print("Recover online: \(lastOnlineUrl)")
			loadRemoteUrl(lastOnlineUrl)
		}
	}
	
	func loadLocalHtml(_ filename: String) {
		let path = Bundle.main.path(forResource: filename, ofType: "html")
		let fileUrl = URL.init(fileURLWithPath: path!)
		super.loadFileURL(fileUrl, allowingReadAccessTo: Bundle.main.bundleURL)
	}

	func loadRemoteUrl(_ url: String) {
		print("loadRemoteUrl: \(url)")
		let req = URLRequest(url: URL(string: url)!)
		super.load(req)
	}
	
	private func _post(_ action: String, json jsonString: String?) {
		if ufoDelegate == nil {
			return
		}
		
		var json: [String: Any]? = nil
		if !Util.isNilOrEmpty(jsonString) {
			do {
				let data = jsonString!.data(using: .utf8)
				let jsonRaw = try JSONSerialization.jsonObject(with:data!, options: .allowFragments)
				json = jsonRaw as? [String: Any]
			} catch {
				print("post: JSON parse failed: \(jsonString!)")
			}
		}
		
		ufoDelegate?.handleAction(action, withJSON:json)
	}


	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if message.name == "ufop" {
			let body = message.body as? NSDictionary
			let method = body?["method"] as? String
			let arg0 = body?["arg0"] as? String
			let arg1 = body?["arg1"] as? String
		
			if "showWait" == method {
				showWait()
			} else if "hideWait" == method {
				hideWait()
			} else if "setAutoWait" == method {
				setAutoWait(Util.isNilOrEmpty(arg0) ? false : true)
			} else if "post" == method {
				_post(arg0 ?? "", json:arg1)
			} else {
				print("Unknown ufo method: \(method ?? "nil")")
			}
		}
	}
	
	func setAutoWait(_ isAuto: Bool) {
		print("setAutoWait(\(isAuto))")
		m_isAutomaticShowHideWait = isAuto
	}
	
	func showWait() {
		ViewController.instance.showWaitMark(true)
	}
	func hideWait() {
		ViewController.instance.showWaitMark(false)
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		let url = webView.url?.absoluteString ?? "nil"
		print("didFinishNavigation: \(url)")
		ufoDelegate?.onWebPageFinished(url)
		
		if m_isAutomaticShowHideWait {
			hideWait()
		}
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		let nserr = error as NSError
		
		let url = webView.url?.absoluteString ?? "nil"
		print("didFailProvisionalNavigation: \(url) \(nserr.code)")

		switch (nserr.code)
		{
		case 102,// frame load interrupted
			NSURLErrorCancelled:
			break
			
		case NSURLErrorUnsupportedURL:
			return
		
		case NSURLErrorTimedOut,
			NSURLErrorCannotFindHost,
			NSURLErrorCannotConnectToHost,
			NSURLErrorNetworkConnectionLost,
			NSURLErrorDNSLookupFailed,
			NSURLErrorResourceUnavailable,
			NSURLErrorNotConnectedToInternet,
			NSURLErrorRedirectToNonExistentLocation:
			showOfflinePage()
			break
			
		default:
			break
		}
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
		
        if !process(webView, request: navigationAction.request as NSURLRequest, hasTargetFrame: false, onLoadInCurrentWebView: { (webView, request) in
            webView.load(request as URLRequest)
            return true
        }, onLoadInExternal: { (request) in
            guard let reqUrl = request.url else { return false }
            UIApplication.shared.openURL(reqUrl)
            return true
        }) {
            // process 실패
            print("Failed to open url")
        }
        
        return nil
	}
	
	func webViewDidClose(_ webView: WKWebView) {
		// window.close() 이벤트를 받을 수가 없음 ㅠ
		print("TODO: webViewDidClose \(webView)")
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
		guard let reqUrl = request.url else {
			// failed to get url
			decisionHandler(.cancel)
			return
		}
        let reqUrlString = reqUrl.absoluteString
		
		print("willNavigate \(request.httpMethod ?? "?"): \(reqUrl)")
		
		if reqUrlString.hasPrefix("ufo:") {
			decisionHandler(.cancel)
			let index = reqUrlString.index(reqUrlString.startIndex, offsetBy: 4)
			handleUfoLink(String(reqUrlString.suffix(from: index)))
			return
		}
		
		if reqUrlString.hasPrefix("http") {
			if let targetFrm = navigationAction.targetFrame {
				if targetFrm.isMainFrame == false {
					// maybe ajax call
					decisionHandler(.allow)
					return
				}
			}
			
			if request.httpMethod != "GET" {
				if m_isAutomaticShowHideWait {
					showWait()
				}
				
				decisionHandler(.allow)
				return
			}
			
			if request.value(forHTTPHeaderField: UfoWebView.HEADERKEY_CATAN_AGENT) != nil {
				decisionHandler(.allow)
				return
			}
			
            // _blank처리
            //
            // webView(_ webView, createWebViewWith: WKWebViewConfiguration, for: WKNavigationAction, windowFeatures: WKWindowFeatures) 보다 먼저 처리는 듯 보임
            //
            // WKNavigationAction#targetFrame
            // The target frame, or nil if this is a new window navigation.
            //
            // https://developer.apple.com/documentation/webkit/wknavigationaction/1401918-targetframe
            if process(webView, request: request as NSURLRequest, hasTargetFrame: (navigationAction.targetFrame == nil), onLoadInCurrentWebView: { (webView, request) in
                decisionHandler(.allow)
                return true
            }, onLoadInExternal: { (request) in
                guard let reqUrl = request.url else { return false }
                UIApplication.shared.openURL(reqUrl)
                decisionHandler(.cancel)
                return true
            }) {
                // process 성공
                return
            }
		}
		
		// unknown scheme
		decisionHandler(.allow)	// or .cancel?
	}

/*
	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if let mimeType = navigationResponse.response.mimeType {
			print("Response MIME type: \(mimeType)")
		} else {
			// response has no MIME type, do some special handling
			print("Response MIME type unknown")
		}
		decisionHandler(.allow)
	}
*/
	
    fileprivate func process(_ webView: WKWebView, request: NSURLRequest, hasTargetFrame: Bool, onLoadInCurrentWebView: ((WKWebView, NSURLRequest) -> Bool), onLoadInExternal: ((NSURLRequest) -> Bool)) -> Bool {
        guard let reqUrl = request.url else {
            return false
        }
        
        guard let mutableRequest = (request).mutableCopy() as? NSMutableURLRequest else {
            return false
        }
        
        mutableRequest.setValue("catan-spark-android", forHTTPHeaderField: UfoWebView.HEADERKEY_CATAN_AGENT)
        mutableRequest.setValue("1.0.0", forHTTPHeaderField: UfoWebView.HEADERKEY_CATAN_VERSION)
        
        if hasTargetFrame == true || reqUrl.absoluteString =~ Config.apiBaseUrlRegex.r {
            m_lastOnlineUrl = reqUrl.absoluteString
            
            if m_isAutomaticShowHideWait {
                showWait()
            }
            
            // 앱 내의 웹뷰에서 계속 진행합니다.
            // ex) webView.load(mutableRequest as URLRequest)
            return onLoadInCurrentWebView(webView, request)
        } else {
            // 외부 브라우저를 엽니다. (사파리)
            // ex) UIApplication.shared.openURL(reqUrl)
            return onLoadInExternal(request)
        }
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
			_post(param ?? "", json:nil)
		} else if action == "eval" {
			if param != nil {
				evalJs(param!)
			}
		} else  {
			print("Unhandled action: \(action) param=\(param ?? "nil")")
		}
	}
}

//
//  ApiMan.swift
//  PartiApp
//
//  Created by shkim on 12/25/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit

protocol ApiResultDelegate : NSObjectProtocol
{
	func onApi(_ jobId: Int, failedWithErrorMessage errMsg: String) -> Bool
	func onApi(_ jobId: Int, finishedWithResult _param: Any?)	
	func onApi(_ jobId: Int, downloadedSoFar current: Int64, ofTotal total: Int64)
}

class ApiMan : NSObject, HttpQueryDelegate
{
	private static var API_BASEURL: String = "https://parti.xyz/"
	
	static let JOBID_REGISTER_TOKEN = 1
	static let JOBID_DELETE_TOKEN = 2
	static let JOBID_DOWNLOAD_FILE = 3

	static func setDevMode() {
		//ApiMan.API_BASEURL = "http://192.168.0.100:8500/"
		ApiMan.API_BASEURL = "https://dev.parti.xyz/"
	}
	
	static func getBaseUrl() -> String {
		return ApiMan.API_BASEURL
	}
	
	private static func getEmptySpec(_ uri: String) -> HttpQuerySpec {
		let url = ApiMan.getBaseUrl() + uri
		let spec = HttpQuerySpec(url)
		spec.methodType = .post
		spec.resultType = .text
		
		return spec
	}
	
	private func sendRequest(_ spec: HttpQuerySpec, withJobId jobId: Int, delegate resDelegate: ApiResultDelegate?) {
		spec.userObj = resDelegate
		AppDelegate.getHttpManager().request(spec, ofJob:jobId, delegate:self)
	}

	func requestRegisterToken(_ resDelegate: ApiResultDelegate?, authkey: String, pushToken: String?, appId: String) {
		let spec = ApiMan.getEmptySpec("api/v1/device_tokens")
		spec.addHeader("Bearer " + authkey, forKey: "Authorization")
		spec.addParam(pushToken ?? "", forKey: "registration_id")
		spec.addParam(appId, forKey: "application_id")
		
		print("registerToken(\(authkey),\(pushToken ?? "NoPushToken"),\(appId))")
		sendRequest(spec, withJobId: ApiMan.JOBID_REGISTER_TOKEN, delegate: resDelegate)
	}

	func requestDeleteToken(_ resDelegate: ApiResultDelegate?, authkey: String, pushToken: String?) {
		let spec = ApiMan.getEmptySpec("api/v1/device_tokens")
		spec.methodType = .delete
		spec.addHeader("Bearer " + authkey, forKey: "Authorization")
		spec.addParam(pushToken ?? "", forKey: "registration_id")
		
		print("deleteToken(\(authkey),\(pushToken ?? "NoPushToken"))")
		sendRequest(spec, withJobId: ApiMan.JOBID_DELETE_TOKEN, delegate: resDelegate)
	}
	
	func requestFileDownload(_ resDelegate: ApiResultDelegate?, authkey: String?, postId: Int, fileId: Int, atLocalPath localPath: String) {
		let spec = ApiMan.getEmptySpec("api/v1/posts/\(postId)/download_file/\(fileId)")
		spec.methodType = .get
		spec.resultType = .fileWithProgress
		
		if let _authkey = authkey {
			spec.addHeader("Bearer " + _authkey, forKey: "Authorization")
		}
		
		print("fileDownload(\(authkey ?? "noAuth"),\(spec.address))")
		spec.userObj = resDelegate
		AppDelegate.getHttpManager().download(spec, ofJob:ApiMan.JOBID_DOWNLOAD_FILE, atPath:localPath, delegate:self)
	}
	
	private func notifyFailure(ofJob jobId: Int, withMessage errMsg: String, delegate _resDelegate: ApiResultDelegate?) {
		guard let resDelegate = _resDelegate else {
			return
		}

		let handled: Bool = resDelegate.onApi(jobId, failedWithErrorMessage:errMsg)
		if !handled {
			let alertController = UIAlertController(title:nil, message:errMsg, preferredStyle:.alert)
			alertController.addAction(UIAlertAction(title:Util.getLocalizedString("ok"),
				style:.cancel, handler:nil))
			ViewController.instance.present(alertController, animated:true, completion:nil)
		}
	}
	
	func httpQuery(_ spec: HttpQuerySpec, ofJob jobId: Int, didFinish success: Bool, withResult result: Any?) {
		let resDelegate = spec.userObj as? ApiResultDelegate
		if !success {
			let errMsg: String
			if result == nil {
				errMsg = "Unknown error"
			} else {
				errMsg = String(describing: result!)
			}
			
			notifyFailure(ofJob: jobId, withMessage: errMsg, delegate: resDelegate)
			return
		}
		
		if resDelegate == nil {
			// success can be ignored without callback
			print("job(\(jobId) succeeded but delegate is nil.")
			return
		}
		
		
		var downloadResult: HttpFileDownloadResult?
		var textResult: String?
		//var jsonResult: [String:Any]?
		
		if spec.resultType == .json {
			//jsonResult = result as? [String:Any]
		} else  if spec.resultType == .text {
			textResult = result as? String
		} else  if spec.resultType == .fileWithProgress {
			downloadResult = result as? HttpFileDownloadResult
		} else {
			let errMsg = "Job#\(jobId): unknown resType \(spec.resultType)"
			notifyFailure(ofJob: jobId, withMessage: errMsg, delegate: resDelegate)
			return
		}
		
		var param: Any?
		switch (jobId) {
			case ApiMan.JOBID_REGISTER_TOKEN:
				param = textResult
				break
			case ApiMan.JOBID_DELETE_TOKEN:
				param = textResult
				break
			case ApiMan.JOBID_DOWNLOAD_FILE:
				param = downloadResult
				break

			default:
				let errMsg = "Unhandled ApiJob#\(jobId)"
				notifyFailure(ofJob: jobId, withMessage: errMsg, delegate: resDelegate)
				return
		}
		
		resDelegate!.onApi(jobId, finishedWithResult: param)
	}
	
	func httpQuery(_ spec: HttpQuerySpec, ofJob jobId: Int, progressSoFar current: Int64, progressTotal total: Int64) {
		let resDelegate = spec.userObj as! ApiResultDelegate
		resDelegate.onApi(jobId, downloadedSoFar:current, ofTotal:total)
	}
	
}

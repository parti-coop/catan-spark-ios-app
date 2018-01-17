//
//  HttpMan.swift
//  PartiApp
//
//  Created by shkim on 12/25/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit
import Foundation

class HttpManError : LocalizedError, CustomStringConvertible {
	var errorDescription: String? {
		return errMsg
	}
	
	var description : String {
		return errMsg
	}

	private var errMsg : String
	
	init(_ description: String)
	{
		errMsg = description
	}
}

public enum HttpQueryResultType : Int {
	case ignore
	case text
	case json
	case binary
	case binaryWithProgress
	case fileWithProgress
}

public enum HttpQueryMethodType : Int {
	case get
	case post
	case put
	case delete
}

class HttpQuerySpec : NSObject
{
	var port: Int = 0
	var isSecure: Bool = false
	var isNotifyOnNetThread: Bool = false
	var isIgnoreCache: Bool = false
	var methodType: HttpQueryMethodType = .get
	var resultType: HttpQueryResultType = .ignore
	
	var address: String
	var path: String?
	
	var userObj: Any?
	var postBody: Any?
	
	init(_ url: String) {
		guard let rng = url.range(of: "://") else {
			print("HttpQuerySpec: invalid http url: \(url)")
			address = ""
			return
			//throw NSError(domain: "Invalid HttpQuerySpec URL", code:1)
		}
		
		isSecure = url[url.index(rng.lowerBound, offsetBy:-1)] == "s"
	
		var strCore = url[rng.upperBound...]
		let rngUri = strCore.range(of: "/")
		if rngUri == nil {
			// has no uri
			path = nil;
		} else {
			path = String(strCore[rngUri!.lowerBound...])
			strCore = strCore[...url.index(rngUri!.lowerBound, offsetBy:-1)]
		}
		
		let rngColon = strCore.range(of: ":")
		if rngColon == nil {
			// no port specified, use default http port (80 or 443)
			port = 0
		} else {
			let strPort = strCore[url.index(rngColon!.lowerBound, offsetBy:1)...]
			port = Int(strPort) ?? 0
			strCore = strCore[...url.index(rngColon!.lowerBound, offsetBy:-1)]
		}
		
		address = String(strCore)
	}
	
	private var m_arrParams: [String]?
	
	func addParam(_ value: String, forKey key:String) {
		if m_arrParams == nil {
			m_arrParams = [String]()
		}
		
		guard let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
			print("urlEncode(\(value)) failed")
			return
		}
		
		let kv = key + "=" + escapedValue
		m_arrParams!.append(kv)
	}
	
	func addParam(value: Int, forKey key:String) {
		addParam(String(value), forKey:key)
	}
	
	func addParam(value: Bool, forKey key:String) {
		addParam(String(value), forKey:key)
	}
	
	func addParam(value: Float, forKey key:String) {
		addParam(String(value), forKey:key)
	}
	
	func getParams() -> [String]? {
		return m_arrParams
	}

	func getParam(forKey key:String) -> String? {
		if m_arrParams == nil {
			return nil
		}
		
		for kv in m_arrParams! {
			let arr = kv.components(separatedBy: "=")
			if arr[0] == key {
				return arr[1]
			}
		}
		
		return nil
	}

	private var m_dicHeaders: [String:String]?
	
	func addHeader(_ value: String, forKey key:String) {
		if m_dicHeaders == nil {
			m_dicHeaders = [String:String]()
		}
		
		m_dicHeaders![key] = value
	}
	
	func getHeaders() -> [String:String]? {
		return m_dicHeaders
	}
	
	private var m_dicUserVars: [String:String]?
	
	func addUserVar(value: String, forKey key:String) {
		if m_dicUserVars == nil {
			m_dicUserVars = [String:String]()
		}
		
		m_dicUserVars![key] = value
	}
	
	func getUserVar(forKey key: String) -> String? {
		return m_dicUserVars?[key]
	}
}

class HttpFileDownloadResult : NSObject
{
	var length: Int64 = 0
	var localFileUrl: URL?
	var error: Error?
	
	let targetPath: String
	public init(_ destPath: String) {
		targetPath = destPath
	}
}

class HttpMultipartFormData : NSObject
{
	public private(set) var boundary: String
	
	override init() {
		boundary = "TODO"
	}
	
	func addParam(_ value: String, forKey key:String) {
	}

	func addFile(_ value: NSData, named filename: String, ofType mimeType: NSString, forKey key: String) {
	
	}
	
	func finish() {
	
	}
	
	func result() -> Data {
		return Data()
	}
}

protocol HttpQueryDelegate : NSObjectProtocol
{
	func httpQuery(_ spec:HttpQuerySpec, ofJob jobId:Int, didFinish success:Bool, withResult result:Any?)
	func httpQuery(_ spec:HttpQuerySpec, ofJob jobId:Int, progressSoFar current:Int64, progressTotal total:Int64)
}

fileprivate class HttpQueryJob : NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate
{
	static let kContentType = "Content-Type"
	static let kContentLength = "Content-Length"

	var m_sessionTask: URLSessionTask!
	var m_receivedData: Data?

	var m_statusCode: Int = 0
	var m_queryProgress: Int = 0
	var m_expectedContentLength: Int64 = 0
	var m_downSoFar: Int64 = 0
	
	//var m_outFileStream: OutputStream?
	var m_downJob: HttpFileDownloadResult?
	
	var m_jobId: Int
	var m_spec: HttpQuerySpec
	var m_delegate: HttpQueryDelegate?

	init?(_ spec:HttpQuerySpec, ofJob jobId:Int, downloadPath downpath:String?, delegate theDelegate:HttpQueryDelegate?) {
		m_jobId = jobId;
		m_spec = spec;
		m_delegate = theDelegate;
		
		super.init()

		let formDataStr: String
		if let params = spec.getParams() {
			formDataStr = params.joined(separator: "&")
		} else {
			formDataStr = ""
		}
		
		let strPort = spec.port == 0 ? "" : ":\(spec.port)"
		var strUrl = "http" + (spec.isSecure ? "s" : "") + "://" +
			spec.address + strPort + (spec.path ?? "")
		
		if !formDataStr.isEmpty && spec.methodType == .get {
			strUrl += "?" + formDataStr
		}
		
		var request: URLRequest
		if spec.isIgnoreCache {
			request = URLRequest(url: URL(string: strUrl)!,
				cachePolicy: .reloadIgnoringLocalCacheData,
				timeoutInterval: 10.0)

		} else {
			request = URLRequest(url: URL(string: strUrl)!)
		}
		
		var methodVerb: String
		switch (spec.methodType)
		{
		case .get:
			methodVerb = "GET"

		case .post:
			methodVerb = "POST"
			
		case .put:
			methodVerb = "PUT"
			
		case .delete:
			methodVerb = "DELETE"
		}
		
		request.httpMethod = methodVerb
		
		var httpBody: Data?
		if (spec.methodType != .get && !formDataStr.isEmpty) {
			request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:HttpQueryJob.kContentType)
			httpBody = formDataStr.data(using: .utf8)
		} else if spec.postBody is HttpMultipartFormData {
			let mfd = spec.postBody as! HttpMultipartFormData
			let ctype = "multipart/form-data; boundary=\(mfd.boundary)"
			request.setValue(ctype, forHTTPHeaderField:HttpQueryJob.kContentType)
			httpBody = mfd.result()
		} else if spec.postBody is Dictionary<String,String> || spec.postBody is Array<Any> {
			/*
			request.setValue("application/json", forHTTPHeaderField:HttpQueryJob.kContentType)
			httpBody = JSONSerialization.data(withJSONObject:spec.postBody, options:0)
			if (!error)
			{
				// TODO: error
				ASSERT(!"JSON creation failed.");
			}
			*/
		} else {
			httpBody = nil;
		}
		
		let moreHeaders = spec.getHeaders()
		if moreHeaders != nil {
			for (k,v) in moreHeaders! {
				request.setValue(v, forHTTPHeaderField:k)
			}
		}
		
		if httpBody != nil {
			request.setValue(String(httpBody!.count), forHTTPHeaderField:HttpQueryJob.kContentLength)
			request.httpBody = httpBody
		}


		if downpath != nil {
			assert(spec.resultType == .fileWithProgress)
			m_downJob = HttpFileDownloadResult(downpath!)
		} else {
			assert(m_downJob == nil)
		}

		let defaultConfigObject = URLSessionConfiguration.default
		let defaultSession = URLSession(configuration:defaultConfigObject, delegate:self, delegateQueue:OperationQueue.main)
		
		if (downpath != nil) {
			m_sessionTask = defaultSession.downloadTask(with: request)
		} else {
			m_sessionTask = defaultSession.dataTask(with: request)
		}
		
		m_sessionTask.resume()
	}
	
	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		print("didBecomeInvalidWithError")
	}

	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
	
	}
	
	func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
		print("urlSessionDidFinishEvents_forBackgroundURLSession")
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Swift.Void) {
		print("willPerformHTTPRedirection");
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void)
	{
#if DEBUG//_HTTPMAN_ENABLE_FAKE_SSL
		completionHandler(.useCredential, URLCredential(trust:challenge.protectionSpace.serverTrust!))
#endif
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Swift.Void) {
		print("needNewBodyStream")
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		//NSTRACE(@"didSendBodyData:%lld totalBytesSent:%lld, expectedToSend:%lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
	}

	@objc private func handleJsonComplete(_ json:Any?) {
		if json == nil {
			let err = HttpManError("JSON parsing failed")
			m_delegate?.httpQuery(m_spec, ofJob:m_jobId, didFinish:false, withResult:err)
		} else {
			m_delegate?.httpQuery(m_spec, ofJob:m_jobId, didFinish:true, withResult:json)
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
	
		AppDelegate.getHttpManager().decreaseNetworkJob(self)

		if error == nil {
			if m_spec.resultType != .ignore {
				if m_spec.resultType == .json {
					let json = try? JSONSerialization.jsonObject(with:m_receivedData!, options: .allowFragments)
					if m_spec.isNotifyOnNetThread {
						handleJsonComplete(json)
					} else {
						self.performSelector(onMainThread:#selector(HttpQueryJob.handleJsonComplete(_:)), with:json, waitUntilDone:false)
					}
				} else {
					notifyResult()
				}
			}
			
			return
		}
	
		//print("didCompleteWithError: \(error!.localizedDescription())")
		print("didCompleteWithError: TODO")

		if m_statusCode == 0 {
			//m_statusCode = error!.rawValue
		}
		
		m_delegate?.httpQuery(m_spec, ofJob:m_jobId, didFinish:false, withResult:error)
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
		guard let httpResponse = response as? HTTPURLResponse else {
			return
		}
		
		m_statusCode = httpResponse.statusCode

		m_expectedContentLength = response.expectedContentLength
		m_downSoFar = 0
		
		m_receivedData = Data()
		m_receivedData?.count = 0

		completionHandler(.allow)
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		print("dataTask didBecomeDownloadTask")
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		print("dataTask didBecomeStreamTask")
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
	{
		if m_spec.resultType == .fileWithProgress {
			assert(false)
/*
			assert(m_outFileStream != nil)
			data.withUnsafeBytes{(u8ptr: UnsafePointer<UInt8>) in
				//let rawPtr = UnsafeRawPointer(u8ptr)
				
				let written = m_outFileStream!.write(u8ptr, maxLength:data.count)
				if written != data.count || m_outFileStream!.hasSpaceAvailable == false {
					//[m_connection cancel];
					m_sessionTask.cancel()
					m_statusCode = -9;
					//[self connection:m_connection didFailWithError:nil];
					return
				}
				
				m_downSoFar += Int64(data.count)
				m_delegate?.httpQuery(m_spec, ofJob:m_jobId, progressSoFar:m_downSoFar, progressTotal:m_expectedContentLength)
			}
*/
		}
		else
		{
			m_receivedData?.append(data)
		
			if m_spec.resultType == .binaryWithProgress {
				m_downSoFar += Int64(data.count)
				m_delegate?.httpQuery(m_spec, ofJob:m_jobId, progressSoFar:m_downSoFar, progressTotal:m_expectedContentLength)
			}
		}
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Swift.Void) {
		completionHandler(m_spec.isIgnoreCache ? nil : proposedResponse);
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
			// could not get http response
			m_statusCode = -1
			return
		}
		
		m_statusCode = httpResponse.statusCode
		if m_statusCode < 200 || m_statusCode >= 300 {
			print("downloadTask didFinishDownloadingTo: failed \(m_statusCode)")
			return
		}
		
		/*let keyValues = httpResponse.allHeaderFields.map {
			(String(describing: $0.key).lowercased(), String(describing: $0.value))
		}
		for (k,v) in httpResponse.allHeaderFields {
			print("httpResponse.allHeaderFields[\(k),\(v)]")
		}
		
		var filename: String?
		if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
			let re = try! NSRegularExpression(pattern: "filename=\"(.+?)\"", options: .caseInsensitive)
			let matches = re.matches(in: contentDisposition, range: NSMakeRange(0, contentDisposition.utf16.count))
			if matches.count > 0 {
				let nameRange = matches[0].range(at: 1)
    			let start = String.UTF16Index(encodedOffset: nameRange.location)
    			let end = String.UTF16Index(encodedOffset: nameRange.location + nameRange.length)

    			filename = String(contentDisposition.utf16[start..<end])
			}
		}*/
		
		assert(m_downJob != nil)
		do {
			assert(m_downJob!.localFileUrl == nil)
			let destUrl = URL.init(fileURLWithPath: m_downJob!.targetPath)
			try FileManager.default.moveItem(at:location, to:destUrl)
			
			m_downJob!.length = m_expectedContentLength
			m_downJob!.localFileUrl = destUrl
		} catch {
			m_downJob!.error = error
			m_downJob!.localFileUrl = nil
		}
		
		print("downloadTask didFinishDownloadingTo")
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		//print("downloadTask didWriteData(written=\(bytesWritten), totalWritten=\(totalBytesWritten), expected=\(totalBytesExpectedToWrite))")
		m_downSoFar = totalBytesWritten
		m_expectedContentLength = totalBytesExpectedToWrite
		m_delegate?.httpQuery(m_spec, ofJob:m_jobId, progressSoFar:m_downSoFar, progressTotal:m_expectedContentLength)
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
		print("downloadTask didResumeAtOffset")
	}
	
	
	fileprivate func cancel() {
		m_sessionTask.cancel()
		m_statusCode = -1
	}

	func notifyResult() {
		var result: Any?
	
		switch(m_spec.resultType)
		{
		case .text:
			result = String(data:m_receivedData!, encoding:.utf8) as Any
			break
			
		case .binary, .binaryWithProgress:
			result = m_receivedData!	// TODO
			break
	
		case .fileWithProgress:
			//m_downJob!.length = m_downSoFar
			if m_downJob!.localFileUrl == nil {
				if m_downJob!.error == nil {
					m_downJob!.error = HttpManError("Download failed \(m_statusCode)")
				}
				
				m_delegate?.httpQuery(m_spec, ofJob:m_jobId, didFinish:false, withResult:m_downJob!.error)
				return
			}
			result = m_downJob
			break
	
		default:
			break
		}
	
		m_delegate?.httpQuery(m_spec, ofJob:m_jobId, didFinish:true, withResult:result)
	}
}

class HttpMan : NSObject
{
	private var m_jobs: Set<HttpQueryJob>
	private var m_dicJobs: [Int:HttpQueryJob]
	
	override init() {
		m_jobs = Set<HttpQueryJob>()
		m_dicJobs = [Int:HttpQueryJob]()
	}
	
	fileprivate func decreaseNetworkJob(_ job: HttpQueryJob) {
		m_dicJobs.removeValue(forKey: job.m_jobId)
		m_jobs.remove(job)
	
		if m_jobs.count <= 0 {
			UIApplication.shared.isNetworkActivityIndicatorVisible = false
		}
	}
	
	func cancel(_ jobId:Int) {
		let job = m_dicJobs[jobId]
		if job != nil {
			print("Cancel httpQueryJob id=\(jobId)")
			job!.cancel()
		}
	}
	
	func getQueuedJobCount() -> Int {
		return m_jobs.count
	}
	
	private func _addJob(_ job: HttpQueryJob?) {
		if job == nil {
			return
		}
		
		m_jobs.insert(job!)
		m_dicJobs[job!.m_jobId] = job
	
		UIApplication.shared.isNetworkActivityIndicatorVisible = true
	}
	
	func request(_ spec:HttpQuerySpec, ofJob jobId:Int, delegate theDelegate:HttpQueryDelegate) {
		_addJob(HttpQueryJob(spec, ofJob:jobId, downloadPath:nil, delegate:theDelegate))
	}

	func download(_ spec:HttpQuerySpec, ofJob jobId:Int, atPath path:String, delegate theDelegate:HttpQueryDelegate) {
		assert(spec.resultType == .fileWithProgress)
		_addJob(HttpQueryJob(spec, ofJob:jobId, downloadPath:path, delegate:theDelegate))
	}
}

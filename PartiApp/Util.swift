//
//  Util.swift
//  PartiApp
//
//  Created by shkim on 12/24/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit
import Foundation
import SafariServices

class Util
{
	static func isNilOrEmpty(_ optStr: String?) -> Bool {
		if let str = optStr {
			//return str.trimmingCharacters(in: .whitespaces).isEmpty
			return str.isEmpty
		} else {
			return true
		}
	}
	
	static func getLocalizedString(_ key: String) -> String {
		return Bundle.main.localizedString(forKey:key, value:"", table:nil)
	}
	
	static func showSimpleAlert(_ message: String) {
		let alertController = UIAlertController(title: nil, message:message, preferredStyle:.alert)
		alertController.addAction(UIAlertAction(title: getLocalizedString("ok"), style:.`default`))
		ViewController.instance.present(alertController, animated:true, completion:nil)
	}

	static func getMD5Hash(_ string: String) -> String {
		let context = UnsafeMutablePointer<CC_MD5_CTX>.allocate(capacity: 1)
		var digest = Array<UInt8>(repeating:0, count:Int(CC_MD5_DIGEST_LENGTH))
		CC_MD5_Init(context)
		CC_MD5_Update(context, string, CC_LONG(string.lengthOfBytes(using: String.Encoding.utf8)))
		CC_MD5_Final(&digest, context)
		context.deallocate(capacity: 1)

		// make hex string
		return digest.map { String(format: "%02.2hhx", $0) }.joined()
	}
	
	static func getPrettyJsonString(_ src: Dictionary<AnyHashable, Any>) -> String? {
		if let jsonData = try? JSONSerialization.data(withJSONObject: src, options: [.prettyPrinted]),
			let jsonString = String(data: jsonData, encoding: .utf8) {
			return jsonString
		}
		return nil
	}
}


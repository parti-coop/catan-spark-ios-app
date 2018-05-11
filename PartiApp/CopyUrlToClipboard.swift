//
//  CopyUrlToClipboard.swift
//  PartiApp
//
//  Copyright © 2018년 Slowalk. All rights reserved.
//
import UIKit

class CopyUrlToClipboardActivity: UIActivity {
  private var url = NSURL()
  
  override class var activityCategory: UIActivityCategory {
    return .action
  }
  
  override var activityType: UIActivityType? {
    guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
    return UIActivityType(rawValue: bundleId + "\(self.classForCoder)")
  }
  
  override var activityTitle: String? {
    return Util.getLocalizedString("copy_link")
  }
  
  override var activityImage: UIImage? {
    return UIImage(named: "icon-copy-link")
  }
  
  override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
    for activityItem in activityItems {
      if let _ = activityItem as? NSURL {
        return true
      }
    }
    
    return false
  }
  
  override func prepare(withActivityItems activityItems: [Any]) {
    for activityItem in activityItems {
      if let url = activityItem as? NSURL {
        self.url = url
      }
    }
  }
  
  override func perform() {
    UIPasteboard.general.string = url.absoluteString
    activityDidFinish(true)
  }
}

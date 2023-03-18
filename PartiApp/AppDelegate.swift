//
//  AppDelegate.swift
//  PartiApp
//
//  Created by shkim on 12/22/17.
//  Copyright © 2017 Slowalk. All rights reserved.
//

import UIKit
import UserNotifications
import AVFoundation

import Firebase
import FirebaseMessaging

import GoogleSignIn
import FBSDKCoreKit

import Firebase
import FirebaseCrashlytics
import SwiftyBeaver
let log = SwiftyBeaver.self

typealias Config = Natrium.Config

#if DEBUG
import SimulatorStatusMagic
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate
{
  var window: UIWindow?

  private var httpMan: HttpMan = HttpMan()
  private var apiMan: ApiMan = ApiMan()

  var googleSignInSuccessCallback: (() -> ())?
  var googleSignInFailureCallback: ((_ error: NSError) -> ())?

  static func getHttpManager() -> HttpMan {
    return (UIApplication.shared.delegate as! AppDelegate).httpMan
  }

  static func getApiManager() -> ApiMan {
    return (UIApplication.shared.delegate as! AppDelegate).apiMan
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()

    Messaging.messaging().delegate = self

    // Register for remote notifications. This shows a permission dialog on first run, to
    // show the dialog at a more appropriate time move this registration accordingly.
    if #available(iOS 10.0, *) {
      // For iOS 10 display notification (sent via APNS)
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: authOptions,
        completionHandler: {_, _ in })
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    // Override point for customization after application launch.
    setupLog()

    // Initialize Google sign-in
    GIDSignIn.sharedInstance().clientID = Config.authGoogleClientId
    GIDSignIn.sharedInstance().serverClientID = Config.authGoogleServerClientId
    GIDSignIn.sharedInstance().delegate = self
    
    // Initialize Facebook sign-in
    ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("CATAN_SCREENSNAPSHOTS") {
      SDStatusBarManager.sharedInstance().enableOverrides()
    }
    #endif

    return true
  }

  fileprivate func setupLog() {
    let console = ConsoleDestination()  // log to Xcode Console
    console.format = "$DHH:mm:ss$d $N.$F:$l $T $L: $M"
    log.addDestination(console)
  }

  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    // If you are receiving a notification message while your app is in the background,
    // this callback will not be fired till the user taps on the notification launching the application.
    handlePushData(userInfo)
  }

/*  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // If you are receiving a notification message while your app is in the background,
    // this callback will not be fired till the user taps on the notification launching the application.
    // TODO: Handle data of notification
    // With swizzling disabled you must let Messaging know about the message, for Analytics
    // Messaging.messaging().appDidReceiveMessage(userInfo)
    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
      log.debug("Message ID: \(messageID)")
    }

    // Print full message.
    handlePushData(userInfo)

    completionHandler(UIBackgroundFetchResult.newData)
  }*/

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    log.debug("Unable to register for remote notifications: \(error.localizedDescription)")
  }

  // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
  // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
  // the FCM registration token.
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    log.debug("APNs token retrieved: \(deviceToken)")

    // With swizzling disabled you must set the APNs token here.
    // Messaging.messaging().apnsToken = deviceToken
  }

/*
  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
*/

  func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
    debugPrint("handleEventsForBackgroundURLSession: \(identifier)")
    completionHandler()
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance().handle(url,
                                             sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String,
                                             annotation: options[UIApplicationOpenURLOptionsKey.annotation])
  }
  
  func application(_ app: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
      let url = userActivity.webpageURL!
      ViewController.instance.handleUniversalLink(url.absoluteString)
    }
    return true
  }

  func handlePushData(_ pushInfo: [AnyHashable : Any]) {
    //log.debug("handlePushData: ", Util.getPrettyJsonString(pushInfo) ?? "nil")

    let url = pushInfo["url"]

    if let urlStr = url as? String, !Util.isNilOrEmpty(urlStr) {
      ViewController.instance.handlePushNotification(urlStr)
    }
  }

  func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
    if let error = error as NSError? {
      log.error("\(error.localizedDescription)")
      googleSignInFailureCallback?(error)
    } else {
      googleSignInSuccessCallback?()
    }
  }
}

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate
{
  // Receive displayed notifications for iOS 10 devices.
  func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

    //handlePushData(notification.request.content.userInfo)

    // Change this to your preferred presentation option
    completionHandler([.alert, .badge, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {

    handlePushData(response.notification.request.content.userInfo)

    completionHandler()
  }
}

extension AppDelegate : MessagingDelegate
{
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
    #if DEBUG
        log.debug("Firebase registration token: \(fcmToken)")
    #endif

    // TODO: If necessary send token to application server.
    // Note: This callback is fired at each app startup and whenever a new token is generated.
  }
}

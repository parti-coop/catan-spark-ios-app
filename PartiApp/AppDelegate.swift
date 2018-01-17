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

import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
	var window: UIWindow?
	
	private var httpMan: HttpMan = HttpMan()
	private var apiMan: ApiMan = ApiMan()

	static func getHttpManager() -> HttpMan {
		return (UIApplication.shared.delegate as! AppDelegate).httpMan
	}
	
	static func getApiManager() -> ApiMan {
		return (UIApplication.shared.delegate as! AppDelegate).apiMan
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		Fabric.with([Crashlytics.self])
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
		return true
	}

  	//let gcmMessageIDKey = "gcm.message_id"
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
		// If you are receiving a notification message while your app is in the background,
		// this callback will not be fired till the user taps on the notification launching the application.
		handlePushData(userInfo)
	}
	
/*	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
		fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		// If you are receiving a notification message while your app is in the background,
		// this callback will not be fired till the user taps on the notification launching the application.
		// TODO: Handle data of notification
		// With swizzling disabled you must let Messaging know about the message, for Analytics
		// Messaging.messaging().appDidReceiveMessage(userInfo)
		// Print message ID.
		if let messageID = userInfo[gcmMessageIDKey] {
			print("Message ID: \(messageID)")
		}

		// Print full message.
		handlePushData(userInfo)

		completionHandler(UIBackgroundFetchResult.newData)
	}*/

	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		print("Unable to register for remote notifications: \(error.localizedDescription)")
	}

	// This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
	// If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
	// the FCM registration token.
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		print("APNs token retrieved: \(deviceToken)")

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


	func handlePushData(_ pushInfo: [AnyHashable : Any]) {
		//print("handlePushData: ", Util.getPrettyJsonString(pushInfo) ?? "nil")
		
		let url = pushInfo["url"]
		
		if let aps = pushInfo["aps"] as? NSDictionary {
			var title: String?
			var body: String?
			
			let alert = aps["alert"]
			if let alertStr = alert as? String {
				body = alertStr
			} else if let alertDic = alert as? NSDictionary {
				body = alertDic["body"] as? String
				title = alertDic["title"] as? String
			} else {
				print("Unknown alert type: \(String(describing: alert))")
				return
			}
		
			if aps["sound"] != nil {
				AudioServicesPlaySystemSound(1315)
			}
			
			let alertController = UIAlertController(title: title, message:body, preferredStyle:.alert)
			alertController.addAction(UIAlertAction(title: Util.getLocalizedString("ok"), style:.`default`, handler: { _ in
				if let urlStr = url as? String {
					ViewController.instance.gotoUrl(urlStr)
				}
			}))
			ViewController.instance.present(alertController, animated:true, completion:nil)
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
		
		handlePushData(notification.request.content.userInfo)

		// Change this to your preferred presentation option
		completionHandler([])
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
		print("Firebase registration token: \(fcmToken)")

		// TODO: If necessary send token to application server.
		// Note: This callback is fired at each app startup and whenever a new token is generated.
	}

	// [END refresh_token]
	// [START ios_10_data_message]
	// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
	// To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
	func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
		//print("Received data message: \(remoteMessage.appData)")
		handlePushData(remoteMessage.appData)
	}
}

//
//  PartiApp_ReleaseUITests.swift
//  PartiApp ReleaseUITests
//
//  Created by Youngmin Kim on 2018. 2. 14..
//  Copyright © 2018년 Slowalk. All rights reserved.
//

import XCTest

class PartiApp_UITests: XCTestCase {
        
  override func setUp() {
    super.setUp()
  
    // Put setup code here. This method is called before the invocation of each test method in the class.
  
    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    let app = XCUIApplication()
    setupSnapshot(app)
    app.launchArguments.append("CATAN_SCREENSNAPSHOTS")
    app.launch()

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testExample() {
    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }

  func testSnapshot() {
    let app = XCUIApplication()
    allowPushNotificationsIfNeeded()
    
    waitForNewPage(app, timeout: 100)
    
    if !app.isAlreadyLogged {
      print("먼저 로그인을 해야합니다")
      return
    }

    snapshot("0_MyFeed")
    
    app.tapDrawer()
    linkFirstMatch(app, identifier: "drawer-parti-take-it-easy").tap()
    
    waitForNewPage(app, timeout: 20)
    snapshot("1_Parti")

    app.tapDrawer()
    linkFirstMatch(app, identifier: "drawer-group-organizer").tap()

    waitForNewPage(app, timeout: 20)
    snapshot("2_Group")

    linkFirstMatch(app, identifier: "post-pinned").tap()

    waitForNewPage(app, timeout: 20)
    snapshot("3_Post")
    
    app.tapBack()
    waitForNewPage(app, timeout: 20)
    
    app.tapDrawer()
    linkFirstMatch(app, identifier: "drawer-group-wouldyou").tap()
    waitForNewPage(app, timeout: 20)
    linkFirstMatch(app, identifier: "date-post-7772").tap()
    
    waitForNewPage(app, timeout: 20)
    snapshot("4_Poll")

    app.tapBack()
    waitForNewPage(app, timeout: 20)
    
    app.tapDrawer()
    linkFirstMatch(app, identifier: "drawer-discover").tap()
    
    waitForNewPage(app, timeout: 20)
    snapshot("5_Discover")
  }
}

fileprivate extension XCUIApplication {
  var showFacebookLoginFormButton: XCUIElement {
    return buttons["Continue with Facebook"]
  }
  
  var isAlreadyLogged: Bool {
    return !staticTexts.matching(identifier: "header-login").element.exists
  }
  
  var pageIdentifier: String {
    return "header-brand"
  }
  
  func linkFirstMatch(identifier: String) -> XCUIElement {
    clearCachedLinks()
    return links.matching(identifier: identifier).element(boundBy: 0)
  }
  
  func tapDrawer() {
    images.matching(identifier: "header-slideout-toggle").element(boundBy: 0).tap()
  }
  
  func tapBack() {
    linkFirstMatch(identifier: "header-back").tap()
  }
}

extension XCTestCase {
  func wait(for duration: TimeInterval) {
    let waitExpectation = expectation(description: "Waiting")
    
    let when = DispatchTime.now() + duration
    DispatchQueue.main.asyncAfter(deadline: when) {
      waitExpectation.fulfill()
    }
    
    // We use a buffer here to avoid flakiness with Timer on CI
    waitForExpectations(timeout: duration + 0.5)
  }
  
  /// Wait for element to appear
  func wait(for element: XCUIElement, timeout duration: TimeInterval) {
    let predicate = NSPredicate(format: "exists == true")
    let _ = expectation(for: predicate, evaluatedWith: element, handler: nil)
    
    // We use a buffer here to avoid flakiness with Timer on CI
    waitForExpectations(timeout: duration + 0.5)
  }
  
  func wait(_ app: XCUIApplication, identifier: String, timeout duration: TimeInterval) {
    app.clearCachedStaticTexts()
    app.clearCachedLinks()
    wait(for: app.descendants(matching: XCUIElement.ElementType.any).matching(identifier: identifier).element, timeout: duration)
  }
  
  func waitForNewPage(_ app: XCUIApplication, timeout duration: TimeInterval, documentReadyTime: TimeInterval = 10) {
    wait(for: 5)
    wait(app, identifier: app.pageIdentifier, timeout: duration)
    wait(for: documentReadyTime)
  }
  
  func allowPushNotificationsIfNeeded() {
    addUIInterruptionMonitor(withDescription: "“RemoteNotification” Would Like to Send You Notifications") { (alerts) -> Bool in
      if(alerts.buttons["Allow"].exists){
        alerts.buttons["Allow"].tap();
      }
      return true;
    }
    XCUIApplication().tap()
  }
  
  func linkFirstMatch(_ app: XCUIApplication, identifier: String) -> XCUIElement {
    wait(app, identifier: identifier, timeout: 20)
    return app.linkFirstMatch(identifier: identifier)
  }
}

extension XCUIApplication {
  // Because of "Use cached accessibility hierarchy"
  func clearCachedStaticTexts() {
    let _ = staticTexts.count
  }
  
  func clearCachedLinks() {
    let _ = links.count
  }
  
  func clearCachedTextFields() {
    let _ = textFields.count
  }
  
  func clearCachedTextViews() {
    let _ = textViews.count
  }
}


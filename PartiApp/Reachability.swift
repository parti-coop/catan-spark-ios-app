import Foundation
import Network

protocol Reachable {
  var isConnected: Bool {get}
  func startNetworkReachabilityObserver()
  func stopNetworkReachabilityObserver()
}

class Reachability: Reachable {

  static let shared = Reachability()
  private let monitor = NWPathMonitor()

  var isConnected: Bool {
    monitor.currentPath.status == .satisfied
  }

  func startNetworkReachabilityObserver() {
    monitor.pathUpdateHandler = { path in
      if path.status == .satisfied {
        NotificationCenter.default.post(name: Notifications.Reachability.connected.name, object: nil)
      } else if path.status == .unsatisfied {
        NotificationCenter.default.post(name: Notifications.Reachability.notConnected.name, object: nil)
      }
    }
    let queue = DispatchQueue.global(qos: .background)
    monitor.start(queue: queue)
  }

  func stopNetworkReachabilityObserver() {
    monitor.cancel()
  }
}

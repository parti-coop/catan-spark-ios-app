import Foundation

protocol NotificationName {
  var name: Notification.Name { get }
}

extension RawRepresentable where RawValue == String, Self: NotificationName {
  var name: Notification.Name {
    Notification.Name(rawValue)
  }
}

enum Notifications {
  enum Reachability: String, NotificationName {
    case connected
    case notConnected
  }
}

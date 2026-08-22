//
//  NotificationRouteStore.swift
//  Student Attendance Predictor
//
//  Holds a pending tab destination from a tapped local notification.
//  HomeView consumes this using the existing tab bar — no parallel navigation.
//

import Foundation
import Combine

@MainActor
final class NotificationRouteStore: ObservableObject {
    static let shared = NotificationRouteStore()

    @Published private(set) var pendingDestination: NotificationRoute?

    func setPending(_ route: NotificationRoute) {
        pendingDestination = route
    }

    func clear() {
        pendingDestination = nil
    }

    static func route(from userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        guard let raw = userInfo["deep_link"] as? String else { return nil }
        return NotificationRoute(rawValue: raw)
    }
}

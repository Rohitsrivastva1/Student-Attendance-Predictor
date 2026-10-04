//
//  SchoolabeAnalyticsBackend.swift
//  Student Attendance Predictor
//
//  Sends product analytics to Schoolabe (not ads). Batched POST:
//  POST https://api.schoolabe.com/api/v1/bunk-planner/events
//
//  Body:
//  {
//    "client_user_id": "...",
//    "platform": "ios",
//    "app_version": "1.7.x",
//    "events": [
//      {
//        "name": "funnel_step" | "screen_view_custom" | "screen_exit" | "session_end_custom" | ...,
//        "ts": "2026-09-06T08:51:00Z",
//        "local_day": "2026-09-06",
//        "session_id": "...",
//        "params": { "step": "profile_done", "screen": "home", "seconds_spent": 42 }
//      }
//    ]
//  }
//
//  Daily BE queries:
//  - Funnel: funnel_step (onboarding_intro → profile_form → profile_done
//    → first_subject → first_days → first_mark → first_session_done)
//  - Time per screen: screen_exit.params.seconds_spent grouped by screen + local_day
//  - Time in app: session_end.params.duration_seconds grouped by local_day / user
//

import Foundation

final class SchoolabeAnalyticsBackend: AnalyticsBackend {
    static let shared = SchoolabeAnalyticsBackend()

    private let queue = DispatchQueue(label: "com.schoolabe.bunkplanner.analytics", qos: .utility)
    private let session: URLSession
    private var pending: [[String: Any]] = []
    private var flushWork: DispatchWorkItem?
    private var userId: String = AnalyticsService.shared.userId

    private let queueKey = "schoolabe.analytics.eventQueue"
    private let maxQueue = 250
    private let flushCount = 8
    private let flushDelayNs: UInt64 = 6_000_000_000

    /// Product journey + screen time. Ads stay on Firebase only.
    private static let allowed: Set<String> = [
        "screen_view_custom", "screen_exit",
        "session_start_custom", "session_end_custom",
        "app_first_launch", "app_launched", "app_foregrounded", "app_backgrounded",
        "onboarding_shown", "onboarding_skipped", "onboarding_completed",
        "student_profile_completed", "student_profile_updated",
        "funnel_step", "first_run_step", "first_run_finished",
        "guided_setup_started", "guided_setup_step", "guided_setup_completed",
        "day_marked", "day_cleared", "mark_today_first_use",
        "subject_added", "subject_deleted", "subject_switched", "subject_limit_hit",
        "timetable_updated",
        "skip_planner_viewed", "skip_planner_locked",
        "forecast_viewed", "locked_forecast_viewed", "trend_viewed", "dashboard_viewed",
        "tools_viewed", "settings_opened",
        "day_two_review_prompt_shown", "day_two_review_prompt_action", "review_prompt_shown",
        "review_ask_unlocked", "review_ask_shown", "review_ask_action",
        "pro_cta_shown", "pro_cta_tapped", "pro_paywall_viewed",
        "pro_purchase_started", "pro_purchase_succeeded", "pro_purchase_failed",
        "weekly_active_days", "streak_updated",
        "invite_link_shared", "invite_redeem_started", "invite_redeem_succeeded",
        "invite_redeem_failed", "referral_reward_claimed"
    ]

    init(session: URLSession = .shared) {
        self.session = session
        if let stored = UserDefaults.standard.array(forKey: queueKey) as? [[String: Any]] {
            pending = stored
        }
    }

    func log(name: String, parameters: [String: Any]) {
        guard Self.allowed.contains(name) else { return }
        guard SchoolabeAPIConfiguration.eventsURL != nil else { return }

        let day = Self.localDay()
        let ts = ISO8601DateFormatter().string(from: Date())
        var record: [String: Any] = [
            "name": name,
            "ts": ts,
            "local_day": day
        ]
        if let sid = parameters["session_id"] as? String {
            record["session_id"] = sid
        }
        var params: [String: Any] = [:]
        for (key, value) in parameters {
            if key == "user_id" || key == "session_id" { continue }
            if JSONSerialization.isValidJSONObject([key: value]) {
                params[key] = value
            } else if let n = value as? NSNumber {
                params[key] = n
            } else {
                params[key] = String(describing: value)
            }
        }
        record["params"] = params

        queue.async { [weak self] in
            guard let self else { return }
            self.pending.append(record)
            if self.pending.count > self.maxQueue {
                self.pending = Array(self.pending.suffix(self.maxQueue))
            }
            self.persistLocked()
            let flushNow = name == "funnel_step"
                || name == "first_run_finished"
                || name == "session_end_custom"
                || name == "day_marked"
            if flushNow || self.pending.count >= self.flushCount {
                self.flushLocked()
            } else {
                self.scheduleFlushLocked()
            }
        }
    }

    func setUserID(_ id: String?) {
        if let id { userId = id }
    }

    func setUserProperty(_ value: String?, forName name: String) {}

    func setCollectionEnabled(_ enabled: Bool) {
        if enabled == false {
            queue.async { [weak self] in self?.flushLocked() }
        }
    }

    /// Call when the app backgrounds so the day’s activity reaches Schoolabe.
    func flushNow() {
        queue.async { [weak self] in
            self?.flushLocked()
        }
    }

    private func scheduleFlushLocked() {
        flushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.queue.async { self?.flushLocked() }
        }
        flushWork = work
        queue.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func persistLocked() {
        UserDefaults.standard.set(pending, forKey: queueKey)
    }

    private func flushLocked() {
        flushWork?.cancel()
        flushWork = nil
        guard pending.isEmpty == false else { return }
        guard let url = SchoolabeAPIConfiguration.eventsURL else { return }

        let batch = pending
        pending = []
        persistLocked()

        let body: [String: Any] = [
            "client_user_id": userId,
            "platform": "ios",
            "app_version": AnalyticsService.appVersion,
            "events": batch
        ]
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else {
            pending = batch + pending
            persistLocked()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BunkPlanner/iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        request.httpBody = data

        session.dataTask(with: request) { [weak self] _, response, error in
            let ok: Bool
            if error != nil {
                ok = false
            } else if let http = response as? HTTPURLResponse {
                ok = (200...299).contains(http.statusCode)
            } else {
                ok = false
            }
            guard ok == false else { return }
            self?.queue.async {
                guard let self else { return }
                self.pending = batch + self.pending
                if self.pending.count > self.maxQueue {
                    self.pending = Array(self.pending.suffix(self.maxQueue))
                }
                self.persistLocked()
            }
        }.resume()
    }

    private static func localDay() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

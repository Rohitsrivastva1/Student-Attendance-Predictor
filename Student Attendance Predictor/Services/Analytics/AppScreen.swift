//
//  AppScreen.swift
//  Student Attendance Predictor
//
//  Canonical list of trackable screens. Used by AnalyticsService to record
//  screen views, time-on-screen, and navigation flow (previous -> next).
//

import Foundation

enum AppScreen: String, CaseIterable {
    case loading
    case onboarding
    case home
    case insights
    case log
    case overview
    case tools
    case academics
    case focusTimer = "focus_timer"
    case skipPlannerTool = "skip_planner_tool"
    case semesterForecastTool = "semester_forecast_tool"
    case exportReportsTool = "export_reports_tool"
    case settings
    case subjects
    case timetableEditor = "timetable_editor"
    case dayEditor = "day_editor"
    case privacyPolicy = "privacy_policy"
    case termsOfUse = "terms_of_use"
    case proPaywall = "pro_paywall"

    /// snake_case name sent to analytics backends.
    var analyticsName: String { rawValue }
}

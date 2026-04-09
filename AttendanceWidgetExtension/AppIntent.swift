//
//  AppIntent.swift
//  AttendanceWidgetExtension
//
//  Created by Rohit Srivastava on 05/04/26.
//

import WidgetKit
import AppIntents

enum WidgetDisplayMode: String, AppEnum {
    case lastActive
    case allRiskLarge

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Display Mode"
    }

    static var caseDisplayRepresentations: [WidgetDisplayMode: DisplayRepresentation] {
        [
            .lastActive: "Last Active",
            .allRiskLarge: "All Risk Subjects (Large)"
        ]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Widget Settings" }
    static var description: IntentDescription { "Choose what the widget highlights." }

    @Parameter(title: "Mode", default: .lastActive)
    var mode: WidgetDisplayMode
}

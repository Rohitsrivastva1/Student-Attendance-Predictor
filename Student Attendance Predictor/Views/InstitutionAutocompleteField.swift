//
//  InstitutionAutocompleteField.swift
//  Student Attendance Predictor
//
//  Typeahead for school/college. Prefers catalog matches; soft-blocks junk names.
//

import SwiftUI

struct InstitutionAutocompleteField: View {
    @Binding var institutionName: String
    var accent: Color = BrandColor.colorAccentPrimary
    var onSubmit: (() -> Void)? = nil

    @ObservedObject private var catalog = InstitutionCatalog.shared
    @FocusState private var isFocused: Bool
    @State private var query = ""
    @State private var suggestions: [InstitutionRecord] = []
    @State private var showSuggestions = false
    @State private var searchGeneration = 0
    @State private var didPickSuggestion = false
    @State private var didHydrate = false
    @State private var listTitle: String?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var incompleteHint: String? {
        InstitutionNameQuality.incompleteHint(for: institutionName.isEmpty ? trimmedQuery : institutionName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField

            if let hint = incompleteHint {
                Text(hint)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(BrandColor.colorMissed.opacity(0.95))
            } else if trimmedQuery.count < 2, showSuggestions == false {
                Text("Type a college, school, or city (Delhi, Mumbai…) — top matches appear below")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            if showSuggestions {
                if let listTitle {
                    Text(listTitle)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 2)
                }
                suggestionsList
            }
        }
        .onAppear {
            if didHydrate == false {
                didHydrate = true
                if institutionName.isEmpty == false {
                    didPickSuggestion = true
                    query = institutionName
                }
            }
            Task { await catalog.loadIfNeeded() }
        }
        .onChange(of: query) { _, newValue in
            if didPickSuggestion {
                didPickSuggestion = false
                return
            }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if InstitutionNameQuality.isAcceptable(trimmed, allowIncompleteOverride: false) {
                institutionName = InstitutionNameQuality.normalizedForStorage(trimmed)
            } else {
                institutionName = ""
            }
            scheduleSearch(newValue)
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                if trimmedQuery.count < 2 {
                    Task { await showPopular() }
                }
            } else {
                showSuggestions = false
                finalizeOnBlur()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))

            TextField("e.g. NMIMS, DPS Delhi, IIT Bombay", text: $query)
                .textContentType(.organizationName)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .foregroundStyle(.white)
                .focused($isFocused)
                .onSubmit {
                    if let exact = suggestions.first(where: {
                        $0.name.compare(trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                    }) {
                        pick(exact.name)
                    } else if let first = suggestions.first,
                              InstitutionNameQuality.looksIncomplete(trimmedQuery) == false {
                        pick(first.name)
                    } else {
                        commitTyped()
                    }
                    onSubmit?()
                }

            if query.isEmpty == false {
                Button {
                    query = ""
                    institutionName = ""
                    suggestions = []
                    showSuggestions = false
                    listTitle = nil
                    Task { await showPopular() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { item in
                Button {
                    pick(item.name)
                } label: {
                    suggestionRow(
                        title: item.name,
                        subtitle: item.subtitle,
                        icon: "building.columns.fill"
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.white.opacity(0.08))
            }

            if trimmedQuery.count >= 2,
               InstitutionNameQuality.looksIncomplete(trimmedQuery) == false,
               suggestions.contains(where: {
                   $0.name.compare(trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
               }) == false {
                Button {
                    commitTyped()
                } label: {
                    suggestionRow(
                        title: "Use “\(trimmedQuery)”",
                        subtitle: "Not in list — save this name",
                        icon: "pencil.line"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func suggestionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent.opacity(0.9))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func pick(_ name: String) {
        let normalized = InstitutionNameQuality.normalizedForStorage(name)
        didPickSuggestion = true
        query = normalized
        institutionName = normalized
        suggestions = []
        showSuggestions = false
        listTitle = nil
        isFocused = false
    }

    private func commitTyped() {
        let trimmed = trimmedQuery
        guard InstitutionNameQuality.isAcceptable(trimmed, allowIncompleteOverride: false) else { return }
        pick(trimmed)
    }

    private func finalizeOnBlur() {
        let trimmed = trimmedQuery
        guard trimmed.count >= 2 else { return }
        if InstitutionNameQuality.isAcceptable(trimmed, allowIncompleteOverride: false) {
            institutionName = InstitutionNameQuality.normalizedForStorage(trimmed)
            query = institutionName
        }
    }

    private func showPopular() async {
        let popular = await catalog.popularSuggestions(limit: 10)
        suggestions = popular
        listTitle = "Popular colleges"
        showSuggestions = popular.isEmpty == false
    }

    private func scheduleSearch(_ text: String) {
        searchGeneration += 1
        let generation = searchGeneration
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.count < 2 {
            Task {
                guard generation == searchGeneration else { return }
                await showPopular()
            }
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard generation == searchGeneration else { return }
            if let city = catalog.detectedCity(from: needle) {
                let local = await catalog.suggestions(forCity: city, limit: 10)
                guard generation == searchGeneration else { return }
                suggestions = local
                listTitle = "Top in \(city.capitalized)"
                showSuggestions = true
                return
            }
            let results = await catalog.search(query: needle, limit: 10)
            guard generation == searchGeneration else { return }
            suggestions = results
            listTitle = results.isEmpty ? nil : "Matches"
            showSuggestions = true
        }
    }
}

//
//  LogDetailView.swift
//  CoffeeGrams
//
//  View and edit a single saved brew: rate it, add tasting notes, or delete it.
//

import SwiftUI
import SwiftData
import CoffeeGramsCore

struct LogDetailView: View {
    /// `@Bindable` lets us bind SwiftUI controls straight to the model's
    /// properties; edits are persisted by saving the context.
    @Bindable var record: BrewLogRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// A local draft so notes persist once (when leaving the screen), not on
    /// every keystroke.
    @State private var notesDraft = ""

    var body: some View {
        Form {
            Section {
                summaryRow("Method", record.method.displayName)
                summaryRow("Dose", "\(Int(record.doseGrams.rounded())) g")
                summaryRow(record.method == .espresso ? "Yield" : "Water",
                           "\(Int(record.waterGrams.rounded())) g")
                summaryRow("Ratio", "1:\(Int(record.ratio.rounded()))")
                if let shot = record.shotSeconds {
                    summaryRow("Shot time", "\(shot)s")
                }
                summaryRow("Date", record.date.formatted(date: .abbreviated, time: .shortened))
            }
            .listRowBackground(Color.cgSurface)

            Section {
                StarRating(rating: ratingBinding)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } header: {
                header("Rating")
            }
            .listRowBackground(Color.cgSurface)

            Section {
                TextField("Tasting notes", text: $notesDraft, axis: .vertical)
                    .lineLimit(3...8)
                    .foregroundStyle(Color.cgTextPrimary)
            } header: {
                header("Notes")
            }
            .listRowBackground(Color.cgSurface)

            Section {
                Button("Delete Brew", role: .destructive) {
                    do {
                        try store.delete(id: record.id)
                        dismiss()
                    } catch {
                        // Keep the screen if deletion fails so the user can retry.
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.cgSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle(record.method.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notesDraft = record.notes ?? "" }
        .onDisappear { saveNotes() }
        // Also persist when the app leaves the foreground, so notes survive
        // backgrounding/termination while the screen is still open.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveNotes() }
        }
    }

    // MARK: Persistence

    /// Route writes through the store rather than persisting from the view.
    private var store: BrewLogStore { BrewLogStore(context: modelContext) }

    /// 0 = unrated; stored as nil.
    private var ratingBinding: Binding<Int> {
        Binding(
            get: { record.rating ?? 0 },
            set: { try? store.setRating($0 == 0 ? nil : $0, forID: record.id) }
        )
    }

    /// Persist the notes draft once, trimmed, when leaving the screen.
    private func saveNotes() {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? store.setNotes(trimmed.isEmpty ? nil : trimmed, forID: record.id)
    }

    // MARK: Row helpers

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.cgTextSecondary)
            Spacer()
            Text(value).foregroundStyle(Color.cgTextPrimary)
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.cgTextSecondary)
    }
}

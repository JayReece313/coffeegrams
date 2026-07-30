//
//  LogView.swift
//  CoffeeGrams
//
//  History of saved brews. Reads reactively from SwiftData via @Query so it
//  updates the moment a brew is saved or deleted.
//

import SwiftUI
import SwiftData
import CoffeeGramsCore

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrewLogRecord.date, order: .reverse) private var records: [BrewLogRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "No brews yet",
                    systemImage: "cup.and.saucer",
                    description: Text("Finish a brew and tap Save to Log.")
                )
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink {
                            LogDetailView(record: record)
                        } label: {
                            LogRow(record: record)
                        }
                        .listRowBackground(Color.cgSurface)
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle("Brew Log")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delete(_ offsets: IndexSet) {
        // Route deletion through the store rather than persisting from the view.
        let store = BrewLogStore(context: modelContext)
        for index in offsets {
            try? store.delete(id: records[index].id)
        }
    }
}

/// One brew in the history list.
private struct LogRow: View {
    let record: BrewLogRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.method.iconSystemName)
                .foregroundStyle(Color.cgTextPrimary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.method.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.cgTextPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.cgTextSecondary)
                if let timing {
                    Text(timing)
                        .font(.caption)
                        .foregroundStyle(Color.cgTextSecondary)
                }
            }

            Spacer()

            if let rating = record.rating {
                StarRating(rating: .constant(rating), isEditable: false, size: 11)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let dose = Int(record.doseGrams.rounded())
        let water = Int(record.waterGrams.rounded())
        let ratio = Int(record.ratio.rounded())
        let when = record.date.formatted(date: .abbreviated, time: .shortened)
        return "\(dose)g → \(water)g · 1:\(ratio) · \(when)"
    }

    /// "4:45 actual · 4:15 planned" — only for brews saved with a timeline
    /// (1.1 onwards). Pre-1.1 rows have no timing and simply omit the line.
    private var timing: String? {
        guard let actual = record.actualSeconds else { return nil }
        guard let planned = record.plannedSeconds else {
            return "\(TimeFormat.mmss(actual)) actual"
        }
        return "\(TimeFormat.mmss(actual)) actual · \(TimeFormat.mmss(planned)) planned"
    }
}

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
                TextField("Tasting notes", text: notesBinding, axis: .vertical)
                    .lineLimit(3...8)
                    .foregroundStyle(Color.cgTextPrimary)
            } header: {
                header("Notes")
            }
            .listRowBackground(Color.cgSurface)

            Section {
                Button("Delete Brew", role: .destructive) {
                    modelContext.delete(record)
                    try? modelContext.save()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.cgSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle(record.method.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Bindings that persist on change

    /// 0 = unrated; stored as nil.
    private var ratingBinding: Binding<Int> {
        Binding(
            get: { record.rating ?? 0 },
            set: {
                record.rating = ($0 == 0) ? nil : $0
                try? modelContext.save()
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { record.notes ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                record.notes = trimmed.isEmpty ? nil : $0
                try? modelContext.save()
            }
        )
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

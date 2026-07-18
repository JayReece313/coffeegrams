//
//  StarRating.swift
//  CoffeeGrams
//
//  A small 1–5 star control, used editable in the log detail and read-only in
//  the list rows. `rating` of 0 means "unrated".
//

import SwiftUI

struct StarRating: View {
    @Binding var rating: Int
    var isEditable: Bool = true
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(value <= rating ? Color.cgAccent : Color.cgTextSecondary)
                    .onTapGesture {
                        guard isEditable else { return }
                        // Tapping the current rating clears it back to unrated.
                        rating = (rating == value) ? 0 : value
                    }
                    .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
            }
        }
    }
}

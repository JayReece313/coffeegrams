//
//  TimeFormatting.swift
//  CoffeeGrams
//
//  Shared, testable time formatting for the timers.
//

import Foundation

enum TimeFormat {
    /// Formats a whole number of seconds as "M:SS" (e.g. 125 → "2:05").
    /// Negative inputs are clamped to zero.
    ///
    /// `nonisolated`: this is pure and has no UI dependency, so it should be
    /// callable from any context (the app module otherwise defaults everything
    /// to the main actor).
    nonisolated static func mmss(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// The same duration in words, for VoiceOver — "2:14" is read aloud as
    /// "two colon fourteen", which is useless mid-brew. Whole minutes drop the
    /// seconds ("4 minutes", not "4 minutes 0 seconds"), and under a minute
    /// drops the minutes.
    nonisolated static func spoken(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60

        let minutePart = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        let secondPart = "\(seconds) second\(seconds == 1 ? "" : "s")"

        if minutes == 0 { return secondPart }
        if seconds == 0 { return minutePart }
        return "\(minutePart) \(secondPart)"
    }
}

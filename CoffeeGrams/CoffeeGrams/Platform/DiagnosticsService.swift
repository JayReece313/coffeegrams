//
//  DiagnosticsService.swift
//  CoffeeGrams
//
//  Subscribes to MetricKit so crashes, hangs, and performance metrics are
//  captured ON-DEVICE and written to the unified log. Nothing is transmitted —
//  this preserves the app's "Data Not Collected" privacy posture while still
//  giving visibility into production issues via Console / Xcode Organizer.
//

import Foundation
import MetricKit
import os

final class DiagnosticsService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = DiagnosticsService()

    private let logger = Logger(subsystem: "com.jrlabs.coffeegrams", category: "diagnostics")

    /// Register for MetricKit payloads. Safe to call once at launch.
    func start() {
        MXMetricManager.shared.add(self)
    }

    // MetricKit delivers these on a background queue, so the methods are
    // nonisolated (the app module otherwise defaults to the main actor).

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        logger.info("MetricKit: received \(payloads.count, privacy: .public) metric payload(s)")
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashes = payload.crashDiagnostics?.count ?? 0
            let hangs = payload.hangDiagnostics?.count ?? 0
            logger.warning("MetricKit: \(crashes, privacy: .public) crash(es), \(hangs, privacy: .public) hang(s)")
        }
    }
}

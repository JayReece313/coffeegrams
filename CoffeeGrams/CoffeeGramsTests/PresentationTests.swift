//
//  PresentationTests.swift
//  CoffeeGramsTests
//
//  Small pure presentation helpers used by the timer screens.
//

import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

@Suite("Time formatting")
struct TimeFormatTests {
    @Test("formats seconds as M:SS")
    func mmss() {
        #expect(TimeFormat.mmss(0) == "0:00")
        #expect(TimeFormat.mmss(5) == "0:05")
        #expect(TimeFormat.mmss(65) == "1:05")
        #expect(TimeFormat.mmss(125) == "2:05")
    }

    @Test("negative input clamps to zero")
    func negativeClamps() {
        #expect(TimeFormat.mmss(-3) == "0:00")
    }
}

@Suite("BrewStep presentation")
struct BrewStepPresentationTests {
    @Test("bloom and pour expose a gram target; steep does not")
    func targetGrams() {
        #expect(BrewStep.bloom(targetGrams: 45, duration: 45).targetGramsText == "45 g")
        #expect(BrewStep.pour(pourNumber: 1, targetCumulativeGrams: 200, duration: 45).targetGramsText == "200 g")
        #expect(BrewStep.steep(duration: 120).targetGramsText == nil)
        #expect(BrewStep.plunge.targetGramsText == nil)
    }

    @Test("instructions mention the target where relevant")
    func instructions() {
        #expect(BrewStep.bloom(targetGrams: 45, duration: 45).instruction.contains("45 g"))
        #expect(BrewStep.pour(pourNumber: 1, targetCumulativeGrams: 200, duration: 45).instruction.contains("200 g"))
        #expect(!BrewStep.plunge.instruction.isEmpty)
    }
}

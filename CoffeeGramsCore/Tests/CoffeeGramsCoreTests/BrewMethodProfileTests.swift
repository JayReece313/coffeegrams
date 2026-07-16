import Testing
@testable import CoffeeGramsCore

/// M1 gate: the hardcoded reference table (spec §3) is internally consistent.
/// These are cheap invariants, but they catch a whole class of data-entry bugs
/// (a typo'd range, a missing method) that would otherwise surface as weird UI
/// behaviour much later.
@Suite("BrewMethodProfile reference table")
struct BrewMethodProfileTests {

    @Test("every method has exactly one profile")
    func everyMethodHasExactlyOneProfile() {
        for method in BrewMethod.allCases {
            let matches = BrewMethodProfile.all.filter { $0.method == method }
            #expect(matches.count == 1, "\(method) should have exactly one profile")
        }
        #expect(BrewMethodProfile.all.count == BrewMethod.allCases.count)
    }

    @Test("profile(for:) returns the matching method", arguments: BrewMethod.allCases)
    func profileLookupMatches(method: BrewMethod) {
        #expect(BrewMethodProfile.profile(for: method).method == method)
    }

    @Test("default ratio sits inside the allowed range", arguments: BrewMethodProfile.all)
    func defaultRatioWithinRange(profile: BrewMethodProfile) {
        #expect(profile.ratioRange.contains(profile.defaultRatio),
                "\(profile.method) default \(profile.defaultRatio) outside \(profile.ratioRange)")
    }

    @Test("ratio ranges are well-formed (lower <= upper, positive)", arguments: BrewMethodProfile.all)
    func ratioRangeWellFormed(profile: BrewMethodProfile) {
        #expect(profile.ratioRange.lowerBound > 0)
        #expect(profile.ratioRange.lowerBound <= profile.ratioRange.upperBound)
    }

    @Test("exact values from the spec §3 table")
    func specTableValues() {
        let v60 = BrewMethodProfile.profile(for: .v60)
        #expect(v60.brewType == .pulsePour)
        #expect(v60.defaultRatio == 16.0)
        #expect(v60.ratioRange == 15.0...17.0)
        #expect(v60.bloomMultiplier == 2.25)
        #expect(v60.bloomSeconds == 45)
        #expect(v60.numPours == 2)
        #expect(v60.pourIntervalSeconds == 45)

        let chemex = BrewMethodProfile.profile(for: .chemex)
        #expect(chemex.pourIntervalSeconds == 60) // spaced wider than V60
        #expect(chemex.bloomMultiplier == 2.5)

        let fp = BrewMethodProfile.profile(for: .frenchPress)
        #expect(fp.brewType == .immersion)
        #expect(fp.defaultRatio == 15.0)
        #expect(fp.steepSeconds == 240)
        #expect(fp.bloomMultiplier == 2.0)

        let aero = BrewMethodProfile.profile(for: .aeropress)
        #expect(aero.defaultRatio == 18.0)          // Hoffmann default
        #expect(aero.ratioRange == 12.0...18.0)
        #expect(aero.bloomMultiplier == nil)        // no bloom
        #expect(aero.steepSeconds == 120)

        let cold = BrewMethodProfile.profile(for: .coldBrew)
        #expect(cold.defaultRatio == 5.0)           // concentrate
        #expect(cold.steepSeconds == nil)           // steep measured in hours

        let esp = BrewMethodProfile.profile(for: .espresso)
        #expect(esp.brewType == .pressure)
        #expect(esp.defaultRatio == 2.0)
        #expect(esp.ratioRange == 1.0...3.0)
        #expect(esp.shotTimeRangeSeconds == 25...30)
    }

    @Test("only espresso defines a shot-time window")
    func onlyEspressoHasShotWindow() {
        for profile in BrewMethodProfile.all {
            if profile.method == .espresso {
                #expect(profile.shotTimeRangeSeconds != nil)
            } else {
                #expect(profile.shotTimeRangeSeconds == nil)
            }
        }
    }

    @Test("free tier is exactly V60 + French Press")
    func freeTierSplit() {
        let free = BrewMethod.allCases.filter(\.isFreeTier)
        #expect(Set(free) == [.v60, .frenchPress])
    }
}

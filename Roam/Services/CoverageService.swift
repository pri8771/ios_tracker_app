import Foundation

/// Coverage of a single state: how many ZIP Code Areas the user has colored in,
/// out of the (approximate) total for that state.
struct StateCoverage: Identifiable, Equatable, Sendable {
    let state: USState
    let areaCount: Int
    let estimatedTotal: Int?

    var id: String { state.code }

    /// Estimated fraction of the state colored in (0...1), if a total is known.
    var fraction: Double? {
        guard let estimatedTotal, estimatedTotal > 0 else { return nil }
        return min(1, Double(areaCount) / Double(estimatedTotal))
    }
}

/// A privacy-safe, state-level rollup of the user's coverage. This is the only
/// shape allowed to leave the device in a share image — it carries counts and
/// percentages, never raw coordinates or individual ZIP polygons.
struct CoverageSummary: Equatable, Sendable {
    let totalAreas: Int
    let states: [StateCoverage]      // sorted by areaCount desc, then name

    var statesTouched: Int { states.count }
    var topState: StateCoverage? { states.first }

    /// Fraction of the 50 states with at least one colored area.
    var nationalStatesFraction: Double {
        Double(states.filter { USStateResolver.allStateCodes.contains($0.state.code) }.count) / 50.0
    }

    static let empty = CoverageSummary(totalAreas: 0, states: [])
}

/// Pure, testable computation of coverage rollups from a set of discovered ZIP
/// Code Area codes. No persistence, no location — just aggregation.
struct CoverageService {

    func summary(forCodes codes: [String]) -> CoverageSummary {
        let distinct = Array(Set(codes))
        guard !distinct.isEmpty else { return .empty }

        var byState: [String: (state: USState, count: Int)] = [:]
        for code in distinct {
            guard let state = USStateResolver.state(forZIP: code) else { continue }
            byState[state.code, default: (state, 0)].count += 1
        }

        let coverages: [StateCoverage] = byState.values.map { entry in
            StateCoverage(
                state: entry.state,
                areaCount: entry.count,
                estimatedTotal: USStateResolver.approximateZCTACount(for: entry.state.code)
            )
        }
        .sorted { lhs, rhs in
            if lhs.areaCount != rhs.areaCount { return lhs.areaCount > rhs.areaCount }
            return lhs.state.name < rhs.state.name
        }

        return CoverageSummary(totalAreas: distinct.count, states: coverages)
    }
}

import Foundation

/// A US state / territory, derived from a ZIP Code Area's leading digits.
struct USState: Hashable, Sendable, Identifiable, Comparable {
    let code: String      // "CA"
    let name: String      // "California"

    var id: String { code }

    static func < (lhs: USState, rhs: USState) -> Bool { lhs.name < rhs.name }
}

/// Resolves a ZCTA / ZIP code to its US state, purely from the code's leading
/// three digits (the USPS Sectional Center Facility prefix), with no network and
/// no per-row state column in the bundle.
///
/// This is the backbone of Roam's **location-abstraction** rule: the shareable
/// rollup and the progress screen report coverage at the *state* level, never the
/// raw ZIP polygons, so a public share can't disclose a home neighborhood.
///
/// State assignment from a 3-digit prefix is exact for the published SCF ranges.
/// Per-state ZCTA totals are *approximate* (2020 Census, rounded) and are only
/// ever surfaced as an explicitly-labeled estimate.
enum USStateResolver {

    /// Resolves a full ZIP/ZCTA code (e.g. "94103") to its state.
    static func state(forZIP zip: String) -> USState? {
        let digits = zip.filter(\.isNumber)
        guard digits.count >= 3, let prefix = Int(digits.prefix(3)) else { return nil }
        guard let code = stateCode(forPrefix: prefix) else { return nil }
        return USState(code: code, name: name(for: code) ?? code)
    }

    /// Distinct states represented by a set of ZIP/ZCTA codes.
    static func states<S: Sequence>(forZIPs zips: S) -> [USState] where S.Element == String {
        var seen = Set<String>()
        var result: [USState] = []
        for zip in zips {
            guard let s = state(forZIP: zip), !seen.contains(s.code) else { continue }
            seen.insert(s.code)
            result.append(s)
        }
        return result.sorted()
    }

    /// Approximate number of ZCTAs in a state (rounded; for estimated coverage %).
    static func approximateZCTACount(for stateCode: String) -> Int? {
        approxZCTACounts[stateCode]
    }

    static func name(for stateCode: String) -> String? { stateNames[stateCode] }

    /// All 50 states + DC (used for "X of 50 states" rollups; territories excluded).
    static let allStateCodes: [String] = [
        "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA",
        "KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
        "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT",
        "VA","WA","WV","WI","WY"
    ]

    // MARK: - Prefix → state code

    private static func stateCode(forPrefix p: Int) -> String? {
        for range in prefixRanges where p >= range.lo && p <= range.hi {
            return range.code
        }
        return nil
    }

    /// (lo, hi) inclusive 3-digit SCF prefix ranges → state code.
    private static let prefixRanges: [(lo: Int, hi: Int, code: String)] = [
        (5, 5, "NY"), (6, 9, "PR"),
        (10, 27, "MA"), (28, 29, "RI"), (30, 38, "NH"), (39, 49, "ME"),
        (50, 59, "VT"), (60, 69, "CT"), (70, 89, "NJ"),
        (100, 149, "NY"), (150, 196, "PA"), (197, 199, "DE"),
        (200, 205, "DC"), (206, 219, "MD"), (220, 246, "VA"), (247, 268, "WV"),
        (270, 289, "NC"), (290, 299, "SC"), (300, 319, "GA"), (320, 349, "FL"),
        (350, 369, "AL"), (370, 385, "TN"), (386, 397, "MS"), (398, 399, "GA"),
        (400, 427, "KY"), (430, 459, "OH"), (460, 479, "IN"), (480, 499, "MI"),
        (500, 528, "IA"), (530, 549, "WI"), (550, 567, "MN"), (569, 569, "DC"),
        (570, 577, "SD"), (580, 588, "ND"), (590, 599, "MT"),
        (600, 629, "IL"), (630, 658, "MO"), (660, 679, "KS"), (680, 693, "NE"),
        (700, 714, "LA"), (716, 729, "AR"), (730, 749, "OK"),
        (750, 799, "TX"), (800, 816, "CO"), (820, 831, "WY"), (832, 838, "ID"),
        (840, 847, "UT"), (850, 865, "AZ"), (870, 884, "NM"), (885, 885, "TX"),
        (889, 898, "NV"), (900, 961, "CA"), (967, 968, "HI"),
        (970, 979, "OR"), (980, 994, "WA"), (995, 999, "AK")
    ]

    private static let stateNames: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "DC": "Washington, D.C.", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
        "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
        "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine",
        "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska",
        "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
        "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
        "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island",
        "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas",
        "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
        "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming", "PR": "Puerto Rico"
    ]

    /// Approximate ZCTA counts per state (2020 Census, rounded). Estimate only.
    private static let approxZCTACounts: [String: Int] = [
        "AL": 642, "AK": 261, "AZ": 408, "AR": 599, "CA": 1763, "CO": 526,
        "CT": 282, "DE": 104, "DC": 57, "FL": 983, "GA": 733, "HI": 94,
        "ID": 317, "IL": 1383, "IN": 775, "IA": 935, "KS": 697, "KY": 770,
        "LA": 518, "ME": 433, "MD": 468, "MA": 538, "MI": 983, "MN": 885,
        "MS": 538, "MO": 1021, "MT": 363, "NE": 581, "NV": 220, "NH": 261,
        "NJ": 595, "NM": 369, "NY": 1794, "NC": 808, "ND": 388, "OH": 1197,
        "OK": 647, "OR": 417, "PA": 1791, "RI": 92, "SC": 424, "SD": 382,
        "TN": 625, "TX": 1935, "UT": 289, "VT": 302, "VA": 895, "WA": 597,
        "WV": 700, "WI": 775, "WY": 190, "PR": 135
    ]
}

import SwiftUI

/// The privacy-safe, shareable coverage card — Roam's growth loop.
///
/// **Location-abstraction rule (hard requirement):** this card renders only
/// *state-level* counts and coverage percentages. It never draws the map, raw
/// coordinates, or individual ZIP polygons, so a publicly-posted image cannot
/// disclose a home neighborhood. The precise polygon track always stays on device.
///
/// Rendered to an image off-screen via `ImageRenderer`, so it is fully
/// self-contained (no environment dependencies).
struct ShareCardView: View {
    let coverage: CoverageSummary
    var headline: String = "My travels on Roam"
    var dateText: String

    private var topStates: [StateCoverage] { Array(coverage.states.prefix(5)) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFF8A4D), Color(hex: 0xF5559E), Color(hex: 0x7C3AED)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Soft decorative blobs.
            Circle().fill(Color.white.opacity(0.10)).frame(width: 520).blur(radius: 8)
                .offset(x: 180, y: -380)
            Circle().fill(Color.white.opacity(0.08)).frame(width: 360).blur(radius: 6)
                .offset(x: -200, y: 420)

            VStack(alignment: .leading, spacing: 0) {
                // Wordmark
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 30, weight: .bold))
                    Text("ROAM")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .tracking(4)
                    Spacer()
                }
                .foregroundStyle(.white)

                Spacer(minLength: 40)

                Text(headline)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                // Hero number
                HStack(alignment: .lastTextBaseline, spacing: 16) {
                    Text("\(coverage.totalAreas)")
                        .font(.system(size: 150, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("ZIP\nareas")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 24)
                }

                // Stat pills
                HStack(spacing: 14) {
                    pill(value: "\(coverage.statesTouched)", label: coverage.statesTouched == 1 ? "state" : "states")
                    if let top = coverage.topState {
                        pill(value: top.state.code, label: "most explored")
                    }
                    if coverage.nationalStatesFraction > 0 {
                        pill(value: "\(Int((coverage.nationalStatesFraction * 100).rounded()))%", label: "of 50 states")
                    }
                }
                .padding(.top, 18)

                Spacer(minLength: 40)

                // Top states with mini bars
                if !topStates.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("WHERE I'VE BEEN")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.8))
                        ForEach(topStates) { sc in
                            stateRow(sc)
                        }
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.white.opacity(0.16))
                    )
                }

                Spacer(minLength: 40)

                // Footer
                HStack {
                    Label("Tracked privately on my iPhone", systemImage: "lock.fill")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                    Spacer()
                    Text(dateText)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(64)
        }
        .frame(width: ShareCardView.size.width, height: ShareCardView.size.height)
    }

    /// Target export size (4:5 portrait, ideal for social feeds).
    static let size = CGSize(width: 1080, height: 1350)

    private func pill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 40, weight: .heavy, design: .rounded))
            Text(label).font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.16))
        )
    }

    private func stateRow(_ sc: StateCoverage) -> some View {
        HStack(spacing: 16) {
            Text(sc.state.name)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let fraction = sc.fraction {
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(width: 160, height: 12)
                    Capsule().fill(.white).frame(width: max(12, 160 * fraction), height: 12)
                }
            }
            Text("\(sc.areaCount)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }
}

#Preview {
    ShareCardView(
        coverage: CoverageSummary(totalAreas: 142, states: [
            StateCoverage(state: USState(code: "CA", name: "California"), areaCount: 88, estimatedTotal: 1763),
            StateCoverage(state: USState(code: "NV", name: "Nevada"), areaCount: 31, estimatedTotal: 220),
            StateCoverage(state: USState(code: "OR", name: "Oregon"), areaCount: 23, estimatedTotal: 417)
        ]),
        dateText: "June 2026"
    )
    .scaleEffect(0.28)
}

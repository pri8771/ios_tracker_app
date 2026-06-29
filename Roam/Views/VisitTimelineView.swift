import SwiftUI

/// Renders the timeline mode of History: a `List` with one section per day
/// (newest first), each containing `ZCTAVisitRow`s.
struct VisitTimelineView: View {
    let sections: [HistoryViewModel.DaySection]
    var onDeleteVisit: ((ZCTAVisit) -> Void)? = nil

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.visits) { visit in
                        ZCTAVisitRow(visit: visit)
                            .swipeActions(edge: .trailing) {
                                if let onDeleteVisit {
                                    Button(role: .destructive) {
                                        onDeleteVisit(visit)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                } header: {
                    Text(dayHeader(section.date))
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

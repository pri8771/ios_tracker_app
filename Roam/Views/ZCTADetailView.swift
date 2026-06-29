import SwiftUI
import MapKit

/// Per-ZCTA detail screen: header with favorite + editable note, stats grid,
/// a mini boundary map, the visit timeline, and actions (export, archive, delete).
struct ZCTADetailView: View {
    @StateObject private var vm: ZCTADetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false
    @FocusState private var noteFocused: Bool

    init(tracked: TrackedZCTA, container: DependencyContainer) {
        _vm = StateObject(wrappedValue: ZCTADetailViewModel(tracked: tracked, container: container))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                miniMap
                statsGrid
                noteEditor
                disclaimer
                visitTimeline
            }
            .padding()
        }
        .navigationTitle(vm.tracked.zctaCode)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        vm.exportCSV()
                        if vm.exportedFileURL != nil { showShareSheet = true }
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        vm.archive()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete this ZIP Code Area and all its visits?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                vm.delete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = vm.exportedFileURL {
                #if canImport(UIKit)
                ActivityView(items: [url])
                #endif
            }
        }
        .onAppear { vm.loadBoundary() }
    }

    private var header: some View {
        GlassPanel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.tracked.zctaCode)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Census ZCTA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    vm.toggleFavorite()
                } label: {
                    Image(systemName: vm.tracked.isFavorite ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(vm.tracked.isFavorite ? .yellow : .secondary)
                }
                .accessibilityLabel(vm.tracked.isFavorite ? "Remove favorite" : "Add favorite")
            }
        }
    }

    private var miniMap: some View {
        Map(initialPosition: .region(vm.centerRegion)) {
            Marker(vm.tracked.zctaCode, coordinate: vm.tracked.centroidCoordinate)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityLabel("Map centered on ZIP Code Area \(vm.tracked.zctaCode)")
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatCell(title: "First Discovered", value: shortDateTime(vm.firstDiscovered), systemImage: "sparkles")
            StatCell(title: "Last Seen", value: relativeTime(vm.lastSeen), systemImage: "eye")
            StatCell(title: "Visits", value: "\(vm.visitCount)", systemImage: "clock.arrow.circlepath")
            StatCell(title: "Total Time", value: formattedDuration(vm.totalDuration), systemImage: "hourglass")
            StatCell(title: "Average Visit", value: formattedDuration(vm.averageVisitSeconds), systemImage: "chart.bar")
            StatCell(title: "Longest Visit", value: formattedDuration(vm.longestVisitSeconds), systemImage: "arrow.up.right")
        }
    }

    private var noteEditor: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Note").font(.headline)
                TextField("Add a private note", text: $vm.note, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($noteFocused)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Save") {
                        vm.saveNote()
                        noteFocused = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(vm.note == vm.tracked.note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var disclaimer: some View {
        Text(AppConstants.Copy.zctaLongDisclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var visitTimeline: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Visits").font(.headline)
                if vm.visits.isEmpty {
                    Text("No recorded visits.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.visits) { visit in
                        ZCTAVisitRow(visit: visit)
                        if visit.id != vm.visits.last?.id { Divider() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatCell: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                Text(value)
                    .font(.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

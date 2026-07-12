import SwiftData
import SwiftUI

struct EventDetailView: View {
    @Bindable var event: Event

    @State private var searchText = ""
    @State private var showCapture = false
    @State private var showEdit = false
    @State private var exportURL: URL?

    private var filteredContacts: [Contact] {
        let sorted = event.contacts.sorted { lhs, rhs in
            if lhs.heat != rhs.heat {
                return heatRank(lhs.heat) < heatRank(rhs.heat)
            }
            return lhs.createdAt > rhs.createdAt
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.company.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                statsHeader
            }

            Section("名片（\(event.contacts.count)）") {
                if event.contacts.isEmpty {
                    Text("還沒有名片，按下方「掃描名片」開始。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredContacts) { contact in
                        NavigationLink(value: contact) {
                            ContactRowView(contact: contact)
                        }
                    }
                }
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact)
        }
        .searchable(text: $searchText, prompt: "搜尋姓名或公司")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("編輯展會", systemImage: "pencil")
                    }
                    Button {
                        exportURL = CSVExporter.export(event: event)
                    } label: {
                        Label("匯出 CSV 報表", systemImage: "square.and.arrow.up")
                    }
                    .disabled(event.contacts.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showCapture = true
            } label: {
                Label("掃描名片", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureFlowView(event: event)
        }
        .sheet(isPresented: $showEdit) {
            EventFormView(event: event)
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(items: [url])
        }
    }

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                statCell(value: "\(event.contacts.count)", label: "名片")
                statCell(value: "🔥 \(event.hotCount)", label: "熱名單")
                statCell(
                    value: event.contacts.isEmpty
                        ? "—"
                        : "\(Int(Double(event.contactedCount) / Double(event.contacts.count) * 100))%",
                    label: "已跟進率"
                )
            }
            if let costPerCard = event.costPerCard {
                Text("攤位成本 NT$\(Int(event.boothCost).formatted())，平均每張名片 NT$\(Int(costPerCard).formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func heatRank(_ heat: HeatLevel) -> Int {
        switch heat {
        case .hot: return 0
        case .warm: return 1
        case .cold: return 2
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

import SwiftUI

struct ContactRowView: View {
    let contact: Contact
    var showEventName = false

    var body: some View {
        HStack(spacing: 12) {
            Text(contact.heat.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.headline)
                HStack(spacing: 4) {
                    if !contact.company.isEmpty {
                        Text(contact.company)
                    }
                    if showEventName, let eventName = contact.event?.name {
                        Text("· \(eventName)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text(contact.status.label)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch contact.status {
        case .pending: return .orange
        case .contacted: return .blue
        case .replied: return .teal
        case .meeting: return .purple
        case .won: return .green
        case .lost: return .gray
        }
    }
}

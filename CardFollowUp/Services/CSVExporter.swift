import Foundation

/// 匯出展會成果 CSV（含 BOM，Excel 開啟中文不亂碼）。
enum CSVExporter {
    static func export(event: Event) -> URL? {
        let header = ["展會", "姓名", "公司", "職稱", "電話", "Email", "LINE ID", "熱度", "狀態", "語音備註", "建立時間", "跟進日"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"

        var rows: [String] = [header.map(field).joined(separator: ",")]
        let sorted = event.contacts.sorted { $0.createdAt < $1.createdAt }
        for contact in sorted {
            let row = [
                event.name,
                contact.name,
                contact.company,
                contact.title,
                contact.phone,
                contact.email,
                contact.lineID,
                contact.heat.label,
                contact.status.label,
                contact.memoTranscript,
                dateFormatter.string(from: contact.createdAt),
                dateFormatter.string(from: contact.followUpDate),
            ]
            rows.append(row.map(field).joined(separator: ","))
        }

        let csv = "\u{FEFF}" + rows.joined(separator: "\r\n")
        let safeName = event.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(safeName)-跟進報表.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func field(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

import Foundation

struct ParsedCard {
    var name = ""
    var company = ""
    var title = ""
    var phone = ""
    var email = ""
    var lineID = ""
    var rawText = ""
}

/// 從 OCR 文字行猜測名片欄位。
/// 設計前提：OCR 永遠不會 100% 準，這裡只求「大致帶入」，由使用者在確認畫面快速修正。
enum CardFieldParser {

    private static let companyKeywords = [
        "有限公司", "股份有限公司", "企業", "集團", "工業", "科技", "實業", "貿易",
        "國際", "商行", "工作室", "事務所", "公司",
        "Co.", "Corp", "Inc", "Ltd", "LLC", "Company", "Enterprise", "Industrial",
    ]

    private static let titleKeywords = [
        "董事長", "執行長", "總經理", "副總", "協理", "處長", "廠長", "經理", "副理",
        "課長", "主任", "組長", "專員", "業務", "行銷", "採購", "顧問", "工程師", "設計師",
        "負責人", "創辦人", "特助",
        "CEO", "CTO", "COO", "CFO", "Founder", "President", "Director", "Manager",
        "Supervisor", "Specialist", "Sales", "Marketing", "Engineer", "Consultant",
    ]

    private static let noiseKeywords = [
        "http", "www.", "傳真", "Fax", "FAX", "地址", "Add", "ADD", "統編", "統一編號",
        "No.", "路", "街", "巷", "樓", "區", "市", "縣", "郵遞區號",
    ]

    static func parse(lines: [String]) -> ParsedCard {
        var card = ParsedCard()
        card.rawText = lines.joined(separator: "\n")
        var unclaimed: [String] = []

        for line in lines {
            // Email
            if card.email.isEmpty, let email = firstMatch(in: line, pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#) {
                card.email = email
                continue
            }
            // LINE ID
            if card.lineID.isEmpty, line.range(of: "line", options: .caseInsensitive) != nil {
                if let id = firstMatch(in: line, pattern: #"(?i)line\s*(?:id)?\s*[:：]?\s*@?([A-Za-z0-9._\-]{3,})"#, group: 1),
                   id.lowercased() != "id" {
                    card.lineID = id
                    continue
                }
            }
            // 電話（跳過傳真行）
            if line.range(of: "fax", options: .caseInsensitive) == nil, !line.contains("傳真") {
                if let phone = extractPhone(from: line) {
                    if card.phone.isEmpty || (phone.hasPrefix("09") && !card.phone.hasPrefix("09")) {
                        card.phone = phone
                        continue
                    }
                }
            }
            // 公司
            if card.company.isEmpty, companyKeywords.contains(where: { line.contains($0) }) {
                card.company = line
                continue
            }
            // 職稱
            if card.title.isEmpty, titleKeywords.contains(where: { line.contains($0) }), line.count <= 15 {
                card.title = line
                continue
            }
            // 雜訊（網址、地址等）不列入姓名候選
            if noiseKeywords.contains(where: { line.contains($0) }) { continue }
            unclaimed.append(line)
        }

        card.name = guessName(from: unclaimed)
        return card
    }

    /// 姓名：優先取 2–4 個中文字的短行，否則取第一個未分類的短行
    private static func guessName(from candidates: [String]) -> String {
        if let cjkName = candidates.first(where: { isLikelyCJKName($0) }) {
            return cjkName
        }
        return candidates.first { $0.count >= 2 && $0.count <= 30 && !$0.allSatisfy(\.isNumber) } ?? ""
    }

    private static func isLikelyCJKName(_ line: String) -> Bool {
        let trimmed = line.replacingOccurrences(of: " ", with: "")
        guard (2...4).contains(trimmed.count) else { return false }
        return trimmed.unicodeScalars.allSatisfy { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func extractPhone(from line: String) -> String? {
        guard let raw = firstMatch(in: line, pattern: #"(\+?886[\s\-]?\d|0\d)[\d\s\-()#]{6,}"#) else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        let digits = cleaned.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        return cleaned
    }

    private static func firstMatch(in text: String, pattern: String, group: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > group,
              let matchRange = Range(match.range(at: group), in: text) else { return nil }
        return String(text[matchRange])
    }
}

import Foundation

/// 範本變數帶入：{姓名}{公司}{職稱}{展會名}
enum TemplateEngine {
    static let availableVariables = ["{姓名}", "{公司}", "{職稱}", "{展會名}"]

    static func render(_ template: String, contact: Contact, event: Event?) -> String {
        template
            .replacingOccurrences(of: "{姓名}", with: contact.name.isEmpty ? "您" : contact.name)
            .replacingOccurrences(of: "{公司}", with: contact.company.isEmpty ? "貴公司" : contact.company)
            .replacingOccurrences(of: "{職稱}", with: contact.title)
            .replacingOccurrences(of: "{展會名}", with: event?.name ?? "展會")
    }
}

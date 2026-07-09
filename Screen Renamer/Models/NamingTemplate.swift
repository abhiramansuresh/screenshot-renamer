import Foundation

enum NamingField: String, Codable, CaseIterable, Identifiable, Hashable {
    case app
    case windowTitle
    case tabName
    case domain
    case documentName
    case ocrDocument
    case date
    case time

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: return "App Name"
        case .windowTitle: return "Window Title"
        case .tabName: return "Tab / Page"
        case .domain: return "Website Domain"
        case .documentName: return "Document Name"
        case .ocrDocument: return "Visible File (OCR)"
        case .date: return "Date"
        case .time: return "Time"
        }
    }

    var subtitle: String {
        switch self {
        case .app: return "Active app (e.g. Chrome, Xcode, Figma)"
        case .windowTitle: return "Best available title for this screenshot"
        case .tabName: return "Browser tab or panel name"
        case .domain: return "Website domain (e.g. github, figma)"
        case .documentName: return "Open document from the title bar"
        case .ocrDocument: return "Filename visible anywhere on screen"
        case .date: return "Capture date (e.g. 2026-06-24)"
        case .time: return "Capture time (e.g. 14-33)"
        }
    }

    var exampleValue: String {
        switch self {
        case .app: return "Chrome"
        case .windowTitle: return "Design_Review"
        case .tabName: return "Dashboard"
        case .domain: return "figma"
        case .documentName: return "ProjectPlan"
        case .ocrDocument: return "Notes"
        case .date: return "2026-06-24"
        case .time: return "14-33"
        }
    }
}

struct NamingTemplate: Codable, Equatable {
    var fields: [NamingField]
    var separator: String
    var prefix: String
    var suffix: String

    static let userDefaultsKey = "NamingTemplate_v1"

    static let `default` = NamingTemplate(
        fields: [.app, .windowTitle],
        separator: "_",
        prefix: "",
        suffix: ""
    )

    static var stored: NamingTemplate {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let template = try? JSONDecoder().decode(NamingTemplate.self, from: data) else {
            return .default
        }
        return template
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: NamingTemplate.userDefaultsKey)
    }
}

import Foundation

struct Clip: Codable, Identifiable, Equatable {
    let filename: String
    let createdAt: Date

    var id: String { filename }

    /// Description embedded after the 4th dash in the filename, hyphens displayed as spaces.
    /// e.g. "2026-20-03-1742482800-cool-riff.m4a" → "cool riff"
    var description: String? {
        let base = (filename as NSString).deletingPathExtension
        let parts = base.components(separatedBy: "-")
        guard parts.count > 4 else { return nil }
        let raw = parts.dropFirst(4).joined(separator: "-")
        return raw.isEmpty ? nil : raw.replacingOccurrences(of: "-", with: " ")
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: createdAt)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: createdAt)
    }

    var formattedDay: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: createdAt)
    }
}

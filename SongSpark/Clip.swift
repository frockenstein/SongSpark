import Foundation

struct Clip: Codable, Identifiable, Equatable {
    let filename: String
    let createdAt: Date
    var tags: [String]

    var id: String { filename }

    init(filename: String, createdAt: Date = Date(), tags: [String] = []) {
        self.filename = filename
        self.createdAt = createdAt
        self.tags = tags
    }

    // Custom decoder so older JSON without a "tags" key decodes gracefully.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        filename  = try c.decode(String.self,  forKey: .filename)
        createdAt = try c.decode(Date.self,    forKey: .createdAt)
        tags      = (try? c.decode([String].self, forKey: .tags)) ?? []
    }

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

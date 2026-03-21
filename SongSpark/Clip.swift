import Foundation

struct Clip: Codable, Identifiable, Equatable {
    let filename: String
    let createdAt: Date

    var id: String { filename }

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

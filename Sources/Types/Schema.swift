import Foundation

struct Todo: Identifiable, Equatable, Hashable {
    let id: Int64

    var title: String
    var description: String?
    var completed: Bool
    var priority: Int
    var createdAt: Int64
    var updatedAt: Int64
}

struct Tag: Identifiable, Equatable, Hashable {
    let id: Int64
    let name: String
}

struct TodoTag: Hashable {
    let todoID: Int64
    let tagID: Int64
}

extension Todo {
    init(
        title: String,
        description: String? = nil,
        priority: Int = 0,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.id = 0
        self.title = title
        self.description = description
        self.completed = false
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TimeInterval {
    fileprivate var int64: Int64 { Int64(self) }
}

extension Bool {
    init(sqliteInt value: Int64) {
        self = value != 0
    }

    var sqliteInt: Int64 {
        self ? 1 : 0
    }
}

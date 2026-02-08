@preconcurrency import Foundation
import SQLite3

struct Helpers {
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func prompt(_ message: String) -> String {
        print(message, terminator: " ")
        return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func exitWithError(_ message: String) -> Never {
        fputs("error: \(message)\n", stderr)
        exit(1)
    }

    static func getOrCreateTag(named name: String) -> Int64 {
        let db = TodoDatabase.shared

        let select = "SELECT id FROM tag WHERE name = ?;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db.db, select, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            sqlite3_finalize(stmt)
            return id
        }
        sqlite3_finalize(stmt)

        let insert = "INSERT INTO tag (name) VALUES (?);"
        sqlite3_prepare_v2(db.db, insert, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            sqlite3_finalize(stmt)
            exitWithError("failed to create tag")
        }

        sqlite3_finalize(stmt)
        return sqlite3_last_insert_rowid(db.db)
    }

    static func attachTag(todoID: Int64, tagID: Int64) {
        let sql = "INSERT OR IGNORE INTO todo_tag (todo_id, tag_id) VALUES (?, ?);"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(TodoDatabase.shared.db, sql, -1, &stmt, nil)
        sqlite3_bind_int64(stmt, 1, todoID)
        sqlite3_bind_int64(stmt, 2, tagID)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    static func searchTodos(query: String) -> [Todo] {
        let sql = """
            SELECT id, title, description, completed, priority, created_at, updated_at
            FROM todo
            WHERE title LIKE ? OR description LIKE ?
            ORDER BY created_at DESC;
            """

        let pattern = "%\(query)%"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(TodoDatabase.shared.db, sql, -1, &stmt, nil)

        sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, pattern, -1, SQLITE_TRANSIENT)

        var results: [Todo] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(
                Todo(
                    id: sqlite3_column_int64(stmt, 0),
                    title: String(cString: sqlite3_column_text(stmt, 1)),
                    description: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                    completed: Bool(sqliteInt: sqlite3_column_int64(stmt, 3)),
                    priority: Int(sqlite3_column_int(stmt, 4)),
                    createdAt: sqlite3_column_int64(stmt, 5),
                    updatedAt: sqlite3_column_int64(stmt, 6)
                )
            )
        }

        sqlite3_finalize(stmt)
        return results
    }
}

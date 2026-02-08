import Foundation
import SQLite3

// Thread-safe singleton managing the SQLite database for TODO items
final class TodoDatabase: @unchecked Sendable {
    static let shared = TodoDatabase()
    private(set) var db: OpaquePointer?
    private let dbPath: String

    private let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        self.dbPath = Self.resolveDatabasePath()
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    private static func resolveDatabasePath() -> String {
        let fileManager = FileManager.default
        let homeURL = fileManager.homeDirectoryForCurrentUser

        let dataFolder =
            homeURL
            .appendingPathComponent(".local")
            .appendingPathComponent("share")
            .appendingPathComponent("todo")

        try? fileManager.createDirectory(
            at: dataFolder,
            withIntermediateDirectories: true
        )

        return dataFolder.appendingPathComponent("todo.sqlite").path
    }

    private func openDatabase() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            fatalError("Unable to open database at \(dbPath)")
        }
    }

    private func createTables() {
        let createTodo = """
            CREATE TABLE IF NOT EXISTS todo (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                title         TEXT NOT NULL,
                description   TEXT,
                completed     INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
                priority      INTEGER NOT NULL DEFAULT 0,
                created_at    INTEGER NOT NULL,
                updated_at    INTEGER NOT NULL
            );
            """

        let createTag = """
            CREATE TABLE IF NOT EXISTS tag (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE
            );
            """

        let createTodoTag = """
            CREATE TABLE IF NOT EXISTS todo_tag (
                todo_id INTEGER NOT NULL,
                tag_id  INTEGER NOT NULL,
                PRIMARY KEY (todo_id, tag_id),
                FOREIGN KEY (todo_id) REFERENCES todo(id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id)  REFERENCES tag(id)  ON DELETE CASCADE
            );
            """

        execute(createTodo)
        execute(createTag)
        execute(createTodoTag)
    }

    private func execute(_ sql: String) {
        var errorMessage: UnsafeMutablePointer<Int8>?

        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = String(cString: errorMessage!)
            sqlite3_free(errorMessage)
            fatalError("SQLite error: \(message)")
        }
    }

    func insert(todo: Todo) -> Int64 {
        let sql = """
            INSERT INTO todo (title, description, completed, priority, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare insert statement")
        }

        sqlite3_bind_text(statement, 1, todo.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, todo.description, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 3, todo.completed.sqliteInt)
        sqlite3_bind_int(statement, 4, Int32(todo.priority))
        sqlite3_bind_int64(statement, 5, todo.createdAt)
        sqlite3_bind_int64(statement, 6, todo.updatedAt)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            fatalError("Failed to insert todo")
        }

        return sqlite3_last_insert_rowid(db)
    }

    func listTodos() -> [Todo] {
        let sql = """
            SELECT id, title, description, completed, priority, created_at, updated_at
            FROM todo
            ORDER BY created_at DESC;
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare list statement")
        }

        var todos: [Todo] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            todos.append(parseTodo(from: statement!))
        }

        return todos
    }

    func search(query: String) -> [Todo] {
        let sql = """
            SELECT id, title, description, completed, priority, created_at, updated_at
            FROM todo
            WHERE title LIKE ? OR description LIKE ?
            ORDER BY created_at DESC;
            """

        let pattern = "%\(query)%"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare search statement")
        }

        sqlite3_bind_text(statement, 1, pattern, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, pattern, -1, SQLITE_TRANSIENT)

        var todos: [Todo] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            todos.append(parseTodo(from: statement!))
        }

        return todos
    }

    func update(id: Int64, completed: Bool) {
        let sql = """
            UPDATE todo
            SET completed = ?, updated_at = ?
            WHERE id = ?;
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare update statement")
        }

        sqlite3_bind_int64(statement, 1, completed.sqliteInt)
        sqlite3_bind_int64(statement, 2, Int64(Date().timeIntervalSince1970))
        sqlite3_bind_int64(statement, 3, id)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            fatalError("Failed to update todo")
        }
    }

    func delete(id: Int64) {
        let sql = "DELETE FROM todo WHERE id = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare delete statement")
        }

        sqlite3_bind_int64(statement, 1, id)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            fatalError("Failed to delete todo")
        }
    }

    func findOrCreateTag(name: String) -> Int64 {
        // Try to find existing tag
        if let existingID = findTag(name: name) {
            return existingID
        }

        // Create new tag
        return createTag(name: name)
    }

    func attachTag(todoID: Int64, tagID: Int64) {
        let sql = "INSERT OR IGNORE INTO todo_tag (todo_id, tag_id) VALUES (?, ?);"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare attach tag statement")
        }

        sqlite3_bind_int64(statement, 1, todoID)
        sqlite3_bind_int64(statement, 2, tagID)

        sqlite3_step(statement)
    }

    private func findTag(name: String) -> Int64? {
        let sql = "SELECT id FROM tag WHERE name = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        }

        return nil
    }

    private func createTag(name: String) -> Int64 {
        let sql = "INSERT INTO tag (name) VALUES (?);"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("Failed to prepare create tag statement")
        }

        sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            fatalError("Failed to create tag")
        }

        return sqlite3_last_insert_rowid(db)
    }

    func getTag(forTodoId todoId: Int64) -> String? {
        let sql = """
            SELECT tg.name
            FROM tag tg
            JOIN todo_tag tt ON tt.tag_id = tg.id
            WHERE tt.todo_id = ?
            LIMIT 1;
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        sqlite3_bind_int64(statement, 1, todoId)

        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                return String(cString: cString)
            }
        }

        return nil
    }

    func listTodos(forTagId tagId: Int64) -> [Todo] {
        let sql = """
            SELECT
                t.id,
                t.title,
                t.description,
                t.completed,
                t.priority,
                t.created_at,
                t.updated_at
            FROM todo t
            JOIN todo_tag tt ON tt.todo_id = t.id
            WHERE tt.tag_id = ?
            ORDER BY t.updated_at DESC;
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        sqlite3_bind_int64(statement, 1, tagId)

        var todos: [Todo] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let todo = Todo(
                id: sqlite3_column_int64(statement, 0),
                title: String(cString: sqlite3_column_text(statement, 1)),
                description: sqlite3_column_text(statement, 2).map { String(cString: $0) },
                completed: sqlite3_column_int(statement, 3) == 1,
                priority: Int(sqlite3_column_int(statement, 4)),
                createdAt: sqlite3_column_int64(statement, 5),
                updatedAt: sqlite3_column_int64(statement, 6)
            )

            todos.append(todo)
        }

        return todos
    }

    func listAllTags() -> [Tag] {
        let sql = "SELECT id, name FROM tag ORDER BY name;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        var tags: [Tag] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)

            if let cString = sqlite3_column_text(statement, 1) {
                let name = String(cString: cString)
                tags.append(Tag(id: id, name: name))
            }
        }

        return tags
    }

    private func parseTodo(from statement: OpaquePointer) -> Todo {
        return Todo(
            id: sqlite3_column_int64(statement, 0),
            title: String(cString: sqlite3_column_text(statement, 1)),
            description: sqlite3_column_text(statement, 2).map { String(cString: $0) },
            completed: Bool(sqliteInt: sqlite3_column_int64(statement, 3)),
            priority: Int(sqlite3_column_int(statement, 4)),
            createdAt: sqlite3_column_int64(statement, 5),
            updatedAt: sqlite3_column_int64(statement, 6)
        )
    }
}

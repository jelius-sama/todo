import Foundation
import SQLite3

final class TodoDatabase: @unchecked Sendable {
    let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static let shared = TodoDatabase()
    var db: OpaquePointer?

    private let dbPath: String = {
        let fileManager = FileManager.default

        // Resolve the current user's home directory (e.g., /home/user or /Users/user)
        let homeURL = fileManager.homeDirectoryForCurrentUser

        // Build the specific path: ~/.local/share/todo/
        let dataFolder =
            homeURL
            .appendingPathComponent(".local")
            .appendingPathComponent("share")
            .appendingPathComponent("todo")

        // Ensure the folder exists before returning the file path
        try? fileManager.createDirectory(at: dataFolder, withIntermediateDirectories: true)

        // Return the full string path to the database file
        return dataFolder.appendingPathComponent("todo.sqlite").path
    }()

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
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
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = String(cString: err!)
            sqlite3_free(err)
            fatalError("SQLite error: \(message)")
        }
    }

    func insert(todo: Todo) -> Int64 {
        let sql = """
            INSERT INTO todo (title, description, completed, priority, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)

        sqlite3_bind_text(stmt, 1, todo.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, todo.description, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 3, todo.completed.sqliteInt)
        sqlite3_bind_int(stmt, 4, Int32(todo.priority))
        sqlite3_bind_int64(stmt, 5, todo.createdAt)
        sqlite3_bind_int64(stmt, 6, todo.updatedAt)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            sqlite3_finalize(stmt)
            fatalError("Failed to insert todo")
        }

        sqlite3_finalize(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func listTodos() -> [Todo] {
        let sql = """
            SELECT id, title, description, completed, priority, created_at, updated_at
            FROM todo
            ORDER BY created_at DESC;
            """

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)

        var todos: [Todo] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let todo = Todo(
                id: sqlite3_column_int64(stmt, 0),
                title: String(cString: sqlite3_column_text(stmt, 1)),
                description: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                completed: Bool(sqliteInt: sqlite3_column_int64(stmt, 3)),
                priority: Int(sqlite3_column_int(stmt, 4)),
                createdAt: sqlite3_column_int64(stmt, 5),
                updatedAt: sqlite3_column_int64(stmt, 6)
            )
            todos.append(todo)
        }

        sqlite3_finalize(stmt)
        return todos
    }

    func markTodo(id: Int64, completed: Bool) {
        let sql = """
            UPDATE todo
            SET completed = ?, updated_at = ?
            WHERE id = ?;
            """

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)

        sqlite3_bind_int64(stmt, 1, completed.sqliteInt)
        sqlite3_bind_int64(stmt, 2, Int64(Date().timeIntervalSince1970))
        sqlite3_bind_int64(stmt, 3, id)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            sqlite3_finalize(stmt)
            fatalError("Failed to update todo")
        }

        sqlite3_finalize(stmt)
    }

    func deleteTodo(id: Int64) {
        let sql = "DELETE FROM todo WHERE id = ?;"

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_int64(stmt, 1, id)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            sqlite3_finalize(stmt)
            fatalError("Failed to delete todo")
        }

        sqlite3_finalize(stmt)
    }
}

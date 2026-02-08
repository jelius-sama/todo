@preconcurrency import Foundation

// Utility functions for CLI interactions and todo operations
struct ClientHelpers {
    private static let database: TodoDatabase = .shared

    static func prompt(_ message: String) -> String {
        print("\(Colors.bold)\(Colors.cyan)\(message)\(Colors.reset)", terminator: " ")
        return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func exitWithError(_ message: String) -> Never {
        fputs("\(Colors.bold)\(Colors.red)error: \(message)\(Colors.reset)\n", stderr)
        exit(1)
    }

    static func getOrCreateTag(named name: String) -> Int64 {
        return database.findOrCreateTag(name: name)
    }

    static func attachTag(todoID: Int64, tagID: Int64) {
        database.attachTag(todoID: todoID, tagID: tagID)
    }

    static func searchTodos(query: String) -> [Todo] {
        return database.search(query: query)
    }

    static func selectTodoID(from matches: [Todo], action: String) -> Int64 {
        guard !matches.isEmpty else {
            exitWithError("no TODOs found")
        }

        prettyPrintTodos(todos: matches)

        let input = prompt("\nEnter TODO ID to \(action):")

        guard let id = Int64(input) else {
            exitWithError("invalid ID")
        }

        return id
    }

    static func prettyPrintTodos(todos: [Todo]) {
        let doneWidth = 4
        let idWidth = 3
        let gap = 2

        let prefixWidth = doneWidth + gap + idWidth + gap

        print("\(Colors.bold)\(Colors.cyan)Done  ID   Title\(Colors.reset)")
        print("\(Colors.gray)----  ---  -----\(Colors.reset)")

        for todo in todos {
            let rawCheckbox = todo.completed ? "✓" : " "
            let paddedCheckbox = rawCheckbox.padding(
                toLength: doneWidth,
                withPad: " ",
                startingAt: 0
            )

            let coloredCheckbox =
                todo.completed
                ? "\(Colors.green)\(paddedCheckbox)\(Colors.reset)"
                : paddedCheckbox

            let idString = String(format: "%-3d", todo.id)

            print(
                coloredCheckbox
                    + String(repeating: " ", count: gap)
                    + "\(Colors.blue)\(idString)\(Colors.reset)"
                    + String(repeating: " ", count: gap)
                    + todo.title
            )

            if let description = todo.description {
                print(
                    String(repeating: " ", count: prefixWidth)
                        + "\(Colors.dim)\(description)\(Colors.reset)"
                )
            }
        }
    }
}

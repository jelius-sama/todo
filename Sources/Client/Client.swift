// CLI client for managing TODO items
struct Client {
    public enum CompletionStatus: String, CaseIterable {
        case yes
        case no

        var isCompleted: Bool {
            self == .yes
        }
    }

    private static let database: TodoDatabase = .shared

    static func AddTodo(
        title: String,
        description: String,
        priority: Int?,
        tag: String?
    ) {
        validatePriority(priority)

        let finalPriority = priority ?? 0
        let tagName = tag ?? promptForTag()

        let todo = Todo(
            title: title,
            description: description.isEmpty ? nil : description,
            priority: finalPriority
        )

        let todoID = database.insert(todo: todo)

        if let name = tagName {
            attachTagToTodo(todoID: todoID, tagName: name)
        }

        print("\(Colors.bold)\(Colors.green)✓ Added TODO #\(todoID): \(title)\(Colors.reset)")
    }

    static func MarkTodo(query: String, status: CompletionStatus) {
        let matches = ClientHelpers.searchTodos(query: query)

        guard !matches.isEmpty else {
            ClientHelpers.exitWithError("no TODOs found matching '\(query)'")
        }

        let id = ClientHelpers.selectTodoID(from: matches, action: "mark")

        database.update(id: id, completed: status.isCompleted)

        let statusText = status.isCompleted ? "completed" : "not completed"
        print("\(Colors.bold)\(Colors.green)✓ TODO #\(id) marked as \(statusText)\(Colors.reset)")
    }

    static func ListTodos() {
        let todos = database.listTodos()

        if todos.isEmpty {
            print("\(Colors.bold)\(Colors.red)No TODOs found.\(Colors.reset)")
            return
        }

        ClientHelpers.prettyPrintTodos(todos: todos)
    }

    static func DeleteTodo(query: String) {
        let matches = ClientHelpers.searchTodos(query: query)

        guard !matches.isEmpty else {
            ClientHelpers.exitWithError("no TODOs found matching '\(query)'")
        }

        let id = ClientHelpers.selectTodoID(from: matches, action: "delete")

        database.delete(id: id)

        print("\(Colors.bold)\(Colors.green)✓ TODO #\(id) deleted\(Colors.reset)")
    }

    private static func validatePriority(_ priority: Int?) {
        if let p = priority, !(1...10).contains(p) {
            ClientHelpers.exitWithError("priority must be between 1 and 10")
        }
    }

    private static func promptForTag() -> String? {
        let answer = ClientHelpers.prompt(
            "Would you like to add a tag? \(Colors.reset)\(Colors.dim)(y/N)"
        ).lowercased()

        guard answer == "y" || answer == "yes" else {
            return nil
        }

        let name = ClientHelpers.prompt(
            "Enter tag name \(Colors.reset)\(Colors.dim)(will be created if does not already exist):"
        )

        return name.isEmpty ? nil : name
    }

    private static func attachTagToTodo(todoID: Int64, tagName: String) {
        let tagID = ClientHelpers.getOrCreateTag(named: tagName)
        ClientHelpers.attachTag(todoID: todoID, tagID: tagID)
    }
}

struct Client {
    public enum Completed: String, CaseIterable {
        case yes = "yes"
        case no = "no"
    }

    static func AddTodo(
        title: String,
        desc: String,
        priority: Optional<Int>,
        tag: Optional<String>
    ) {
        if let p = priority, !(1...10).contains(p) {
            Helpers.exitWithError("priority must be between 1 and 10")
        }

        let finalPriority = priority ?? 0
        var tagName = tag

        if tagName == nil {
            let answer = Helpers.prompt("Add a tag? (y/N)").lowercased()
            if answer == "y" || answer == "yes" {
                let name = Helpers.prompt("Tag name:")
                if !name.isEmpty {
                    tagName = name
                }
            }
        }

        let todo = Todo(
            title: title,
            description: desc.isEmpty ? nil : desc,
            priority: finalPriority
        )

        let todoID = TodoDatabase.shared.insert(todo: todo)

        if let name = tagName {
            let tagID = Helpers.getOrCreateTag(named: name)
            Helpers.attachTag(todoID: todoID, tagID: tagID)
        }

        print("✓ Added TODO #\(todoID): \(title)")
    }

    static func MarkTodo(query: String, completed: Completed) {
        let matches = Helpers.searchTodos(query: query)

        guard !matches.isEmpty else {
            Helpers.exitWithError("no TODOs found matching '\(query)'")
        }

        for todo in matches {
            print("[\(todo.id)] \(todo.title)")
        }

        let input = Helpers.prompt("Enter TODO ID to mark:")
        guard let id = Int64(input) else {
            Helpers.exitWithError("invalid ID")
        }

        let done = completed == .yes
        TodoDatabase.shared.markTodo(id: id, completed: done)

        print("✓ TODO #\(id) marked as \(done ? "completed" : "not completed")")
    }

    static func ListTodo() {
        let todos = TodoDatabase.shared.listTodos()

        if todos.isEmpty {
            print("No TODOs found.")
            return
        }

        for todo in todos {
            let status = todo.completed ? "✓" : " "
            print("[\(status)] \(todo.id): \(todo.title)")
        }
    }

    static func DeleteTodo(query: String) {
        let matches = Helpers.searchTodos(query: query)

        guard !matches.isEmpty else {
            Helpers.exitWithError("no TODOs found matching '\(query)'")
        }

        for todo in matches {
            print("[\(todo.id)] \(todo.title)")
        }

        let input = Helpers.prompt("Enter TODO ID to delete:")
        guard let id = Int64(input) else {
            Helpers.exitWithError("invalid ID")
        }

        TodoDatabase.shared.deleteTodo(id: id)
        print("✓ TODO #\(id) deleted")
    }
}

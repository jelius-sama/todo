struct Client {
    public enum Completed: String, CaseIterable {
        case yes = "yes"
        case no = "no"
    }

    static func AddTodo(title: String, desc: String, priority: Optional<Int>, tag: Optional<String>)
    {
        // Support: (normalize quotes)
        // todo add "Hello World"
        // todo add Hello World
        // Just add to the database
    }

    static func MarkTodo(query: String, completed: Completed) {

    }

    static func ListTodo() {

    }

    static func DeleteTodo(query: String) {

    }
}

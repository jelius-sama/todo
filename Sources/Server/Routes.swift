import Foundation

enum APIRouter {
    private static let router = Router()
    private static let database: TodoDatabase = .shared

    static var shared: Router {
        return router
    }

    static func registerRoutes() {
        router.get("/") { _ in
            do {
                guard
                    let url = Bundle.module.url(
                        forResource: "index",
                        withExtension: "html",
                        subdirectory: "Assets"
                    )
                else {
                    throw APIError.internalError
                }

                let html = try String(contentsOf: url, encoding: .utf8)
                return HTTPResponse.html(html)
            } catch {
                return HTTPResponse.text(
                    "index.html not found",
                    status: .internalServerError
                )
            }
        }

        router.get("/version") { _ in
            .text(VERSION)
        }

        // Health check
        router.get("/health") { _ in
            struct HealthResponse: Codable {
                let status: String
                let timestamp: Double
            }

            let response = HealthResponse(
                status: "ok",
                timestamp: Date().timeIntervalSince1970
            )

            return .json(response)
        }

        // GET /api/todos - List all todos
        router.get("/api/todos") { _ in
            let todos = database.listTodos()
            return .json(todos.map(todoToResponse))
        }

        // GET /api/tags
        router.get("/api/tags") { _ in
            return .json(database.listAllTags())
        }

        // GET /api/tags/:id/todos
        router.get("/api/tags/:id/todos") { req in
            guard let idString = req.pathParams["id"],
                let tagId = Int64(idString)
            else {
                throw APIError.badRequest("Invalid tag ID")
            }

            let todos = database.listTodos(forTagId: tagId)
            return .json(todos.map(todoToResponse))
        }

        // GET /api/todos/:id - Get single todo
        router.get("/api/todos/:id") { req in
            guard let idString = req.pathParams["id"],
                let id = Int64(idString)
            else {
                throw APIError.badRequest("Invalid todo ID")
            }

            let todos = database.listTodos()
            guard let todo = todos.first(where: { $0.id == id }) else {
                throw APIError.notFound
            }

            return .json(todoToResponse(todo))
        }

        // POST /api/todos - Create new todo
        router.post("/api/todos") { req in
            struct CreateTodoRequest: Codable {
                let title: String
                let description: String?
                let priority: Int?
                let tag: String?
            }

            let payload = try req.decode(CreateTodoRequest.self)

            // Validate title
            guard !payload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.badRequest("Title cannot be empty")
            }

            // Validate priority
            if let priority = payload.priority, !(1...10).contains(priority) {
                throw APIError.badRequest("Priority must be between 1 and 10")
            }

            let finalPriority = payload.priority ?? 0

            let todo = Todo(
                title: payload.title,
                description: payload.description?.isEmpty == false ? payload.description : nil,
                priority: finalPriority
            )

            let todoID = database.insert(todo: todo)

            // Handle tag if provided
            if let tagName = payload.tag?.trimmingCharacters(in: .whitespacesAndNewlines),
                !tagName.isEmpty
            {
                let tagID = ClientHelpers.getOrCreateTag(named: tagName)
                ClientHelpers.attachTag(todoID: todoID, tagID: tagID)
            }

            // Fetch the created todo to return
            let todos = database.listTodos()
            guard let createdTodo = todos.first(where: { $0.id == todoID }) else {
                throw APIError.internalError
            }

            return .json(todoToResponse(createdTodo), status: .created)
        }

        // PATCH /api/todos/:id/complete - Mark as complete
        router.patch("/api/todos/:id/complete") { req in
            guard let idString = req.pathParams["id"],
                let id = Int64(idString)
            else {
                throw APIError.badRequest("Invalid todo ID")
            }

            let todos = database.listTodos()
            guard todos.first(where: { $0.id == id }) != nil else {
                throw APIError.notFound
            }

            database.update(id: id, completed: true)

            let updatedTodos = database.listTodos()
            guard let updatedTodo = updatedTodos.first(where: { $0.id == id }) else {
                throw APIError.internalError
            }

            return .json(todoToResponse(updatedTodo))
        }

        // PATCH /api/todos/:id/uncomplete - Mark as incomplete
        router.patch("/api/todos/:id/uncomplete") { req in
            guard let idString = req.pathParams["id"],
                let id = Int64(idString)
            else {
                throw APIError.badRequest("Invalid todo ID")
            }

            let todos = database.listTodos()
            guard todos.first(where: { $0.id == id }) != nil else {
                throw APIError.notFound
            }

            database.update(id: id, completed: false)

            let updatedTodos = database.listTodos()
            guard let updatedTodo = updatedTodos.first(where: { $0.id == id }) else {
                throw APIError.internalError
            }

            return .json(todoToResponse(updatedTodo))
        }

        // DELETE /api/todos/:id - Delete todo
        router.delete("/api/todos/:id") { req in
            guard let idString = req.pathParams["id"],
                let id = Int64(idString)
            else {
                throw APIError.badRequest("Invalid todo ID")
            }

            let todos = database.listTodos()
            guard todos.first(where: { $0.id == id }) != nil else {
                throw APIError.notFound
            }

            database.delete(id: id)

            struct DeleteResponse: Codable {
                let success: Bool
                let id: Int64
            }

            return .json(DeleteResponse(success: true, id: id))
        }

        // GET /api/todos/search - Search todos
        router.get("/api/todos/search/:id") { req in
            if let query = req.pathParams["id"] {
                let results = ClientHelpers.searchTodos(query: query)
                return .json(results.map(todoToResponse))
            } else {
                throw APIError.badRequest("Search query not provided")
            }
        }

        // GET /api/stats - Get statistics
        router.get("/api/stats") { _ in
            struct Stats: Codable {
                let total: Int
                let completed: Int
                let active: Int
                let highPriority: Int
                let mediumPriority: Int
                let lowPriority: Int
            }

            let todos = database.listTodos()

            let stats = Stats(
                total: todos.count,
                completed: todos.filter { $0.completed }.count,
                active: todos.filter { !$0.completed }.count,
                highPriority: todos.filter { $0.priority >= 7 }.count,
                mediumPriority: todos.filter { $0.priority >= 4 && $0.priority < 7 }.count,
                lowPriority: todos.filter { $0.priority > 0 && $0.priority < 4 }.count
            )

            return .json(stats)
        }

        // GET /api/todos/filter/completed - Get completed todos
        router.get("/api/todos/filter/completed") { _ in
            let todos = database.listTodos().filter { $0.completed }
            return .json(todos.map(todoToResponse))
        }

        // GET /api/todos/filter/active - Get active todos
        router.get("/api/todos/filter/active") { _ in
            let todos = database.listTodos().filter { !$0.completed }
            return .json(todos.map(todoToResponse))
        }

        // GET /api/todos/filter/priority/:level - Get todos by priority level
        router.get("/api/todos/filter/priority/:level") { req in
            guard let level = req.pathParams["level"] else {
                throw APIError.badRequest("Missing priority level")
            }

            let todos = database.listTodos()
            let filtered: [Todo]

            switch level.lowercased() {
            case "high":
                filtered = todos.filter { $0.priority >= 7 }
            case "medium":
                filtered = todos.filter { $0.priority >= 4 && $0.priority < 7 }
            case "low":
                filtered = todos.filter { $0.priority > 0 && $0.priority < 4 }
            default:
                throw APIError.badRequest("Invalid priority level. Use: high, medium, or low")
            }

            return .json(filtered.map(todoToResponse))
        }
    }

    private struct TodoResponse: Identifiable, Equatable, Hashable, Codable {
        let id: Int64
        let title: String
        let description: String?
        let completed: Bool
        let priority: Int
        let createdAt: Int64
        let updatedAt: Int64
        let tag: String?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case description
            case completed
            case priority
            case createdAt
            case updatedAt
            case tag
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(completed, forKey: .completed)
            try container.encode(priority, forKey: .priority)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(updatedAt, forKey: .updatedAt)

            if let tag = tag {
                try container.encode(tag, forKey: .tag)
            } else {
                try container.encodeNil(forKey: .tag)
            }
        }
    }

    private static func todoToResponse(
        _ todo: Todo,
    ) -> TodoResponse {
        TodoResponse(
            id: todo.id,
            title: todo.title,
            description: todo.description,
            completed: todo.completed,
            priority: todo.priority,
            createdAt: todo.createdAt,
            updatedAt: todo.updatedAt,
            tag: todo.tag,
        )
    }

    /// Must be called once at startup
    static func InitRouter() {
        registerRoutes()
        router.freeze()
    }
}

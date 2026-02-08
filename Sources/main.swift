import NIO

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#else
    #error("Unsupported platform")
#endif

let VERSION = "1.0.0"

@main
struct Entry {
    static func main() {
        if CommandLine.arguments.count > 1 {
            switch CommandLine.arguments[1] {
            case "--help", "-help", "--h", "-h":
                printHelp(status: 0)

            case "--version", "-version", "--v", "-v":
                printVersion()

            case "server":
                server()

            case "list", "l":
                Client.ListTodos()

            case "sync", "s":
                sync()

            case "add", "a":
                // Required minimum of 6 arguments.
                if CommandLine.arguments.count < 6 {
                    printHelp(status: 1)
                }

                var title: String? = nil
                var desc: String? = nil
                var priority: Int? = nil
                var tag: String? = nil

                var fIndex = 2
                while fIndex < CommandLine.arguments.count {
                    let arg = CommandLine.arguments[fIndex]

                    // Safety: Ensure there is a value after the flag
                    guard fIndex + 1 < CommandLine.arguments.count else {
                        printHelp(status: 1)
                    }
                    let value = CommandLine.arguments[fIndex + 1]

                    switch arg {
                    case "-title", "--title", "-t", "--t":
                        title = value
                        fIndex += 2
                    case "-description", "--description", "-d", "--d", "-desc", "--desc":
                        desc = value
                        fIndex += 2
                    case "-priority", "--priority", "-p", "--p":
                        priority = Int(value)
                        fIndex += 2
                    case "-tag", "--tag":
                        tag = value
                        fIndex += 2
                    default:
                        // Catch unknown flags or unquoted words
                        printHelp(status: 1)
                    }
                }

                if let title = title, let desc = desc {
                    Client.AddTodo(title: title, description: desc, priority: priority, tag: tag)
                } else {
                    printHelp(status: 1)
                }

            case "mark", "m":
                // Required minimum of 6 arguments.
                if CommandLine.arguments.count < 6 {
                    printHelp(status: 1)
                }

                var mark: Client.CompletionStatus? = nil
                var query: String? = nil

                var fIndex = 2
                while fIndex < CommandLine.arguments.count {
                    let arg = CommandLine.arguments[fIndex]

                    // Safety: Ensure there is actually a "next" argument for the value
                    guard fIndex + 1 < CommandLine.arguments.count else {
                        printHelp(status: 1)
                    }

                    let value = CommandLine.arguments[fIndex + 1]

                    switch arg {
                    case "-c", "-completed", "--c", "--completed":
                        if value == "yes" {
                            mark = .yes
                        } else if value == "no" {
                            mark = .no
                        } else {
                            printHelp(status: 1)
                        }
                        fIndex += 2

                    case "-q", "-query", "--q", "--query":
                        query = value
                        fIndex += 2

                    default:
                        // This catches unknown flags or unquoted words that fall into the loop
                        printHelp(status: 1)
                    }
                }

                if let mark = mark, let query = query {
                    Client.MarkTodo(query: query, status: mark)
                } else {
                    printHelp(status: 1)
                }

            case "delete", "d":
                // Required minimum of 4 arguments.
                if CommandLine.arguments.count != 4 {
                    printHelp(status: 1)
                }
                switch CommandLine.arguments[2] {
                case "-q", "-query", "--q", "--query":
                    Client.DeleteTodo(query: CommandLine.arguments[3])
                default: printHelp(status: 1)
                }

            default:
                printHelp(status: 1)
            }
        } else {
            printHelp(status: 1)
        }
    }

    private static func printHelp(status: Int32) -> Never {
        print(
            """
            \(Colors.gray)\(Colors.bold)
             ████████╗ ██████╗ ██████╗  ██████╗ 
             ╚══██╔══╝██╔═══██╗██╔══██╗██╔═══██╗
                ██║   ██║   ██║██║  ██║██║   ██║
                ██║   ██║   ██║██║  ██║██║   ██║
                ██║   ╚██████╔╝██████╔╝╚██████╔╝
                ╚═╝    ╚═════╝ ╚═════╝  ╚═════╝ 
            \(Colors.reset)
            \(Colors.bold)Todo\(Colors.reset) — Terminal-based task manager with remote syncing.

            \(Colors.cyan)USAGE:\(Colors.reset)
              \(CommandLine.arguments[0]) <command> [args]

            \(Colors.cyan)COMMANDS:\(Colors.reset)
              \(Colors.green)add\(Colors.reset), \(Colors.green)a\(Colors.reset)      Add a task. \(Colors.dim)Requires -t and -d.\(Colors.reset)
              \(Colors.green)mark\(Colors.reset), \(Colors.green)m\(Colors.reset)     Update status. \(Colors.dim)Requires -q and -c.\(Colors.reset)
              \(Colors.green)delete\(Colors.reset), \(Colors.green)d\(Colors.reset)   Remove a task. \(Colors.dim)Requires -q.\(Colors.reset)
              \(Colors.green)list\(Colors.reset), \(Colors.green)l\(Colors.reset)     List all TODOs.
              \(Colors.green)sync\(Colors.reset), \(Colors.green)s\(Colors.reset)     Sync with remote server.
              \(Colors.green)server\(Colors.reset)      Start the backend service.

            \(Colors.cyan)ARGUMENTS & FLAGS:\(Colors.reset)
              \(Colors.dim)# Arguments for add command\(Colors.reset)
              \(Colors.bold)-t\(Colors.reset), --t, -title, -title
                    The name of the task \(Colors.dim)(Required)\(Colors.reset)
              \(Colors.bold)-d\(Colors.reset), --d, -desc, --desc, -description, --description
                    Task description \(Colors.dim)(Required)\(Colors.reset)
              \(Colors.bold)-p\(Colors.reset), --p, -priority, --priority
                    Integer priority level \(Colors.dim)(Optional, Value: [1-10])\(Colors.reset)
              \(Colors.bold)-tag\(Colors.reset), --tag
                    Custom category tag \(Colors.dim)(Optional)\(Colors.reset)

              \(Colors.dim)# Arguments for mark command\(Colors.reset)
              \(Colors.bold)-c\(Colors.reset), --c, -completed, --completed
                    Value: \(Colors.green)yes\(Colors.reset) or \(Colors.green)no\(Colors.reset) \(Colors.dim)(Required)\(Colors.reset)

              \(Colors.dim)# Arguments for mark and delete command\(Colors.reset)
              \(Colors.bold)-q\(Colors.reset), --q, -query, --query
                    Search query/Task title \(Colors.dim)(Required)\(Colors.reset)

            \(Colors.cyan)OPTIONS:\(Colors.reset)
              -h, --h, -help, --help         Show this help message
              -v, --v, -version, --version   Show current version

            \(Colors.blue)EXAMPLES:\(Colors.reset)
              \(Colors.dim)# Add a task\(Colors.reset)
              todo add -t \(Colors.green)"Buy Coffee"\(Colors.reset) -d \(Colors.green)"Get espresso roast"\(Colors.reset) -p 1

              \(Colors.dim)# Mark a task as done\(Colors.reset)
              todo mark -q \(Colors.green)"Buy Coffee"\(Colors.reset) -c yes

              \(Colors.dim)# Delete a task\(Colors.reset)
              todo delete -q \(Colors.green)"Old Task"\(Colors.reset)

            \(Colors.dim)Note: Always wrap multi-word strings in "quotes" to ensure correct parsing.\(Colors.reset)
            """)

        exit(status)
    }

    private static func printVersion() {
        print("\(CommandLine.arguments[0]) version \(VERSION)")
    }

    private static func sync() {
        #if os(macOS)
            // macOS: fork via dlsym workaround
            let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
            guard let forkPtr = dlsym(RTLD_DEFAULT, "fork") else {
                fatalError("Failed to resolve fork()")
            }
            typealias ForkType = @convention(c) () -> Int32
            let fork = unsafeBitCast(forkPtr, to: ForkType.self)
            let pid = fork()
        #elseif os(Linux)
            // Linux: just call fork normally
            let pid = fork()
        #else
            fatalError("Unsupported platform")
        #endif

        if pid < 0 {
            // fork failed
            print("Failed to fork")
            exit(1)
        }

        if pid > 0 {
            // Parent process, exit immediately
            exit(0)
        }

        setsid()
        let status = syncLocalDatabase()
        exit(status ? 0 : 1)
    }

    private static func server() {
        APIRouter.InitRouter()

        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: System.coreCount
        )

        defer {
            // SwiftNIO 2 requires blocking shutdown
            try? group.syncShutdownGracefully()
        }

        do {
            let bootstrap = makeBootstrap(group: group)
            let channel = try bindServer(bootstrap: bootstrap)

            print("HTTP server listening on http://\(ServerConfig.host):\(ServerConfig.port)")

            // Block the main thread until shutdown
            try channel.closeFuture.wait()

        } catch {
            print("Fatal server error:", error)
            exit(1)
        }
    }
}

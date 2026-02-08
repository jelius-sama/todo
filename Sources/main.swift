import NIO

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#else
    #error("Unsupported platform")
#endif

let VERSION = "0.0.0"

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
                Client.ListTodo()

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
                    Client.AddTodo(title: title, desc: desc, priority: priority, tag: tag)
                } else {
                    printHelp(status: 1)
                }

            case "mark", "m":
                // Required minimum of 6 arguments.
                if CommandLine.arguments.count < 6 {
                    printHelp(status: 1)
                }

                var mark: Client.Completed? = nil
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
                    Client.MarkTodo(query: query, completed: mark)
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
        let reset = "\u{001B}[0m"
        let bold = "\u{001B}[1m"
        let dim = "\u{001B}[2m"

        let blue = "\u{001B}[34m"
        let green = "\u{001B}[32m"
        let cyan = "\u{001B}[36m"
        let gray = "\u{001B}[90m"

        print(
            """
            \(gray)\(bold)
             ████████╗ ██████╗ ██████╗  ██████╗ 
             ╚══██╔══╝██╔═══██╗██╔══██╗██╔═══██╗
                ██║   ██║   ██║██║  ██║██║   ██║
                ██║   ██║   ██║██║  ██║██║   ██║
                ██║   ╚██████╔╝██████╔╝╚██████╔╝
                ╚═╝    ╚═════╝ ╚═════╝  ╚═════╝ 
            \(reset)
            \(bold)Todo\(reset) — Terminal-based task manager with remote syncing.

            \(cyan)USAGE:\(reset)
              \(CommandLine.arguments[0]) <command> [args]

            \(cyan)COMMANDS:\(reset)
              \(green)add\(reset), \(green)a\(reset)      Add a task. \(dim)Requires -t and -d.\(reset)
              \(green)mark\(reset), \(green)m\(reset)     Update status. \(dim)Requires -q and -c.\(reset)
              \(green)delete\(reset), \(green)d\(reset)   Remove a task. \(dim)Requires -q.\(reset)
              \(green)list\(reset), \(green)l\(reset)     List all TODOs.
              \(green)sync\(reset), \(green)s\(reset)     Sync with remote server.
              \(green)server\(reset)      Start the backend service.

            \(cyan)ARGUMENTS & FLAGS:\(reset)
              \(dim)# Arguments for add command\(reset)
              \(bold)-t\(reset), --t, -title, -title
                    The name of the task \(dim)(Required)\(reset)
              \(bold)-d\(reset), --d, -desc, --desc, -description, --description
                    Task description \(dim)(Required)\(reset)
              \(bold)-p\(reset), --p, -priority, --priority
                    Integer priority level \(dim)(Optional, Value: [1-10])\(reset)
              \(bold)-tag\(reset), --tag
                    Custom category tag \(dim)(Optional)\(reset)

              \(dim)# Arguments for mark command\(reset)
              \(bold)-c\(reset), --c, -completed, --completed
                    Value: \(green)yes\(reset) or \(green)no\(reset) \(dim)(Required)\(reset)

              \(dim)# Arguments for mark and delete command\(reset)
              \(bold)-q\(reset), --q, -query, --query
                    Search query/Task title \(dim)(Required)\(reset)

            \(cyan)OPTIONS:\(reset)
              -h, --h, -help, --help         Show this help message
              -v, --v, -version, --version   Show current version

            \(blue)EXAMPLES:\(reset)
              \(dim)# Add a task\(reset)
              todo add -t \(green)"Buy Coffee"\(reset) -d \(green)"Get espresso roast"\(reset) -p 1

              \(dim)# Mark a task as done\(reset)
              todo mark -q \(green)"Buy Coffee"\(reset) -c yes

              \(dim)# Delete a task\(reset)
              todo delete -q \(green)"Old Task"\(reset)

            \(dim)Note: Always wrap multi-word strings in "quotes" to ensure correct parsing.\(reset)
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

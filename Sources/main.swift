import NIO

let VERSION = "0.0.0"

@main
struct Entry {
    enum ClientTask: String, CaseIterable {
        case add = "add"
        case mark = "mark"
        case delete = "delete"
    }

    static func main() {
        if CommandLine.arguments.count > 1 {
            let arg: String = CommandLine.arguments[1]
            switch arg {
            case "--help", "-help", "--h", "-h":
                printHelp()

            case "--version", "-version", "--v", "-v":
                printVersion()

            case "server":
                server()

            case "add", "a":
                client(task: .add)

            case "mark", "m":
                client(task: .mark)

            case "delete", "d":
                client(task: .delete)

            case "sync", "s":
                sync()

            default:
                printHelp()
            }
        } else {
            printHelp()
        }
    }

    static func printHelp() {
        let reset = "\u{001B}[0m"
        let bold = "\u{001B}[1m"
        let dim = "\u{001B}[2m"

        let blue = "\u{001B}[34m"
        let green = "\u{001B}[32m"
        let cyan = "\u{001B}[36m"
        let _ = "\u{001B}[90m"  // gray-ish

        print(
            """
            \(blue)\(bold)
             ████████╗ ██████╗ ██████╗  ██████╗ 
             ╚══██╔══╝██╔═══██╗██╔══██╗██╔═══██╗
                ██║   ██║   ██║██║  ██║██║   ██║
                ██║   ██║   ██║██║  ██║██║   ██║
                ██║   ╚██████╔╝██████╔╝╚██████╔╝
                ╚═╝    ╚═════╝ ╚═════╝  ╚═════╝ 
            \(reset)

            \(bold)Todo\(reset) — Manage your tasks from the terminal or browser, with syncing via an external server.

            \(cyan)USAGE:\(reset)
              \(CommandLine.arguments[0]) <command> [options]

            \(cyan)COMMANDS:\(reset)
              \(green)add\(reset), \(green)a\(reset)      Add a new task to your list
              \(green)mark\(reset), \(green)m\(reset)     Mark a task as complete or incomplete
              \(green)delete\(reset), \(green)d\(reset)   Remove a task forever
              \(green)sync\(reset), \(green)s\(reset)     Sync tasks with the remote server
              \(green)server\(reset)      Start the todo backend server

            \(cyan)OPTIONS:\(reset)
              --help, -h      Show this help message
              --version, -v   Show current version

            \(blue)Example:\(reset)
              \(dim)\(bold)# Intelligent parsing\(reset)
              todo add "Buy coffee beans"
              todo add Buy coffee beans
              todo add Buy\\ coffee\\ beans
            """)
    }

    static func printVersion() {
        print("\(CommandLine.arguments[0]) version \(VERSION)")
    }

    static func client(task: ClientTask) {
        print("TODO: Implement todo client!")
    }

    static func sync() {
        print("TODO: Implement remote syncing!")
    }

    static func server() {
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

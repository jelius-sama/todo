import Foundation

// Sends a macOS notification using bundled terminal-notifier.
public func sendNotification(title: String, message: String) -> Bool {
    do {
        #if os(macOS)
            let status = try MacOS.sendNotification(
                title: title,
                message: message
            )
        #elseif os(Linux)
            let status = try Linux.sendNotification(
                title: title,
                message: message
            )
        #endif
        return status == 0
    } catch {
        return false
    }
}

#if os(Linux)
    private struct Linux {
        private struct NotifierExtraction {
            let tempRoot: URL
            let binary: URL
        }

        // Unpacks notify-send to a uniquely named directory in /tmp
        private static func unpackNotifySendToTemp() throws -> NotifierExtraction {
            let fm = FileManager.default

            guard
                let bundledBinaryURL = Bundle.module.url(
                    forResource: "notify-send",
                    withExtension: nil,
                    subdirectory: "notify-send"
                )
            else {
                throw NSError(
                    domain: "Notifier",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "notify-send not found in bundle"]
                )
            }

            let uuid = UUID().uuidString
            let tempRoot = URL(fileURLWithPath: "/tmp")
                .appendingPathComponent("notify-send-\(uuid)", isDirectory: true)

            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: false)

            let extractedBinary = tempRoot.appendingPathComponent("notify-send")
            try fm.copyItem(at: bundledBinaryURL, to: extractedBinary)

            // Ensure executable bit (important on Linux)
            try fm.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: extractedBinary.path
            )

            return NotifierExtraction(
                tempRoot: tempRoot,
                binary: extractedBinary
            )
        }

        static func sendNotification(
            title: String,
            message: String
        ) throws -> Int32 {
            let extraction = try unpackNotifySendToTemp()

            defer {
                try? FileManager.default.removeItem(at: extraction.tempRoot)
            }

            let process = Process()
            process.executableURL = extraction.binary
            process.arguments = [
                title,
                message,
            ]

            let stderr = Pipe()
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            return process.terminationStatus
        }
    }
#endif

#if os(macOS)
    private struct MacOS {
        private struct NotifierExtraction {
            let tempRoot: URL
            let binary: URL
        }

        // Unpacks terminal-notifier.app to a uniquely named directory in /tmp
        private static func unpackTerminalNotifierToTemp() throws -> NotifierExtraction {
            let fm = FileManager.default

            guard
                let bundledAppURL = Bundle.module.url(
                    forResource: "terminal-notifier",
                    withExtension: "app"
                )
            else {
                throw NSError(domain: "Notifier", code: 1)
            }

            let uuid = UUID().uuidString
            let tempRoot = URL(fileURLWithPath: "/tmp")
                .appendingPathComponent("terminal-notifier-\(uuid)", isDirectory: true)

            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: false)

            let extractedApp = tempRoot.appendingPathComponent("terminal-notifier.app")
            try fm.copyItem(at: bundledAppURL, to: extractedApp)

            let binary =
                extractedApp
                .appendingPathComponent("Contents/MacOS/terminal-notifier")

            return NotifierExtraction(
                tempRoot: tempRoot,
                binary: binary
            )
        }

        // Executes terminal-notifier and waits for exit status.
        static func sendNotification(
            title: String,
            message: String
        ) throws -> Int32 {
            let extraction = try unpackTerminalNotifierToTemp()

            defer {
                try? FileManager.default.removeItem(at: extraction.tempRoot)
            }

            let process = Process()
            process.executableURL = extraction.binary
            process.arguments = [
                "-title", title,
                "-message", message,
            ]

            let stderr = Pipe()
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            return process.terminationStatus
        }
    }
#endif

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#else
    #error("Unsupported platform")
#endif

func syncLocalDatabase() -> Bool {
    print("TODO: Implement remote syncing!")
    sleep(5)

    let didSend = sendNotification(
        title: "Todo",
        message: "Hello, World!"
    )

    if !didSend {
        print("Failed to notify!")
        return false
    }

    return true
}

import Foundation

final class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?

    init?(directory: URL, callback: @escaping () -> Void) {
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source?.setEventHandler {
            callback()
        }
        source?.setCancelHandler {
            close(fd)
        }
        source?.resume()
    }

    deinit {
        source?.cancel()
    }
}

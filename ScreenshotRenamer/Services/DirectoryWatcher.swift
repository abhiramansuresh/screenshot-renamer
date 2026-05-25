import Darwin
import Foundation

final class DirectoryWatcher {
    private let directoryURL: URL
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    init?(directoryURL: URL, onChange: @MainActor @escaping (URL) -> Void) {
        self.directoryURL = directoryURL

        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: .main
        )

        source.setEventHandler { [directoryURL] in
            Task { @MainActor in
                onChange(directoryURL)
            }
        }

        source.setCancelHandler { [fileDescriptor] in
            if fileDescriptor >= 0 {
                close(fileDescriptor)
            }
        }

        self.source = source
        source.resume()
    }

    deinit {
        cancel()
    }

    func cancel() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}

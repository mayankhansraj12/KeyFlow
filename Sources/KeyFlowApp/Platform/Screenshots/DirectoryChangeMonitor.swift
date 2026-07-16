import Darwin
import Foundation

enum DirectoryChangeMonitorError: Error {
    case unavailable(Int32)
    case timedOut
}

struct DirectoryChangeMonitor {
    func waitForChange(in directory: URL, timeout: Duration) async throws {
        let state = DirectoryChangeWaitState(directory: directory, timeout: timeout)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.start(continuation)
            }
        } onCancel: {
            state.finish(.failure(CancellationError()))
        }
    }
}

private final class DirectoryChangeWaitState: @unchecked Sendable {
    private let directory: URL
    private let timeout: Duration
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var isFinished = false

    init(directory: URL, timeout: Duration) {
        self.directory = directory
        self.timeout = max(.milliseconds(1), timeout)
    }

    func start(_ continuation: CheckedContinuation<Void, any Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }

        let fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            lock.unlock()
            continuation.resume(throwing: DirectoryChangeMonitorError.unavailable(errno))
            return
        }

        let queue = DispatchQueue(label: "app.keyflow.screenshot-directory-monitor", qos: .utility)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )
        let timer = DispatchSource.makeTimerSource(queue: queue)
        source.setEventHandler { [weak self] in self?.finish(.success(())) }
        source.setCancelHandler { close(fileDescriptor) }
        timer.setEventHandler { [weak self] in self?.finish(.failure(DirectoryChangeMonitorError.timedOut)) }
        timer.schedule(deadline: .now() + timeout.timeInterval)

        self.continuation = continuation
        self.source = source
        self.timer = timer
        lock.unlock()

        source.activate()
        timer.activate()
    }

    func finish(_ result: Result<Void, any Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        self.continuation = nil
        let source = self.source
        self.source = nil
        let timer = self.timer
        self.timer = nil
        lock.unlock()

        source?.cancel()
        timer?.cancel()
        continuation?.resume(with: result)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

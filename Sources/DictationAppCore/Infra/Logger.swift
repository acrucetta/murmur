public protocol Logging {
    func log(_ message: String)
}

public struct NoopLogger: Logging {
    public init() {}

    public func log(_ message: String) {}
}

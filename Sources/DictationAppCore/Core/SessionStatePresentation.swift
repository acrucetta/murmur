public enum SessionStatePresentation {
    public static func label(for state: SessionState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening"
        case .finalizing:
            return "Finalizing"
        case .inserting:
            return "Inserting"
        case .error(let code):
            return "Error: \(code.rawValue)"
        }
    }
}

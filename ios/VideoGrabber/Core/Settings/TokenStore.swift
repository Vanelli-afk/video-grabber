protocol TokenStore: Sendable {
    func readToken() -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

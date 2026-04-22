import Foundation

/// A user-configured MCP (Model Context Protocol) server. When `enabled`
/// is true, `ApfelArgumentsBuilder` appends `--mcp <path>` to the apfel
/// server spawn, exposing the server's tools to the on-device model.
struct MCPServerConfig: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var enabled: Bool

    init(id: UUID = UUID(), name: String, path: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.path = path
        self.enabled = enabled
    }
}

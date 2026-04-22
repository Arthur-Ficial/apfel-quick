import Foundation

/// Pure builder for the argument list passed to `apfel --serve`. Always
/// emits `--cors --permissive` (apfel-quick's required defaults) and
/// appends `--mcp <path>` for each enabled MCP server with a non-empty
/// path.
enum ApfelArgumentsBuilder {
    static func build(mcpServers: [MCPServerConfig]) -> [String] {
        var args: [String] = ["--cors", "--permissive"]
        for server in mcpServers where server.enabled && !server.path.isEmpty {
            args.append("--mcp")
            args.append(server.path)
        }
        return args
    }
}

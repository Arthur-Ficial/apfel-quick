import Testing
import Foundation
@testable import apfel_quick

/// TDD (RED) for MCP enable/disable (issue #9).
///
/// Spec:
/// - A configured MCP server has id, name, path, enabled fields.
/// - QuickSettings stores a list of them.
/// - ApfelArgumentsBuilder builds the `[String]` passed to `apfel --serve`
///   by starting with `--cors --permissive` and appending `--mcp <path>`
///   for each ENABLED server (disabled ones are skipped).

@Suite("MCPServerConfig")
struct MCPServerConfigTests {

    @Test func testInitDefaultsEnabled() {
        let c = MCPServerConfig(name: "Calc", path: "/tmp/calc.py")
        #expect(c.enabled == true)
    }

    @Test func testCodableRoundTrip() throws {
        let c = MCPServerConfig(name: "Calc", path: "/tmp/calc.py", enabled: false)
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(MCPServerConfig.self, from: data)
        #expect(back.name == c.name)
        #expect(back.path == c.path)
        #expect(back.enabled == c.enabled)
        #expect(back.id == c.id)
    }

    @Test func testIdentifiableIsUnique() {
        let a = MCPServerConfig(name: "A", path: "/a")
        let b = MCPServerConfig(name: "B", path: "/b")
        #expect(a.id != b.id)
    }
}

@Suite("ApfelArgumentsBuilder")
struct ApfelArgumentsBuilderTests {

    @Test func testNoServersProducesBaseArgs() {
        let args = ApfelArgumentsBuilder.build(mcpServers: [])
        #expect(args == ["--cors", "--permissive"])
    }

    @Test func testOneEnabledServerAppendsMcpPair() {
        let args = ApfelArgumentsBuilder.build(mcpServers: [
            MCPServerConfig(name: "calc", path: "/tmp/calc.py", enabled: true)
        ])
        #expect(args == ["--cors", "--permissive", "--mcp", "/tmp/calc.py"])
    }

    @Test func testDisabledServerIsOmitted() {
        let args = ApfelArgumentsBuilder.build(mcpServers: [
            MCPServerConfig(name: "calc", path: "/tmp/calc.py", enabled: false)
        ])
        #expect(args == ["--cors", "--permissive"])
    }

    @Test func testMultipleEnabledServersEachGetTheirOwnPair() {
        let args = ApfelArgumentsBuilder.build(mcpServers: [
            MCPServerConfig(name: "calc", path: "/tmp/calc.py", enabled: true),
            MCPServerConfig(name: "web", path: "/tmp/web.py", enabled: true),
        ])
        #expect(args == [
            "--cors", "--permissive",
            "--mcp", "/tmp/calc.py",
            "--mcp", "/tmp/web.py",
        ])
    }

    @Test func testMixedEnabledAndDisabledPreservesOrderAndSkipsDisabled() {
        let args = ApfelArgumentsBuilder.build(mcpServers: [
            MCPServerConfig(name: "a", path: "/a", enabled: true),
            MCPServerConfig(name: "b", path: "/b", enabled: false),
            MCPServerConfig(name: "c", path: "/c", enabled: true),
        ])
        #expect(args == [
            "--cors", "--permissive",
            "--mcp", "/a",
            "--mcp", "/c",
        ])
    }

    @Test func testEmptyPathIsSkipped() {
        // Defensive: an empty path would cause apfel to crash on start.
        let args = ApfelArgumentsBuilder.build(mcpServers: [
            MCPServerConfig(name: "broken", path: "", enabled: true),
            MCPServerConfig(name: "good", path: "/ok", enabled: true),
        ])
        #expect(args == ["--cors", "--permissive", "--mcp", "/ok"])
    }
}

@Suite("QuickSettings MCP")
struct QuickSettingsMCPTests {

    @Test func testDefaultMcpServersIsEmpty() {
        let s = QuickSettings()
        #expect(s.mcpServers.isEmpty)
    }

    @Test func testMcpServersRoundTripThroughCodable() throws {
        var s = QuickSettings()
        s.mcpServers = [
            MCPServerConfig(name: "calc", path: "/tmp/calc.py", enabled: true),
            MCPServerConfig(name: "web", path: "/tmp/web.py", enabled: false),
        ]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(QuickSettings.self, from: data)
        #expect(back.mcpServers.count == 2)
        #expect(back.mcpServers.first?.name == "calc")
        #expect(back.mcpServers.last?.enabled == false)
    }

    @Test func testLegacySettingsWithoutMcpServersDecodes() throws {
        let legacy = #"""
        {"hotkeyKeyCode":49,"hotkeyModifiers":524288,"autoCopy":true,"launchAtLogin":true,"showMenuBar":true,"checkForUpdatesOnLaunch":true,"hasSeenWelcome":true,"launchAtLoginPromptShown":true}
        """#
        let s = try JSONDecoder().decode(QuickSettings.self, from: Data(legacy.utf8))
        #expect(s.mcpServers.isEmpty)
    }
}

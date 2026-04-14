@testable import AppBundle
import Common
import XCTest

@MainActor
final class LayoutCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testHorizontalLayoutEnforcesHTilesLimit() async throws {
        config.workspaceToHTilesLimit[name] = 3
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
            $0.changeOrientation(.v)
        }

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .horizontal, .vertical]))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .v_accordion([
                    .window(3),
                    .window(4),
                ]),
            ]),
        )
    }
}

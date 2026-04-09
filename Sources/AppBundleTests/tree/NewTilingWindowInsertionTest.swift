@testable import AppBundle
import XCTest

@MainActor
final class NewTilingWindowInsertionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testNewTilingWindowWithoutLimitUsesDefaultInsertion() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            let window2 = TestWindow.new(id: 2, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 3, parent: $0)
            }
            assertEquals(window2.focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 4, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .window(4),
                .v_tiles([
                    .window(3),
                ]),
            ]),
        )
    }

    func testOverflowInsertionChoosesRightVTilesAndCreatesTopLevelHAccordion() async throws {
        config.workspaceToVTilesLimit[name] = 2
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            let window1 = TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
            }
            TestWindow.new(id: 3, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 4, parent: $0)
            }
            assertEquals(window1.focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 5, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([
                    .h_accordion([
                        .window(2),
                        .window(5),
                    ]),
                ]),
                .window(3),
                .v_tiles([
                    .window(4),
                ]),
            ]),
        )
    }

    func testOverflowInsertionChoosesLeftVTilesWhenThereIsNoRightCandidate() async throws {
        config.workspaceToVTilesLimit[name] = 1
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0)
            }
            TestWindow.new(id: 2, parent: $0)
            assertEquals(TestWindow.new(id: 3, parent: $0).focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 4, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .v_tiles([
                    .h_accordion([
                        .window(1),
                        .window(4),
                    ]),
                ]),
                .window(2),
                .window(3),
            ]),
        )
    }

    func testOverflowInsertionUsesMostRecentTopLevelHAccordion() async throws {
        config.workspaceToVTilesLimit[name] = 1
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        var targetVTiles: TilingContainer!
        var accordion1: TilingContainer!
        var window4: Window!
        var accordion2: TilingContainer!
        var window1: Window!
        root.apply {
            window1 = TestWindow.new(id: 1, parent: $0)
            targetVTiles = TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1)
            targetVTiles.apply {
                accordion1 = TilingContainer(parent: $0, adaptiveWeight: 1, .h, .accordion, index: INDEX_BIND_LAST)
                accordion1.apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
                window4 = TestWindow.new(id: 4, parent: $0)
                accordion2 = TilingContainer(parent: $0, adaptiveWeight: 1, .h, .accordion, index: INDEX_BIND_LAST)
                accordion2.apply {
                    TestWindow.new(id: 5, parent: $0)
                    TestWindow.new(id: 6, parent: $0)
                }
            }
        }
        (accordion1.children.last as? Window)?.markAsMostRecentChild()
        window4.markAsMostRecentChild()
        assertEquals(window1.focusWindow(), true)

        let newWindow = TestWindow.new(id: 7, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([
                    .h_accordion([
                        .window(2),
                        .window(3),
                        .window(7),
                    ]),
                    .window(4),
                    .h_accordion([
                        .window(5),
                        .window(6),
                    ]),
                ]),
            ]),
        )
    }

    func testOverflowInsertionSurvivesNormalization() async throws {
        config.workspaceToVTilesLimit[name] = 1
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true

        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            let window1 = TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
            }
            assertEquals(window1.focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 3, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)
        workspace.normalizeContainers()

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([
                    .h_accordion([
                        .window(2),
                        .window(3),
                    ]),
                ]),
            ]),
        )
    }

    func testHTilesOverflowChoosesRightRootChildAndWrapsIntoVAccordion() async throws {
        config.workspaceToHTilesLimit[name] = 3
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            let window1 = TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
            assertEquals(window1.focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 5, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_accordion([
                    .window(2),
                    .window(5),
                ]),
                .window(3),
                .window(4),
            ]),
        )
    }

    func testHTilesOverflowChoosesLeftRootChildWhenFocusedIsLast() async throws {
        config.workspaceToHTilesLimit[name] = 3
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            assertEquals(TestWindow.new(id: 4, parent: $0).focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 5, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .v_accordion([
                    .window(3),
                    .window(5),
                ]),
                .window(4),
            ]),
        )
    }

    func testHTilesOverflowUsesExistingVAccordionWithoutWrappingAgain() async throws {
        config.workspaceToHTilesLimit[name] = 3
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            let window1 = TestWindow.new(id: 1, parent: $0)
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .accordion, index: INDEX_BIND_LAST).apply {
                TestWindow.new(id: 2, parent: $0)
            }
            TestWindow.new(id: 3, parent: $0)
            assertEquals(window1.focusWindow(), true)
        }

        let newWindow = TestWindow.new(id: 4, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_accordion([
                    .window(2),
                    .window(4),
                ]),
                .window(3),
            ]),
        )
    }

    func testHTilesOverflowDoesNotApplyWhenInsertionIsNested() async throws {
        config.workspaceToHTilesLimit[name] = 2
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                let window2 = TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
                assertEquals(window2.focusWindow(), true)
            }
        }

        let newWindow = TestWindow.new(id: 4, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([
                    .window(2),
                    .window(4),
                    .window(3),
                ]),
            ]),
        )
    }
}

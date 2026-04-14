import AppKit
import Common

@MainActor
func getBindingDataForOverflowTilingWindow(_ workspace: Workspace) -> BindingData? {
    if let hTilesBinding = getBindingDataForHTilesOverflow(workspace) {
        return hTilesBinding
    }
    return getBindingDataForVTilesOverflow(workspace)
}

@MainActor
func enforceWorkspaceRootLimits(_ workspace: Workspace) {
    let preservedMruWindow = workspace.mostRecentWindowRecursive
    let didChange = enforceWorkspaceHTilesLimit(workspace) || enforceWorkspaceVTilesLimit(workspace)
    if didChange {
        preservedMruWindow?.markAsMostRecentChild()
    }
}

@MainActor
private func getBindingDataForVTilesOverflow(_ workspace: Workspace) -> BindingData? {
    guard let limit = config.workspaceToVTilesLimit[workspace.name] else { return nil }
    let root = workspace.rootTilingContainer
    guard root.layout == .tiles, root.orientation == .h else { return nil }

    let mruWindow = workspace.mostRecentWindowRecursive
    let defaultInsertionParent = (mruWindow?.parent as? TilingContainer) ?? root
    guard defaultInsertionParent === root else { return nil }

    let topLevelVTiles = root.children.compactMap(asTopLevelVTiles)
    guard topLevelVTiles.count >= limit else { return nil }

    guard let activeRootChild = mruWindow ?? root.mostRecentChild,
          let activeIndex = activeRootChild.ownIndex
    else {
        return nil
    }

    let targetVTiles = root.children.dropFirst(activeIndex + 1).compactMap(asTopLevelVTiles).first
        ?? root.children.prefix(activeIndex).reversed().compactMap(asTopLevelVTiles).first
    guard let targetVTiles else { return nil }

    let targetAccordion = targetVTiles.mostRecentChild(where: isTopLevelHAccordion)
        .flatMap { $0 as? TilingContainer }
        ?? createTopLevelHAccordion(in: targetVTiles)

    return BindingData(
        parent: targetAccordion,
        adaptiveWeight: WEIGHT_AUTO,
        index: INDEX_BIND_LAST,
    )
}

@MainActor
private func getBindingDataForHTilesOverflow(_ workspace: Workspace) -> BindingData? {
    guard let limit = config.workspaceToHTilesLimit[workspace.name] else { return nil }
    let root = workspace.rootTilingContainer
    guard root.layout == .tiles, root.orientation == .h else { return nil }

    let mruWindow = workspace.mostRecentWindowRecursive
    let defaultInsertionParent = (mruWindow?.parent as? TilingContainer) ?? root
    guard defaultInsertionParent === root else { return nil }
    guard root.children.count >= limit else { return nil }

    guard let activeRootChild = mruWindow ?? root.mostRecentChild,
          let activeIndex = activeRootChild.ownIndex
    else {
        return nil
    }

    let targetChild = root.children.getOrNil(atIndex: activeIndex + 1)
        ?? root.children.getOrNil(atIndex: activeIndex - 1)
    guard let targetChild else { return nil }

    let targetVAccordion = (targetChild as? TilingContainer)?
        .takeIf { $0.layout == .accordion && $0.orientation == .v }
        ?? createTopLevelVAccordion(around: targetChild)

    return BindingData(
        parent: targetVAccordion,
        adaptiveWeight: WEIGHT_AUTO,
        index: INDEX_BIND_LAST,
    )
}

@MainActor
private func enforceWorkspaceHTilesLimit(_ workspace: Workspace) -> Bool {
    guard let limit = config.workspaceToHTilesLimit[workspace.name] else { return false }
    let root = workspace.rootTilingContainer
    guard root.layout == .tiles, root.orientation == .h else { return false }

    var didChange = false
    while root.children.count > limit {
        guard let sourceChild = root.children.last,
              let sourceIndex = sourceChild.ownIndex,
              let targetChild = root.children.getOrNil(atIndex: sourceIndex - 1)
        else {
            break
        }
        let targetVAccordion = (targetChild as? TilingContainer)?
            .takeIf { $0.layout == .accordion && $0.orientation == .v }
            ?? createTopLevelVAccordion(around: targetChild)
        moveNodeOrContainerChildren(sourceChild, into: targetVAccordion)
        didChange = true
    }
    return didChange
}

@MainActor
private func enforceWorkspaceVTilesLimit(_ workspace: Workspace) -> Bool {
    guard let limit = config.workspaceToVTilesLimit[workspace.name] else { return false }
    let root = workspace.rootTilingContainer
    guard root.layout == .tiles, root.orientation == .h else { return false }

    var didChange = false
    while root.children.compactMap(asTopLevelVTiles).count > limit {
        guard let sourceVTiles = root.children.reversed().compactMap(asTopLevelVTiles).first,
              let sourceIndex = sourceVTiles.ownIndex
        else {
            break
        }
        let targetVTiles = root.children.prefix(sourceIndex).reversed().compactMap(asTopLevelVTiles).first
        guard let targetVTiles else { break }

        let targetAccordion = targetVTiles.mostRecentChild(where: isTopLevelHAccordion)
            .flatMap { $0 as? TilingContainer }
            ?? createTopLevelHAccordion(in: targetVTiles)
        moveNodeOrContainerChildren(sourceVTiles, into: targetAccordion)
        didChange = true
    }
    return didChange
}

private func asTopLevelVTiles(_ node: TreeNode) -> TilingContainer? {
    guard let container = node as? TilingContainer,
          container.layout == .tiles,
          container.orientation == .v
    else {
        return nil
    }
    return container
}

private func isTopLevelHAccordion(_ node: TreeNode) -> Bool {
    guard let container = node as? TilingContainer else { return false }
    return container.layout == .accordion && container.orientation == .h
}

@MainActor
private func moveNodeOrContainerChildren(_ node: TreeNode, into targetContainer: TilingContainer) {
    if let sourceContainer = node as? TilingContainer,
       sourceContainer.layout == targetContainer.layout,
       sourceContainer.orientation == targetContainer.orientation
    {
        while let child = sourceContainer.children.first {
            child.unbindFromParent()
            child.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
        if sourceContainer.isBound {
            sourceContainer.unbindFromParent()
        }
    } else {
        node.unbindFromParent()
        node.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
}

@MainActor
func createTopLevelVAccordion(around node: TreeNode) -> TilingContainer {
    let previousBinding = node.unbindFromParent()
    let vAccordion = TilingContainer(
        parent: previousBinding.parent,
        adaptiveWeight: previousBinding.adaptiveWeight,
        .v,
        .accordion,
        index: previousBinding.index,
    )
    node.bind(to: vAccordion, adaptiveWeight: WEIGHT_AUTO, index: 0)
    return vAccordion
}

@MainActor
func createTopLevelHAccordion(in vTiles: TilingContainer) -> TilingContainer {
    guard let mruChild = vTiles.mostRecentChild ?? vTiles.children.last else {
        return TilingContainer(parent: vTiles, adaptiveWeight: WEIGHT_AUTO, .h, .accordion, index: INDEX_BIND_LAST)
    }

    let previousBinding = mruChild.unbindFromParent()
    let accordion = TilingContainer(
        parent: vTiles,
        adaptiveWeight: previousBinding.adaptiveWeight,
        .h,
        .accordion,
        index: previousBinding.index,
    )
    mruChild.bind(to: accordion, adaptiveWeight: WEIGHT_AUTO, index: 0)
    return accordion
}

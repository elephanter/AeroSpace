extension Workspace {
    @MainActor func normalizeContainers() {
        rootTilingContainer.unbindEmptyAndAutoFlatten() // Beware! rootTilingContainer may change after this line of code
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
        enforceWorkspaceRootLimits(self)
    }
}

extension TilingContainer {
    @MainActor fileprivate func unbindEmptyAndAutoFlatten() {
        if let child = children.singleOrNil(),
           config.enableNormalizationFlattenContainers &&
           (child is TilingContainer || !isRootContainer) &&
           !shouldPreserveForWorkspaceVTilesLimit(singleChild: child)
        {
            child.unbindFromParent()
            let mru = parent?.mostRecentChild
            let previousBinding = unbindFromParent()
            child.bind(to: previousBinding.parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            (child as? TilingContainer)?.unbindEmptyAndAutoFlatten()
            if mru != self {
                mru?.markAsMostRecentChild()
            } else {
                child.markAsMostRecentChild()
            }
        } else {
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndAutoFlatten()
            }
            if children.isEmpty && !isRootContainer {
                unbindFromParent()
            }
        }
    }

    @MainActor private func shouldPreserveForWorkspaceVTilesLimit(singleChild: TreeNode) -> Bool {
        guard let workspace = nodeWorkspace, config.workspaceToVTilesLimit[workspace.name] != nil else { return false }
        guard layout == .tiles, orientation == .v else { return false }
        guard let parent = parent as? TilingContainer,
              parent.isRootContainer,
              parent.layout == .tiles,
              parent.orientation == .h
        else {
            return false
        }
        guard let childContainer = singleChild as? TilingContainer else { return false }
        return childContainer.layout == .accordion && childContainer.orientation == .h
    }
}

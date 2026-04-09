import Common

func parseWorkspaceToVTilesLimit(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [String: Int] {
    guard let rawTable = raw.asDictOrNil else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: Int] = [:]
    for (workspaceName, rawLimit) in rawTable {
        let limitBacktrace = backtrace + .key(workspaceName)
        if let limit = parseInt(rawLimit, limitBacktrace)
            .filter(.semantic(limitBacktrace, "Must be greater than 0"), { $0 > 0 })
            .getOrNil(appendErrorTo: &errors)
        {
            result[workspaceName] = limit
        }
    }
    return result
}

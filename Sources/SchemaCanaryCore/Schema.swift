import Foundation

public struct SchemaSnapshot: Codable, Sendable {
    public let formatVersion: Int
    public let entities: [SchemaEntity]

    public init(formatVersion: Int, entities: [SchemaEntity]) {
        self.formatVersion = formatVersion
        self.entities = entities
    }
}

public struct SchemaEntity: Codable, Sendable {
    public let name: String
    public let properties: [SchemaProperty]

    public init(name: String, properties: [SchemaProperty]) {
        self.name = name
        self.properties = properties
    }
}

public struct SchemaProperty: Codable, Sendable {
    public let name: String
    public let type: String
    public let optional: Bool
    public let hasDefaultValue: Bool
    public let unique: Bool
    public let relationshipDestination: String?
    public let toMany: Bool?

    public init(
        name: String,
        type: String,
        optional: Bool,
        hasDefaultValue: Bool,
        unique: Bool,
        relationshipDestination: String?,
        toMany: Bool?
    ) {
        self.name = name
        self.type = type
        self.optional = optional
        self.hasDefaultValue = hasDefaultValue
        self.unique = unique
        self.relationshipDestination = relationshipDestination
        self.toMany = toMany
    }
}

public struct SchemaChange: Sendable {
    public enum Severity: String, Sendable, Equatable {
        case breaking
        case informational
    }

    public let severity: Severity
    public let path: String
    public let message: String
}

public enum SchemaCanaryError: Error, CustomStringConvertible, Sendable {
    case unsupportedFormat(Int)
    case duplicateName(String)

    public var description: String {
        switch self {
        case .unsupportedFormat(let version):
            return "Unsupported snapshot format version: \(version)"
        case .duplicateName(let name):
            return "Duplicate entity or property name: \(name)"
        }
    }
}

public enum SchemaComparator {
    public static func compare(
        baseline: SchemaSnapshot,
        current: SchemaSnapshot
    ) throws -> [SchemaChange] {
        guard baseline.formatVersion == 1 else {
            throw SchemaCanaryError.unsupportedFormat(baseline.formatVersion)
        }
        guard current.formatVersion == 1 else {
            throw SchemaCanaryError.unsupportedFormat(current.formatVersion)
        }

        let oldEntities = try index(baseline.entities, name: \.name)
        let newEntities = try index(current.entities, name: \.name)
        var changes: [SchemaChange] = []

        for oldEntity in baseline.entities {
            guard let newEntity = newEntities[oldEntity.name] else {
                changes.append(change(.breaking, oldEntity.name, "Entity was removed."))
                continue
            }

            let oldProperties = try index(oldEntity.properties, name: \.name)
            let newProperties = try index(newEntity.properties, name: \.name)

            for oldProperty in oldEntity.properties {
                guard let newProperty = newProperties[oldProperty.name] else {
                    changes.append(change(.breaking, "\(oldEntity.name).\(oldProperty.name)", "Property was removed."))
                    continue
                }

                let path = "\(oldEntity.name).\(oldProperty.name)"
                if oldProperty.type != newProperty.type {
                    changes.append(change(.breaking, path, "Type changed from \(oldProperty.type) to \(newProperty.type)."))
                }
                if oldProperty.optional && !newProperty.optional {
                    changes.append(change(.breaking, path, "Property became required."))
                }
                if oldProperty.relationshipDestination != newProperty.relationshipDestination {
                    changes.append(change(.breaking, path, "Relationship destination changed."))
                }
                if oldProperty.toMany != newProperty.toMany {
                    changes.append(change(.breaking, path, "Relationship cardinality changed."))
                }
                if !oldProperty.unique && newProperty.unique {
                    changes.append(change(.breaking, path, "Uniqueness was added; existing duplicate values may block migration."))
                }
                if oldProperty.hasDefaultValue && !newProperty.hasDefaultValue && !newProperty.optional {
                    changes.append(change(.breaking, path, "Required property lost its migration default."))
                }
            }

            for property in newEntity.properties where oldProperties[property.name] == nil {
                if !property.optional && !property.hasDefaultValue {
                    changes.append(change(.breaking, "\(newEntity.name).\(property.name)", "Required property was added without a migration default."))
                } else {
                    changes.append(change(.informational, "\(newEntity.name).\(property.name)", "Property was added with a default or as optional."))
                }
            }
        }

        for newEntity in current.entities where oldEntities[newEntity.name] == nil {
            changes.append(change(.informational, newEntity.name, "Entity was added."))
        }

        return changes.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.severity.rawValue != $1.severity.rawValue {
                return $0.severity.rawValue < $1.severity.rawValue
            }
            return $0.message < $1.message
        }
    }

    private static func index<T>(
        _ values: [T],
        name: (T) -> String
    ) throws -> [String: T] {
        var result: [String: T] = [:]
        for value in values {
            let key = name(value)
            guard result[key] == nil else {
                throw SchemaCanaryError.duplicateName(key)
            }
            result[key] = value
        }
        return result
    }

    private static func change(
        _ severity: SchemaChange.Severity,
        _ path: String,
        _ message: String
    ) -> SchemaChange {
        SchemaChange(severity: severity, path: path, message: message)
    }
}

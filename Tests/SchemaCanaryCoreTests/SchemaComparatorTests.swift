import XCTest
@testable import SchemaCanaryCore

final class SchemaComparatorTests: XCTestCase {
    private func property(
        _ name: String,
        type: String = "String",
        optional: Bool = true,
        hasDefault: Bool = false
    ) -> SchemaProperty {
        SchemaProperty(
            name: name,
            type: type,
            optional: optional,
            hasDefaultValue: hasDefault,
            unique: false,
            relationshipDestination: nil,
            toMany: nil
        )
    }

    func testRequiredAdditionAndRemovedFieldAreBreaking() throws {
        let before = SchemaSnapshot(
            formatVersion: 1,
            entities: [SchemaEntity(name: "Invoice", properties: [property("memo")])]
        )
        let after = SchemaSnapshot(
            formatVersion: 1,
            entities: [SchemaEntity(
                name: "Invoice",
                properties: [
                    property("total", type: "Decimal", optional: false),
                    property("status")
                ]
            )]
        )
        let changes = try SchemaComparator.compare(baseline: before, current: after)
        XCTAssertTrue(changes.contains { $0.severity == .breaking && $0.path == "Invoice.memo" })
        XCTAssertTrue(changes.contains { $0.severity == .breaking && $0.path == "Invoice.total" })
        XCTAssertTrue(changes.contains { $0.severity == .informational && $0.path == "Invoice.status" })
    }

    func testTypeAndRelationshipChangesAreReported() throws {
        let oldProperty = SchemaProperty(
            name: "owner", type: "Relationship", optional: true, hasDefaultValue: false,
            unique: false, relationshipDestination: "User", toMany: false
        )
        let newProperty = SchemaProperty(
            name: "owner", type: "Relationship", optional: true, hasDefaultValue: false,
            unique: false, relationshipDestination: "Team", toMany: true
        )
        let before = SchemaSnapshot(
            formatVersion: 1,
            entities: [SchemaEntity(name: "Invoice", properties: [oldProperty])]
        )
        let after = SchemaSnapshot(
            formatVersion: 1,
            entities: [SchemaEntity(name: "Invoice", properties: [newProperty])]
        )
        let changes = try SchemaComparator.compare(baseline: before, current: after)
        XCTAssertEqual(changes.filter { $0.severity == .breaking }.count, 2)
    }

    func testDuplicateNamesAreRejected() {
        let snapshot = SchemaSnapshot(
            formatVersion: 1,
            entities: [
                SchemaEntity(name: "Invoice", properties: []),
                SchemaEntity(name: "Invoice", properties: [])
            ]
        )
        XCTAssertThrowsError(try SchemaComparator.compare(baseline: snapshot, current: snapshot))
    }

    func testOptionalAdditionIsInformational() throws {
        let before = SchemaSnapshot(
            formatVersion: 1,
            entities: [SchemaEntity(name: "Invoice", properties: [])]
        )
        let after = SchemaSnapshot(
            formatVersion: 1,
            entities: [SchemaEntity(name: "Invoice", properties: [property("memo")])]
        )
        let changes = try SchemaComparator.compare(baseline: before, current: after)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.severity, .informational)
    }
}

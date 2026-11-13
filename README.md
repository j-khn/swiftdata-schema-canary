# SwiftData Schema Canary

> **Status:** Early-stage reference implementation; APIs may change.

Catch likely destructive persistence-schema changes before they reach an installed app.

SwiftData and Core Data migrations are versioned with application code, while old stores live on user devices. Schema Canary compares two small JSON snapshots and reports changes that deserve an explicit migration plan: removed fields, type changes, newly required data, and relationship changes.

## ✨ Try it

~~~sh
swift run schema-canary examples/baseline.json examples/current-breaking.json
~~~

The sample exits with status 2 because Invoice.memo changed from optional to required. A CI job can use that status to block a release until the migration is reviewed.

## Snapshot shape

A snapshot records entities and properties, including type, optionality, default availability, uniqueness, and relationship metadata. See the examples directory for a complete pair.

~~~json
{
  "formatVersion": 1,
  "entities": [
    {
      "name": "Invoice",
      "properties": [
        {
          "name": "id",
          "type": "UUID",
          "optional": false,
          "hasDefaultValue": true,
          "unique": true,
          "relationshipDestination": null,
          "toMany": null
        }
      ]
    }
  ]
}
~~~

## What it flags

- Removed entities or properties.
- Property type changes and optional-to-required changes.
- New required properties without a declared default.
- Relationship destination or cardinality changes.
- New uniqueness constraints that may conflict with existing data.

Optional additions and required additions with a declared default are informational.

## Important limits

Apple provides migration mechanisms such as SwiftData SchemaMigrationPlan and Core Data mapping models. This tool complements them with a reviewable compatibility diff; it is not a migration engine. It does not inspect a SwiftData model automatically and cannot prove that a custom migration closure preserves user data. Export or maintain snapshots deliberately, then review every reported change against the migration code and real historical stores.

## License

MIT.

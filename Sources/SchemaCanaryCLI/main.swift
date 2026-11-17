import Foundation
import SchemaCanaryCore

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

@main
struct SchemaCanaryCommand {
    static func main() {
        let paths = Array(CommandLine.arguments.dropFirst())
        guard paths.count == 2 else {
            FileHandle.standardError.write(Data("Usage: schema-canary BASELINE.json CURRENT.json\n".utf8))
            exit(1)
        }

        do {
            let baselineData = try Data(contentsOf: URL(fileURLWithPath: paths[0]))
            let currentData = try Data(contentsOf: URL(fileURLWithPath: paths[1]))
            let decoder = JSONDecoder()
            let baseline = try decoder.decode(SchemaSnapshot.self, from: baselineData)
            let current = try decoder.decode(SchemaSnapshot.self, from: currentData)
            let changes = try SchemaComparator.compare(baseline: baseline, current: current)

            if changes.isEmpty {
                print("✅ No schema changes.")
                return
            }

            for change in changes {
                let icon = change.severity == .breaking ? "❌" : "ℹ️"
                print("\(icon) \(change.path): \(change.message)")
            }

            if changes.contains(where: { $0.severity == .breaking }) {
                exit(2)
            }
        } catch {
            FileHandle.standardError.write(Data("schema-canary: \(error)\n".utf8))
            exit(1)
        }
    }
}

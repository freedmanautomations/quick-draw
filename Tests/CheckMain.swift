import AppKit
import Foundation

@main struct CheckMain {
    @MainActor static func main() {
        do {
            if let index = CommandLine.arguments.firstIndex(of: "--render-check"), CommandLine.arguments.count == index + 2 {
                try InterfaceChecks.run(output: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            } else { try SelfTest.run() }
        } catch {
            fputs("FAIL: standalone checks did not pass\n", stderr)
            exit(1)
        }
    }
}

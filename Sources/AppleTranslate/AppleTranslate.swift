import ArgumentParser
import Darwin
import Foundation

@main
struct AppleTranslate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "translate",
        abstract: "Translate text using Apple's on-device Translation framework.",
        discussion: "Requires macOS 26 or later.",
        version: "0.1.0"
    )

    @Option(name: [.customShort("s"), .customLong("source")],
            help: "Source language code, for example en or ja; use auto to detect it.")
    var source: String = "auto"

    @Option(name: [.customShort("t"), .customLong("target")],
            help: "Target language code, for example ja or en.")
    var target: String

    @Argument(help: "Text to translate. Omit or use '-' to read UTF-8 text from stdin.")
    var text: String?

    mutating func validate() throws {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Source and target language codes must not be empty.")
        }
    }

    mutating func run() throws {
        let input = try readInput()
        let sourceLanguage = source.caseInsensitiveCompare("auto") == .orderedSame
            ? nil
            : Locale.Language(identifier: source)
        let targetLanguage = Locale.Language(identifier: target)
        let translated = try MainActor.assumeIsolated {
            try TranslationRunner().run(input: input, source: sourceLanguage, target: targetLanguage)
        }
        print(translated)
    }

    private func readInput() throws -> String {
        let input: String
        if let text, text != "-" {
            input = text
        } else {
            guard isatty(STDIN_FILENO) == 0 else {
                throw ValidationError("Provide text as an argument or pipe UTF-8 text to stdin.")
            }
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw ValidationError("Standard input must be valid UTF-8.")
            }
            input = decoded
        }
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Text to translate must not be empty.")
        }
        return input
    }
}

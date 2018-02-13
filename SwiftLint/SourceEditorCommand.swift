//
//  SourceEditorCommand.swift
//  SwiftLint
//
//  Created by 野村 憲男 on 6/15/16.
//
//  Copyright (c) 2016 Norio Nomura
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import XcodeKit

let targetContentUTIs = ["public.swift-source", "com.apple.dt.playgroundpage"]

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {

        var error: Error? = nil
        defer { completionHandler(error) }

        if !targetContentUTIs.contains(invocation.buffer.contentUTI) { return }

        do {
            let fm = FileManager.default
            let temporaryDirectory = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("autocorrect") as NSString

            // create temporary directory
            if !fm.fileExists(atPath: temporaryDirectory as String) {
                try fm.createDirectory(atPath: temporaryDirectory as String,
                                       withIntermediateDirectories: true, attributes: nil)
            }

            // create empty .swiftlint.yml in temporary directory
            let config = temporaryDirectory.appendingPathComponent(".swiftlint.yml")
            if !fm.fileExists(atPath: config) {
                try "".write(toFile: config, atomically: true, encoding: .utf8)
            }

            // create temporary.swift in temporary directory
            let source = temporaryDirectory.appendingPathComponent("temporary.swift")
            try invocation.buffer.completeBuffer.write(toFile: source, atomically: true, encoding: .utf8)

            // run autocorrect
            switch invocation.commandIdentifier {
            case "io.github.norio-nomura.SwiftLintForXcode.SwiftLint.autocorrect":
                try autocorrect(directory: temporaryDirectory as String)
            case "io.github.norio-nomura.SwiftLintForXcode.SwiftLint.autocorrect-format":
                try autocorrect(directory: temporaryDirectory as String, arguments: ["--format"])
            default:
                throw SwiftLintError.unknownCommandIdentifier
            }

            // check result
            if let autocorrected = try? String(contentsOfFile: source) as NSString
                , invocation.buffer.completeBuffer != autocorrected as String {

                // update lines
                var start = 0, end = 0, lineIndex = 0
                var updatedLines = [Int]()
                let originalLineCount = invocation.buffer.lines.count
                while start < autocorrected.length {
                    let range = NSRange(location: start, length: 0)
                    autocorrected.getLineStart(&start, end: &end, contentsEnd: nil, for: range)
                    let lineRange = NSRange(location: start, length: end - start)
                    let newLine = autocorrected.substring(with: lineRange)

                    let originalLine = invocation.buffer.lines[lineIndex] as! NSString
                    if  originalLine as String != newLine {
                        if lineIndex < originalLineCount {
                            invocation.buffer.lines[lineIndex] = newLine
                        } else {
                            invocation.buffer.lines.add(newLine)
                        }
                        updatedLines.append(lineIndex)
                    }
                    lineIndex += 1
                    start = end
                }
                if lineIndex <= originalLineCount {
                    let indexSet = IndexSet(integersIn: lineIndex..<originalLineCount)
                    invocation.buffer.lines.removeObjects(at: indexSet)
                }

                // update selections
                let updatedSelections = updatedLines.map { (lineIndex: Int) -> XCSourceTextRange in
                    let range = XCSourceTextRange()
                    range.start = XCSourceTextPosition(line: lineIndex, column: 0)
                    range.end = XCSourceTextPosition(line: lineIndex + 1, column: 0)
                    return range
                }
                if !updatedSelections.isEmpty {
                    invocation.buffer.selections.setArray(updatedSelections)
                }
            }
        } catch let caughtError {
            print(caughtError)
            error = caughtError
            return
        }

    }

    deinit {
        connection.invalidate()
    }

    private let connection = { () -> NSXPCConnection in
        let connection = NSXPCConnection(serviceName: "io.github.norio-nomura.SwiftLintForXcode.SwiftLintHelper")
        connection.remoteObjectInterface = NSXPCInterface(with: SwiftLintHelperProtocol.self)
        return connection
    }()

    private enum SwiftLintError: Error, CustomNSError, CustomStringConvertible {
        case error(String)
        case helperConnectError
        case unknownCommandIdentifier

        // CustomNSError
        var errorUserInfo: [String : Any] {
            return [NSLocalizedDescriptionKey: description]
        }

        // CustomStringConvertible
        var description: String {
            switch self {
            case .error(let message): return "error: \(message)"
            case .helperConnectError: return "Helper Connectiont Error"
            case .unknownCommandIdentifier: return "Unknown Command Identifier"
            }
        }
    }

    typealias ReplyHandler = (Int, String, String) throws -> Void

    private func swiftlint(in directory: String, with arguments: [String], reply: ReplyHandler) throws {
        connection.resume()
        defer { connection.suspend() }
        guard let swiftlint = connection.remoteObjectProxy as? SwiftLintHelperProtocol else {
            print("Failt to connect: \(connection)")
            throw SwiftLintError.helperConnectError
        }
        let semaphore = DispatchSemaphore(value: 0)
        var (status, output, errorOutput) = (0, "", "")
        swiftlint.execute(in: directory, with: arguments) {
            (status, output, errorOutput) = ($0, $1, $2)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 10)
        try reply(status, output, errorOutput)
    }

    private func autocorrect(directory: String, arguments: [String] = []) throws {
        try swiftlint(in: directory, with: ["autocorrect"] + arguments) { status, output, errorOutput in
            if status != 0 {
                throw SwiftLintError.error(errorOutput)
            }
        }
    }
}

//
//  LoggingShim.swift
//  Audiobookphile
//
//  Portable Logger shim for platforms without OSLog (Android/Skip). On Apple
//  platforms the real `os.Logger` is used; here we fall back to stdout logging
//  so the same logging API compiles everywhere.
//

import Foundation

#if !canImport(OSLog)
public struct Logger: Sendable {
    private let subsystem: String
    private let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    private func emit(_ level: String, _ message: String) {
        print("[\(subsystem)] [\(category)] \(level): \(message)")
    }

    public func info(_ message: @autoclosure () -> String) {
        emit("info", message())
    }

    public func debug(_ message: @autoclosure () -> String) {
        emit("debug", message())
    }

    public func error(_ message: @autoclosure () -> String) {
        emit("error", message())
    }
}
#endif

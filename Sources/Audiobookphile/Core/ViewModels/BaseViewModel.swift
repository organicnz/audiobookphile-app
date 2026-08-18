//
//  BaseViewModel.swift
//  Audiobookphile
//
//  Shared base class for ViewModels, providing common loading and
//  error handling for the MVVM architecture.
//

import Foundation
import Observation

@MainActor
@Observable
open class BaseViewModel {
    /// Human-readable description of the most recent failure, if any.
    public var errorMessage: String?

    /// Default empty initializer.
    public init() {}

    /// Runs a throwing async operation, capturing any failure into
    /// `errorMessage`. Loading state is the responsibility of each
    /// concrete view model.
    public func perform(_ operation: () async throws -> Void) async {
        errorMessage = nil
        do {
            try await operation()
        } catch {
            print("[BaseViewModel] Operation failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

//
//  NavigationViewModel.swift
//  Audiobookphile
//
//  View model for app-level navigation: presentation sheets, tabs and
//  the currently open book detail.
//

import Foundation
import Observation

@MainActor
@Observable
public final class NavigationViewModel: BaseViewModel {
    public static let shared = NavigationViewModel()

    // MARK: - Book detail

    /// The book currently displayed in a detail view, if any.
    public var selectedBook: Book? {
        didSet { selectedBookId = selectedBook?.id }
    }

    /// The ID of the currently displayed book detail, if any.
    public private(set) var selectedBookId: String?

    /// The library the user is currently browsing.
    public var selectedLibraryId: String? {
        get { AppState.shared.currentLibraryId }
        set {
            AppState.shared.currentLibraryId = newValue
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: StorageKeys.lastLibraryId)
            }
        }
    }

    // MARK: - Presentation

    public var isShowingSettings: Bool { NavigationState.shared.showingSettings }
    public var isShowingStats: Bool { NavigationState.shared.showingStats }
    public var isShowingAccount: Bool { NavigationState.shared.showingAccount }
    public var isShowingConnectModal: Bool { NavigationState.shared.showingConnectModal }
    public var selectedTab: Int {
        get { NavigationState.shared.selectedTab }
        set { NavigationState.shared.selectedTab = newValue }
    }

    public func showSettings() { NavigationState.shared.showingSettings = true }
    public func showStats() { NavigationState.shared.showingStats = true }
    public func showAccount() { NavigationState.shared.showingAccount = true }
    public func showConnectModal() { NavigationState.shared.showingConnectModal = true }

    public func dismissAllSheets() {
        NavigationState.shared.showingSettings = false
        NavigationState.shared.showingStats = false
        NavigationState.shared.showingAccount = false
        NavigationState.shared.showingConnectModal = false
    }

    // MARK: - Book detail navigation

    public func openBook(_ book: Book) {
        selectedBook = book
    }

    public func closeBook() {
        selectedBook = nil
    }
}

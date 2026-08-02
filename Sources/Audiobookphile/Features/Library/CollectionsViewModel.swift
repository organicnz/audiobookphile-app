//
//  CollectionsViewModel.swift
//  Audiobookphile
//
//  Manages the state and API calls for the Collections tab.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

@Observable
@MainActor
public class CollectionsViewModel {
    public var series: [SeriesSummary] = []
    public var collections: [CollectionSummary] = []
    public var playlists: [PlaylistSummary] = []
    
    public var isLoading: Bool = false
    public var error: Error?

    public init() {}

    public func loadData(libraryId: String?, isAuthenticated: Bool, type: CollectionsView.CollectionType) async {
        guard isAuthenticated else { return }
        
        isLoading = true
        error = nil
        
        do {
            switch type {
            case .series:
                if series.isEmpty {
                    let service = LiveLibraryService()
                    let response = try await service.fetchSeries(libraryId: libraryId, page: 0)
                    self.series = response.results
                }
            case .collections:
                if collections.isEmpty {
                    // API implementation can be hooked up here later
                    self.collections = []
                }
            case .playlists:
                if playlists.isEmpty {
                    // API implementation can be hooked up here later
                    self.playlists = []
                }
            }
        } catch {
            print("[CollectionsViewModel] Failed to fetch \(type.rawValue): \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    public func refresh(libraryId: String?, isAuthenticated: Bool, type: CollectionsView.CollectionType) async {
        switch type {
        case .series:
            series = []
        case .collections:
            collections = []
        case .playlists:
            playlists = []
        }
        
        await loadData(libraryId: libraryId, isAuthenticated: isAuthenticated, type: type)
    }
}

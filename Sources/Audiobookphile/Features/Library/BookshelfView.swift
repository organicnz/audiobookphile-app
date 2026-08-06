//
//  BookshelfView.swift
//  Audiobookphile
//
//  Main library view with glass design and parallax.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

/// Main bookshelf/library view
public struct BookshelfView: View {
    @State var viewModel = BookshelfViewModel()
    var proMotion = ProMotionManager.shared
    @Environment(AppState.self) private var appState
    @State var showSearch = false
    @State var searchText = ""
    @State var scrollOffset: CGFloat = 0
    @State var selectedBookForDetails: Book?

    @State var selectedPill: LibraryPill = .library
    
    enum LibraryPill: String, CaseIterable {
        case library = "Library"
        case authors = "Authors"
        case narrators = "Narrators"
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Animated background with particles
            backgroundLayer

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Main library grid
                    if selectedPill == .library {
                        libraryGridSection
                    } else {
                        // Placeholder for Authors/Narrators
                        VStack(spacing: 20) {
                            Spacer().frame(height: 100)
                            Image(systemName: "person.2.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("\(selectedPill.rawValue) Coming Soon")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                })
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            #if os(iOS) || SKIP
            .refreshable {
                await viewModel.refresh(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
            }
            #endif

            // Search overlay
            if showSearch {
                searchOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationDestination(item: $selectedBookForDetails) { book in
            BookDetailView(book: book)
        }
        .audiobookphileNavigationToolbar(title: "Library")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Library View", selection: $selectedPill) {
                    Text("Library").tag(LibraryPill.library)
                    Text("Authors").tag(LibraryPill.authors)
                    Text("Narrators").tag(LibraryPill.narrators)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(.appPrimary)
            }
            #if os(iOS) || SKIP
            ToolbarItem(placement: .topBarTrailing) {
                if selectedPill == .library {
                    Button(action: viewModel.showFilterOptions) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(.primary)
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                if selectedPill == .library {
                    Button(action: viewModel.showFilterOptions) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(.primary)
                }
            }
            #endif
        }
        .task(id: LibraryLoadTrigger(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)) {
            await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
        .applySensoryFeedback(trigger: selectedBookForDetails != nil)
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        Color.appBackground.ignoresSafeArea()
    }

    // MARK: - Navigation Pills removed in favor of Toolbar Picker

    // (Continue listening moved to HomeView)

    // MARK: - Library Grid

    private var libraryGridSection: some View {
        BookshelfGridSection(viewModel: viewModel, selectedBookForDetails: $selectedBookForDetails)
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        BookshelfSearchOverlay(searchText: $searchText, showSearch: $showSearch, viewModel: viewModel, selectedBookForDetails: $selectedBookForDetails)
    }

    // MARK: - End BookshelfView
}

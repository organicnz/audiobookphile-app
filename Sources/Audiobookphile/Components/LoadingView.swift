//
//  LoadingView.swift
//  Audiobookphile
//
//  Reusable loading overlay with frosted glass.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct LoadingView: View {
    public let message: String

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                #if os(iOS)
                .controlSize(.large)
                #endif
                .tint(.appPrimary)
            
            Text(message)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.15), radius: 20)
    }
}

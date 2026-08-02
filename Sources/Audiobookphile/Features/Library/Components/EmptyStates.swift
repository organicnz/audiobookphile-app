//
//  EmptyStates.swift
//  Audiobookphile
//

import SwiftUI

public struct EmptyLibraryView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundStyle(Color.secondary.opacity(0.6))

            Text("No Content Available")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)

            Text("Your personalized content will appear here")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

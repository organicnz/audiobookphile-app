//
//  StatsView.swift
//  Audiobookphile
//
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct StatsView: View {
    // In a real implementation this would fetch from an API or local CoreData
    // For now we use placeholder stats as agreed for local storage tracking.
    @State private var totalListeningTime: TimeInterval = 145 * 3600 + 30 * 60 // 145h 30m
    @State private var totalBooksFinished = 12
    @State private var currentStreak = 5
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.appPrimary)
                            .padding(.bottom, 8)
                        
                        Text("Listening Stats")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // Main Stat
                    VStack(spacing: 8) {
                        Text("Total Time Listened")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(formatTotalTime(totalListeningTime))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    
                    // Stats Grid
                    HStack(spacing: 16) {
                        statCard(title: "Books Finished", value: "\(totalBooksFinished)", icon: "book.closed.fill", color: .green)
                        statCard(title: "Current Streak", value: "\(currentStreak) Days", icon: "flame.fill", color: .orange)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Stats")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatTotalTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
}

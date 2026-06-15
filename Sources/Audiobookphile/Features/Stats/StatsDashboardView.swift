import SwiftUI

public struct StatsDashboardView: View {
    let title: String
    
    public init(title: String = "Listening Stats") {
        self.title = title
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Heatmap Mock
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Listening Activity")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(0..<28, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appPrimary.opacity(Double.random(in: 0.2...1.0)))
                                    .aspectRatio(1.0, contentMode: .fit)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Finished Books Mock
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Finished Books (This Year)")
                            .font(.headline)
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach([3, 5, 2, 8, 4, 10, 6], id: \.self) { count in
                                VStack {
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.appPrimary)
                                        .frame(height: CGFloat(count * 10))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .applyBookshelfScrollTransition()
            .navigationTitle("Stats")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .applyToolbarAdapters(isLight: false, isHidden: false)
        }
    }
}

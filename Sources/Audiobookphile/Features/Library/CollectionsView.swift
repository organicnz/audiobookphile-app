import SwiftUI

public struct CollectionsView: View {
    public init() {}
    public var body: some View {
        VStack {
            Text("Collections")
                .font(.largeTitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 250/255, green: 249/255, blue: 246/255)) // Cream
        .navigationTitle("Collections")
    }
}

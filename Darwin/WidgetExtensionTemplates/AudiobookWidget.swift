import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - App Intent for Interactive Widgets
import AppIntents

@available(iOS 17.0, *)
struct TogglePlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Playback"

    func perform() async throws -> some IntentResult {
        // You would dispatch a notification or use shared UserDefaults to tell the main app to play/pause
        return .result()
    }
}

// MARK: - Live Activity Attributes
struct AudiobookPlaybackAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var progress: Double
        var chapterName: String
    }

    var bookTitle: String
    var author: String
}

// MARK: - Live Activity View
@available(iOS 16.1, *)
struct AudiobookWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudiobookPlaybackAttributes.self) { context in
            // Lock screen/banner UI goes here
            HStack {
                Image(systemName: "book.closed")
                VStack(alignment: .leading) {
                    Text(context.attributes.bookTitle).font(.headline)
                    Text(context.state.chapterName).font(.caption)
                }
                Spacer()
                Button(intent: TogglePlaybackIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.bookTitle)
                }
            } compactLeading: {
                Image(systemName: "book.fill")
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "chart.bar.fill" : "play.fill")
            } minimal: {
                Image(systemName: "book.fill")
            }
        }
    }
}

// MARK: - Home Screen Widget
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: "Sample Book", author: "Author", progress: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(getEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries: [SimpleEntry] = []
        entries.append(getEntry())
        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
    
    private func getEntry() -> SimpleEntry {
        guard let defaults = UserDefaults(suiteName: "group.organicnz.audiobookphile"),
              let stateDict = defaults.dictionary(forKey: "audiobookWidgetState") else {
            return SimpleEntry(date: Date(), title: "No Book Playing", author: "", progress: 0)
        }
        
        let title = stateDict["bookTitle"] as? String ?? "Unknown Title"
        let author = stateDict["author"] as? String ?? ""
        let progress = stateDict["progress"] as? Double ?? 0
        let duration = stateDict["duration"] as? Double ?? 1
        
        return SimpleEntry(date: Date(), title: title, author: author, progress: progress / max(duration, 1.0))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String
    let author: String
    let progress: Double
}

struct AudiobookWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
            if !entry.author.isEmpty {
                Text(entry.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.3))
                        .frame(height: 6)
                    Capsule().fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(entry.progress), height: 6)
                }
            }.frame(height: 6)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.black
        }
        .environment(\.colorScheme, .dark)
    }
}

struct AudiobookWidget: Widget {
    let kind: String = "AudiobookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AudiobookWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Current Audiobook")
        .description("Quickly see what you're reading.")
    }
}

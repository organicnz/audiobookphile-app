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
        SimpleEntry(date: Date(), title: "Sample Book")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), title: "Sample Book")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries: [SimpleEntry] = []
        let entry = SimpleEntry(date: Date(), title: "Sample Book")
        entries.append(entry)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String
}

struct AudiobookWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text(entry.title)
                .font(.headline)
            Text("Currently Reading")
                .font(.caption)
        }
        .containerBackground(for: .widget) {
            Color.blue.gradient
        }
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

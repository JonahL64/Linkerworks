//
//  LinkerworksWidgetLiveActivity.swift
//  LinkerworksWidget
//
//  Created by Jonah Linker on 7/21/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LinkerworksWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LinkerworksWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LinkerworksWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color("TrainingBackground"))
            .activitySystemActionForegroundColor(Color("PrimaryText"))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .keylineTint(Color("PrimaryText"))
        }
    }
}

extension LinkerworksWidgetAttributes {
    fileprivate static var preview: LinkerworksWidgetAttributes {
        LinkerworksWidgetAttributes(name: "World")
    }
}

extension LinkerworksWidgetAttributes.ContentState {
    fileprivate static var smiley: LinkerworksWidgetAttributes.ContentState {
        LinkerworksWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LinkerworksWidgetAttributes.ContentState {
         LinkerworksWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LinkerworksWidgetAttributes.preview) {
   LinkerworksWidgetLiveActivity()
} contentStates: {
    LinkerworksWidgetAttributes.ContentState.smiley
    LinkerworksWidgetAttributes.ContentState.starEyes
}

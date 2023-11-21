import SwiftUI
import CoreData

public struct ToolsView: View {
    let score:Score
    let helpMetronome:String
    
    public init(score:Score, helpMetronome:String) {
        self.score = score
        self.helpMetronome = helpMetronome
    }
    
    public var body: some View {
        VStack {
            HStack {
                MetronomeView(score:score, helpText: helpMetronome, frameHeight: score.lineSpacing * 6)
                    //.padding(.horizontal)
                    .padding()
//                VoiceCounterView(frameHeight: frameHeight)
//                    //.padding(.horizontal)
//                    .padding()
            }
        }
    }
}



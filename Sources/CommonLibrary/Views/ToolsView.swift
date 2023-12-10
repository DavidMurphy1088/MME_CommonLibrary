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
                MetronomeView(timeSignature:score.timeSignature, helpText: helpMetronome, 
                              frameHeight: score.lineSpacing * 6, backgroundColor: Settings.shared.colorInstructions)
                    //.padding(.horizontal)
                    .padding()
//                VoiceCounterView(frameHeight: frameHeight)
//                    //.padding(.horizontal)
//                    .padding()
            }
        }
    }
}



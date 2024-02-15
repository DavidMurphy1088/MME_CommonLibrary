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
            Text(" ") ///This view is at the top of a view inside a ScrollView which for some unknown reason scrolls the top of the metronome off the top of the screen so space it down some :(
            HStack {
                MetronomeView(timeSignature:score.timeSignature, helpText: helpMetronome, 
                              frameHeight: score.lineSpacing * 6, 
                              //backgroundColor: Settings.shared.colorScore
                              backgroundColor: Color.white
                )
                    .padding()
//                VoiceCounterView(frameHeight: frameHeight)
//                    //.padding(.horizontal)
//                    .padding()
            }
        }
    }
}



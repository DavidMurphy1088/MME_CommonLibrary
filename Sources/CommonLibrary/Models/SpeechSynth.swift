import SwiftUI
import AVFoundation

class SpeechSynthesizer {
    static let shared = SpeechSynthesizer()
    let synthesizer = AVSpeechSynthesizer()
    //var voice:AVSpeechSynthesisVoice?
    var config = true
    var voiceToUse:AVSpeechSynthesisVoice?
    var logger = Logger.logger
    
    init() {
        voiceToUse = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-AU.Karen")
        if voiceToUse == nil {
            let voices = AVSpeechSynthesisVoice.speechVoices()
            for voice in voices {
                if voice.name.contains("Saman") {//"Saman"
                    if voice.name.contains("Saman") {//"Saman"
                        voiceToUse = voice
                    }
                }
            }
        }
    }
    
    func speakWord(_ word: String) {
        if config {
            //voice = AVSpeechSynthesisVoice(identifier: identifier)
            config = false
        }
        let utterance = AVSpeechUtterance(string: word)
        //utterance.rate = 0.1
        utterance.voice = voiceToUse
        synthesizer.speak(utterance)
    }

}

//struct ContentView: View {
//    let synthesizer = AVSpeechSynthesizer()
//
//    var body: some View {
//        Button(action: {
//            speakWord("Hello", withVoiceIdentifier: "en-AU")
//        }) {
//            Text("Speak")
//                .font(.headline)
//                .padding()
//                .background(Color.blue)
//                .foregroundColor(.white)
//                .cornerRadius(10)
//        }
//    }
//
//    func speakWord(_ word: String, withVoiceIdentifier identifier: String) {
//        let voice = AVSpeechSynthesisVoice(identifier: identifier)
//        let utterance = AVSpeechUtterance(string: word)
//        utterance.voice = voice
//
//        synthesizer.speak(utterance)
//    }
//}

struct VoiceListView: View {
    @State private var selectedVoice: AVSpeechSynthesisVoice?
    @State private var isSpeaking: Bool = false
    @State var ctr = 0
    
    let synthesizer = AVSpeechSynthesizer()
    let voices = AVSpeechSynthesisVoice.speechVoices()
    
    var body: some View {
        VStack {
            List(voices, id: \.identifier) { voice in
                Button(action: {
                    selectedVoice = voice
                    speakWord("Hello World", withVoice: voice)
                    ctr += 1
                }) {
                    Text(voice.language)
                        .foregroundColor(selectedVoice == voice ? .blue : .primary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            Spacer()
            
            Button(action: {
                stopSpeaking()
            }) {
                Text(isSpeaking ? "Stop" : "Start")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .disabled(selectedVoice == nil)
        }
    }
    
    func speakWord(_ word: String, withVoice voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

struct AllVoicesView: View {
    var body: some View {
        VoiceListView()
    }
}


import Foundation
import Accelerate
import AVFoundation

enum TickType {
    case metronome
    case handclap
}

/// Provide sampled audio as ticks for metronome
class MetronomeTickerPlayer {
    private var timeSignature:TimeSignature
    
    //Use an array so that sound n+1 can start before n finishes. Required for faster tempos and short note values.
    private var audioPlayersLow:[AVAudioPlayer] = []
    private var audioPlayersHigh:[AVAudioPlayer] = []
    private var numAudioPlayers = 16
    private var nextPlayer = 0
    private var duration = 0.0
    private var newBar = true
    
    init(timeSignature: TimeSignature, tickStyle:Bool) {
        self.timeSignature = timeSignature
        //https://samplefocus.com/samples/short-ambient-clap-one-shot
        if tickStyle {
            audioPlayersLow = loadAudioPlayer(name: "Mechanical metronome - Low", ext: "aif")
            audioPlayersHigh = loadAudioPlayer(name: "Mechanical metronome - Low", ext: "aif")
        }
        else {
            audioPlayersLow = loadAudioPlayer(name: "clap-single-inspectorj", ext: "wav")
            audioPlayersHigh = loadAudioPlayer(name: "clap-single-inspectorj", ext: "wav")
        }
    }
    
    func loadAudioPlayer(name:String, ext:String) -> [AVAudioPlayer] {
        var audioPlayers:[AVAudioPlayer] = []
        let clapURL:URL?
        clapURL = Bundle.main.url(forResource: name, withExtension: ext)

        if clapURL == nil {
            Logger.logger.reportError(self, "Cannot load resource \(name)")
        }
        for _ in 0..<numAudioPlayers {
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: clapURL!)
                //if audioPlayer != nil {
                    audioPlayers.append(audioPlayer)
                    audioPlayer.prepareToPlay()
                    audioPlayer.volume = 1.0 // Set the volume to full
                    audioPlayer.rate = 2.0
                //}
            }
            catch  {
                Logger.logger.reportError(self, "Cannot prepare AVAudioPlayer")
            }
        }
        return audioPlayers
    }
    
    func soundTick(noteValue:Double?=nil, silent:Bool) {
        let nextAudioPlayer = newBar ? audioPlayersHigh[nextPlayer] : audioPlayersLow[nextPlayer]
        nextAudioPlayer.volume = newBar ? 1.0 : 0.33
        if !silent {
            nextAudioPlayer.play()
        }
        nextPlayer += 1
        if nextPlayer > numAudioPlayers - 1 {
            nextPlayer = 0
        }
        if let noteValue = noteValue {
            duration += noteValue
            newBar = duration >= Double(timeSignature.top)
            if newBar {
                duration = 0
            }
        }
    }
}

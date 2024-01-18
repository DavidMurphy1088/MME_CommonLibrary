import Foundation
import Accelerate
import AVFoundation

enum TickType {
    case metronome
    case handclap
}

/// Provide sampled audio as ticks for metronome
class MetronomeTickerPlayer {
    //Use an array so that sound n+1 can start before n finishes. Required for faster tempos and short note values.
    private var audioPlayersLow:[AVAudioPlayer] = []
    private var audioPlayersHigh:[AVAudioPlayer] = []
    private var numAudioPlayers = 1
    private var nextPlayer = 0
    private var duration = 0.0
    private var newBar = true
    
    init(tickStyle:Bool) {
        //self.timeSignature = timeSignature
        //https://samplefocus.com/samples/short-ambient-clap-one-shot
        if tickStyle {
            audioPlayersLow = loadAudioPlayer(name: "metronome_mechanical_low", ext: "aiff")
            audioPlayersHigh = loadAudioPlayer(name: "metronome_mechanical_high", ext: "aiff")
        }
        else {
            audioPlayersLow = loadAudioPlayer(name: "clap", ext: "aiff")
            audioPlayersHigh = loadAudioPlayer(name: "clap", ext: "aiff")
        }
    }
    
    func loadAudioPlayer(name:String, ext:String) -> [AVAudioPlayer] {
        var audioPlayers:[AVAudioPlayer] = []
        let clapURL = Bundle.module.url(forResource: name, withExtension: ext)

        if clapURL == nil {
            Logger.logger.reportError(self, "Cannot load resource \(name)")
        }
        for i in 0..<numAudioPlayers {
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: clapURL!)
                audioPlayers.append(audioPlayer)
                audioPlayer.prepareToPlay()
                audioPlayer.volume = 1.0 // Set the volume to full
                audioPlayer.rate = 2.0
            }
            catch  {
                Logger.logger.reportError(self, "Cannot prepare AVAudioPlayer")
            }
        }
        Logger.logger.log(self, "Loaded \(numAudioPlayers) audio players")
        return audioPlayers
    }
    
    func soundTick(timeSignature: TimeSignature, noteValue:Double?=nil, silent:Bool) {
        ///Stronger beat on first downbeat
        let nextAudioPlayer = newBar ? audioPlayersHigh[nextPlayer] : audioPlayersLow[nextPlayer]
        //nextAudioPlayer.volume = newBar ? 1.0 : 0.33
        nextAudioPlayer.volume = newBar ? 1.0 : 0.50
        if !silent {
            nextAudioPlayer.play()
        }
        nextPlayer += 1
        if nextPlayer > numAudioPlayers - 1 {
            nextPlayer = 0
        }
        var tickValue:Double? = nil
        if let noteValue = noteValue {
            tickValue = noteValue
        }
//        else {
//            tickValue = 1.0
//        }
        
        if let tickValue = tickValue {
            duration += tickValue
            newBar = duration >= Double(timeSignature.top)
            if newBar {
                duration = 0
            }
        }
    }
}

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
    private var numAudioPlayers = 1
    private var nextPlayer = 0
    private var duration = 0.0
    private var newBar = true
    
    init(timeSignature: TimeSignature, tickStyle:Bool) {
        self.timeSignature = timeSignature
        //https://samplefocus.com/samples/short-ambient-clap-one-shot
        //log("Init \(tickStyle)")
        if tickStyle {
            //audioPlayersLow = loadAudioPlayer(name: "Mechanical metronome - Low", ext: "aif")
            //audioPlayersHigh = loadAudioPlayer(name: "Mechanical metronome - Low", ext: "aif")
            audioPlayersLow = loadAudioPlayer(name: "metronome_mechanical_low", ext: "aiff")
            audioPlayersHigh = loadAudioPlayer(name: "metronome_mechanical_high", ext: "aiff")
        }
        else {
//            audioPlayersLow = loadAudioPlayer(name: "clap-single-inspectorj", ext: "wav")
//            audioPlayersHigh = loadAudioPlayer(name: "clap-single-inspectorj", ext: "wav")
            audioPlayersLow = loadAudioPlayer(name: "clap", ext: "aiff")
            audioPlayersHigh = loadAudioPlayer(name: "clap", ext: "aiff")
        }
    }
    
//    public func log(_ msg:String) {
//        print("========= MetronomeTickerPlayer", msg)
//    }

    func loadAudioPlayer(name:String, ext:String) -> [AVAudioPlayer] {
        var audioPlayers:[AVAudioPlayer] = []
        let clapURL = Bundle.module.url(forResource: name, withExtension: ext)

        if clapURL == nil {
            Logger.logger.reportError(self, "Cannot load resource \(name)")
        }
        for i in 0..<numAudioPlayers {
            do {
                //log("create audio \(i)")
                let audioPlayer = try AVAudioPlayer(contentsOf: clapURL!)
                audioPlayers.append(audioPlayer)
                audioPlayer.prepareToPlay()
                audioPlayer.volume = 1.0 // Set the volume to full
                audioPlayer.rate = 2.0
                //log("end create audio \(i)")
            }
            catch  {
                Logger.logger.reportError(self, "Cannot prepare AVAudioPlayer")
            }
        }
        return audioPlayers
    }
    
    func soundTick(noteValue:Double?=nil, silent:Bool) {
        let nextAudioPlayer = newBar ? audioPlayersHigh[nextPlayer] : audioPlayersLow[nextPlayer]
        //let nextAudioPlayer = newBar ? audioPlayersLow[nextPlayer] : audioPlayersLow[nextPlayer]
        nextAudioPlayer.volume = newBar ? 1.0 : 0.33
        //log("soundTick \(nextAudioPlayer.volume) Bar:\(newBar)")
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

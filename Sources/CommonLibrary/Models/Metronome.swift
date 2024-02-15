import SwiftUI
import CoreData
import AVFoundation

public class Metronome: ObservableObject  {
    
    static private var shared:Metronome = Metronome()
    static private var nextInstrument = 0
    
    let id = UUID()
    @Published public var clapCounter = 0
    @Published public var tempoName:String = ""
    @Published private var tempo:Int = 60
    @Published public var allowChangeTempo:Bool = false
    @Published public var tickingIsActive = false
    @Published public var speechEnabled = false
    
    public var tempoMinimumSetting = 40 //90
    public var tempoMaximumSetting = 145 //120
    
    public var tickTimes:[Date] = []
    public var nextTickTime:Date?
    
    var setCtr = 0

    let audioTickerMetronomeTick:MetronomeTickerPlayer = MetronomeTickerPlayer(tickStyle: true)
    let audioClapper:MetronomeTickerPlayer = MetronomeTickerPlayer(tickStyle: false)

    private var clapCnt = 0
    private var isThreadRunning = false
    private var score:Score?
    private var nextScoreIndex = 0
    private var nextScoreTimeSlice:TimeSlice?
    private var currentNoteTimeToLive = 0.0

    //the shortest note value which is used to set the metronome's thread firing frequency
    private let shortestNoteValue = Note.VALUE_SEMIQUAVER
    
    private let speech = SpeechSynthesizer.shared
    private var onDoneFunction:(()->Void)? = nil
    
    public static func getMetronomeWithSettings(_ ctx:String, initialTempo:Int, allowChangeTempo:Bool,
                                                minTempo:Int? = nil, maxTempo:Int? = nil) -> Metronome {
        shared.setTempo("getMetronomeWithSettings \(ctx)", tempo: initialTempo)
        shared.setAllowTempoChange("getMetronomeWithSettings", allow: allowChangeTempo)
        if let tempo = minTempo {
            shared.tempoMinimumSetting = tempo
        }
        if let tempo = maxTempo {
            shared.tempoMaximumSetting = tempo
        }
        return Metronome.shared
    }

    public static func getMetronomeWithCurrentSettings(ctx:String) -> Metronome {
        return Metronome.shared
    }

    public init() {
        //super.init(parent: "Metronome")
    }

    public func getTempo() -> Int {
        return self.tempo
    }
    
    public func setSpeechEnabled(enabled:Bool) {
        DispatchQueue.main.async {
            self.speechEnabled = enabled
        }
    }
    
    public func startTicking(timeSignature:TimeSignature) {
        //let audioSamplerMIDI = AudioSamplerPlayer.shared.sampler
        //let audioTicker:AudioSamplerPlayer = AudioSamplerPlayer(timeSignature: score.timeSignature)
        //setTempo(tempo: self.tempo)
        DispatchQueue.main.async {
            self.tickingIsActive = true
            if !self.isThreadRunning {
                //self.log("start thread")
                self.startPlayThreadRunning(timeSignature: timeSignature)
            }
        }
    }
    
    public func stopTicking() {
        //self.tickingIsActive = false
        DispatchQueue.main.async {
            //Logger.logger.log(self, "set stopTicking")
            self.tickingIsActive = false
        }
    }

    public func setTempo(_ ctx:String, tempo: Int, allowBeyondLimits:Bool = false) {
        //https://theonlinemetronome.com/blogs/12/tempo-markings-defined
        var tempoToSet:Int
        var maxTempo = self.tempoMaximumSetting
        var minTempo = self.tempoMinimumSetting
        
        if allowBeyondLimits {
            maxTempo = 250
            minTempo = 50
        }
        if tempo < minTempo {
            tempoToSet = minTempo
        }
        else {
            if tempo > maxTempo {
                tempoToSet = maxTempo
            }
            else {
                tempoToSet = tempo
            }
        }
        
        if self.tempo == tempoToSet {
            return
        }
        setCtr += 1

        var name = ""
        if tempoToSet <= 20 {
            name = "Larghissimo"
        }
        if tempoToSet > 20 && tempo <= 40 {
            name = "Solenne/Grave"
        }
        if tempoToSet > 40 && tempo <= 59 {
            name = "Lento"
        }
        if tempoToSet > 59 && tempo <= 72 {
            name = "Adagio"
        }
        if tempoToSet > 72 && tempo <= 76 {
            name = "Andante"
        }
        if tempoToSet > 76 && tempo <= 83 {
            name = "Andantino"
        }
        if tempoToSet > 83  && tempo <= 120 {
            name = "Moderato"
        }
        if tempoToSet > 120  && tempo <= 128 {
            name = "Allegretto"
        }
        if tempoToSet > 128  && tempo <= 180 {
            name = "Allegro"
        }
        if tempoToSet > 180  {
            name = "Presto"
        }
        if tempoToSet > 200 {
            name = "*"
        }
        DispatchQueue.main.async {
            self.tempo = tempoToSet
            self.tempoName = name
        }
    }
    
    public func setAllowTempoChange(_ ctx:String, allow:Bool) {
        DispatchQueue.main.async {
            self.allowChangeTempo = allow
        }
    }
    
    public func playScore(score:Score, rhythmNotesOnly:Bool=false, onDone: (()->Void)? = nil) {
        //find the first note to play
        nextScoreIndex = 0
        if score.scoreEntries.count > 0 {
            if score.scoreEntries[0] is TimeSlice {
                let next = score.scoreEntries[0] as! TimeSlice
                if next.getTimeSliceEntries().count > 0 {
                    self.score = score
                    self.nextScoreTimeSlice = next
                    self.currentNoteTimeToLive = nextScoreTimeSlice!.getTimeSliceEntries()[0].getValue()
                    self.onDoneFunction = onDone
                }
            }
        }
        nextScoreIndex = 1
        if !self.isThreadRunning {
            startPlayThreadRunning(timeSignature: score.timeSignature)
        }
    }
    
    public func stopPlayingScore() {
        DispatchQueue.main.async {
            self.score = nil
            //AudioSamplerPlayer.shared.stopSampler()
        }
    }

    public func noteCountSpeechWord(currentTimeValue:Double) -> String {
        var word = ""
        if currentTimeValue.truncatingRemainder(dividingBy: 1) == 0 {
            let cvInt = Int(currentTimeValue)
            if let score = score {
                switch cvInt %  score.timeSignature.top {
                case 0 :
                    word = "one"
                    
                case 1 :
                    word = "two"
                    
                case 2 :
                    word = "three"
                    
                default :
                    word = "four"
                }
            }
        }
        else {
            word = ""
        }
        return word
    }
    
    private func getSleepTime() -> Double {
        ///Last number is an attempt to sync with Google metronome
        return (60.0 / Double(self.tempo)) * shortestNoteValue * (self.tempo < 80 ? 0.94 : 0.885)
    }
    
    private func startPlayThreadRunning(timeSignature:TimeSignature) {
        self.isThreadRunning = true
        AudioManager.shared.checkReadyToPlay("Metronome.startPlayThreadRunning. Temo:\(self.tempo)")

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var loopCtr = 0
            var keepRunning = true
            var currentTimeValue = 0.0
            var ticksPlayed = 0
            var firstNote = true
            var tieWasFound = false
            //var debug = true
            //var lastTime = Date()

            while keepRunning {
                ///Sound the metronome tick. %4 because its counting at semiquaver intervals
                ///Make sure score playing is synched to the metronome tick
                if loopCtr % 4 == 0 {
                    if self.tickingIsActive {
                        audioTickerMetronomeTick.soundMetronomeTick(timeSignature: timeSignature, silent: false)
                        ticksPlayed += 1
                    }
                }
                
                ///Sound the next note
                if (firstNote && loopCtr % 4 == 0) || (!firstNote) {
                    if let score = score {
                        firstNote = false
                        if let timeSlice = nextScoreTimeSlice {
                            if timeSlice.entries.count > 0 {
                                let entry = timeSlice.entries[0]
                                if currentNoteTimeToLive >= entry.getValue() {
                                    if entry is Rest {
                                        audioClapper.soundMetronomeTick(timeSignature: timeSignature, noteValue: entry.getValue(), silent: true)
                                    }
                                    else {

                                        for note in timeSlice.getTimeSliceNotes() {
                                            if tieWasFound {
                                                tieWasFound = false
                                            }
                                            else {
                                                if note.isOnlyRhythmNote  {
                                                    audioClapper.soundMetronomeTick(timeSignature: timeSignature, noteValue: note.getValue(), silent: false)
                                                }
                                                else {
                                                    AudioManager.shared.playPitch(midiPitch: note.midiNumber)
                                                }
                                                note.setHilite(hilite: true)
                                                DispatchQueue.global(qos: .background).async {
                                                    Thread.sleep(forTimeInterval: 0.5)
                                                    note.setHilite(hilite: false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            //determine what time slice comes on the next tick. e.g. possibly for a long note the current time slice needs > 1 tick
                            currentNoteTimeToLive -= self.shortestNoteValue
                            if currentNoteTimeToLive <= 0 {
                                //look for the next note (or rest) to play
                                nextScoreTimeSlice = nil
                                while nextScoreIndex < score.scoreEntries.count {
                                    let entry = score.scoreEntries[nextScoreIndex]
                                    if entry is TimeSlice {
                                        nextScoreTimeSlice = (entry as! TimeSlice)
                                        if nextScoreTimeSlice!.entries.count > 0 {
                                            nextScoreIndex += 1
                                            currentNoteTimeToLive = nextScoreTimeSlice!.entries[0].getValue()
                                            break
                                        }
                                    }
                                    if entry is BarLine {
                                        currentTimeValue = 0
                                    }
                                    if entry is Tie {
                                        tieWasFound = true
                                    }
                                    nextScoreIndex += 1
                                }
                            }
                        }
                    }
                }

//                if speechEnabled {
//                    if loopCtr % 2 == 0 {
//                        let word = noteCountSpeechWord(currentTimeValue: currentTimeValue)
//                        speech.speakWord(word)
//                    }
//                    else {
//                        //quavers say 'and'
//                        if noteValueSpeechWord != nil {
//                            speech.speakWord(noteValueSpeechWord!)
//                        }
//                    }
//                }
                currentTimeValue += shortestNoteValue
                if score == nil {
                    firstNote = true
                }
                else {
                    if nextScoreTimeSlice == nil {
                        if self.onDoneFunction != nil {
                            self.onDoneFunction!()
                        }
                        self.onDoneFunction = nil
                        score = nil
                        firstNote = true
                    }
                }

                if !tickingIsActive {
                    keepRunning = score != nil
                }

                if keepRunning {
                    let sleepTime = getSleepTime()
                    ///Add more granularity to tickTime so timed tests can get more accurate note durations
                    for _ in 0..<2 {
                        Thread.sleep(forTimeInterval: sleepTime / 2.0)
                        let now = Date()
                        tickTimes.append(Date())
                        nextTickTime = now.addingTimeInterval(sleepTime / 2.0)
                    }
                    loopCtr += 1
                }
            }
            self.isThreadRunning = false
        }
    }
}


import SwiftUI
import CoreData
import AVFoundation

class Metronome: AudioPlayerUser, ObservableObject  {
    
    static private var shared:Metronome = Metronome()
    static private var nextInstrument = 0
    
    let id = UUID()
    @Published var clapCounter = 0
    @Published var tempoName:String = ""
    @Published var tempo:Int = 60
    @Published var allowChangeTempo:Bool = false
    @Published var tickingIsActive = false
    @Published var speechEnabled = false

    let tempoMinimumSetting = 60
    let tempoMaximumSetting = 120
    var setCtr = 0

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
    
    static func getMetronomeWithSettings(initialTempo:Int, allowChangeTempo:Bool, ctx:String) -> Metronome {
        shared.setTempo(tempo: initialTempo, context: "getMetronomeWithSettings - \(ctx)")
        shared.allowChangeTempo = allowChangeTempo
        return Metronome.shared
    }

    static func getMetronomeWithCurrentSettings(ctx:String) -> Metronome {
        return Metronome.shared
    }

    private init() {
        super.init(parent: "Metronome")
    }
    
    func setSpeechEnabled(enabled:Bool) {
        DispatchQueue.main.async {
            self.speechEnabled = enabled
        }
    }
    
    func startTicking(score:Score) {
        //let audioSamplerMIDI = AudioSamplerPlayer.shared.sampler
        //let audioTicker:AudioSamplerPlayer = AudioSamplerPlayer(timeSignature: score.timeSignature)
        //setTempo(tempo: self.tempo)
        DispatchQueue.main.async {
            self.tickingIsActive = true
            if !self.isThreadRunning {
                self.startPlayThreadRunning(timeSignature: score.timeSignature)
            }
        }
    }
    
    func stopTicking() {
        //self.tickingIsActive = false
        DispatchQueue.main.async {
            //Logger.logger.log(self, "set stopTicking")
            self.tickingIsActive = false
        }
    }

    func setTempo(tempo: Int, context:String, allowBeyondLimits:Bool = false) {
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
    
    func setAllowTempoChange(allow:Bool) {
        DispatchQueue.main.async {
            self.allowChangeTempo = allow
        }
    }
    
    func playScore(score:Score, rhythmNotesOnly:Bool=false, onDone: (()->Void)? = nil) {
//        let audioSamplerMIDI = AudioSamplerPlayer.shared.sampler
//        AudioSamplerPlayer.shared.startSampler()
        
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
    
    func stopPlayingScore() {
        DispatchQueue.main.async {
            self.score = nil
            //AudioSamplerPlayer.shared.stopSampler()
        }
    }

    func noteCountSpeechWord(currentTimeValue:Double) -> String {
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
    
    private func startPlayThreadRunning(timeSignature:TimeSignature) {
        self.isThreadRunning = true
        AudioManager.shared.setSession(.playback)
        ///This is required but dont know why. Without it the audio sampler does not sound notes after the app records an audio.
        AudioSamplerPlayer.reset()
        let midiSampler = AudioSamplerPlayer.getShared().getSampler()
        let audioTickerMetronomeTick:MetronomeTickerPlayer = MetronomeTickerPlayer(timeSignature: timeSignature, tickStyle: true)
        let audioClapper:MetronomeTickerPlayer = MetronomeTickerPlayer(timeSignature: timeSignature, tickStyle: false)

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var loopCtr = 0
            var keepRunning = true
            var currentTimeValue = 0.0
            //var noteValueSpeechWord:String? = nil
            var ticksPlayed = 0
            var firstNote = true
            var tieWasFound = false
            //let sleepTime1 = (60.0 / Double(self.tempo)) * shortestNoteValue

            while keepRunning {
                ///Sound the metronome tick. %4 because its counting at semiquaver intervals
                ///Make sure score playing is synched to the metronome tick
                if loopCtr % 4 == 0 {
                    if self.tickingIsActive {
                        audioTickerMetronomeTick.soundTick(silent: false)
                        ticksPlayed += 1
                    }
                }
                
                ///Sound the next note
                if (firstNote && loopCtr % 2 == 0) || (!firstNote) {
                    if let score = score {
                        firstNote = false
                        if let timeSlice = nextScoreTimeSlice {
                            if timeSlice.entries.count > 0 {
                                let entry = timeSlice.entries[0]
                                if currentNoteTimeToLive >= entry.getValue() {
                                    if entry is Rest {
                                        audioClapper.soundTick(noteValue: entry.getValue(), silent: true)
                                    }
                                    else {
                                        for note in timeSlice.getTimeSliceNotes() {
                                            if tieWasFound {
                                                tieWasFound = false
                                            }
                                            else {
                                                if note.isOnlyRhythmNote  {
                                                    audioClapper.soundTick(noteValue: note.getValue(), silent: false)
                                                }
                                                else {
                                                    midiSampler.startNote(UInt8(note.midiNumber), withVelocity:64, onChannel:UInt8(0))
                                                }
                                                note.setHilite(hilite: true)
                                                DispatchQueue.global(qos: .background).async {
                                                    Thread.sleep(forTimeInterval: 0.5)
                                                    note.setHilite(hilite: false)
                                                }
                                            }
//                                            if noteInChordNum == 0 && note.getValue() < 1.0 {
//                                                noteValueSpeechWord = "and"
//                                            }
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
                                        nextScoreTimeSlice = entry as! TimeSlice
                                        if nextScoreTimeSlice!.entries.count > 0 {
                                            nextScoreIndex += 1
                                            //currentNoteTimeToLive = nextScoreTimeSlice!.getNotes()[0].getValue()
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
                    let sleepTime = (60.0 / Double(self.tempo)) * shortestNoteValue
                    Thread.sleep(forTimeInterval: sleepTime)
                    loopCtr += 1
                }
            }
            self.isThreadRunning = false
        }
    }
}


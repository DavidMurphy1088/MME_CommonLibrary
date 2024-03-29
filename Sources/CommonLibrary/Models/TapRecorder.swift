import SwiftUI
import CoreData
import AVFoundation
import SwiftUI
import AVFoundation

public class TapRecorder : NSObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate, ObservableObject {
    public static let shared = TapRecorder()
    
    @Published public var status:String = ""
    @Published public var enableRecordingLight = false
    
    var tapTimes:[Double] = []
    var tappedValues:[Double] = []

    var metronome = Metronome.getMetronomeWithCurrentSettings(ctx: "Tap Recorder init")
    var metronomeTempoAtRecordingStart:Int? = nil
    //let tapSoundPlayer = TapSoundPlayer()
    
    public func setStatus(_ msg:String) {
        DispatchQueue.main.async {
            self.status = msg
        }
    }
    
    public func startRecording(metronomeLeadIn:Bool, metronomeTempoAtRecordingStart:Int)  {
        self.tappedValues = []
        self.tapTimes = []
        if metronomeLeadIn {
            self.enableRecordingLight = false
        }
        else {
            self.enableRecordingLight = true
        }
        self.metronomeTempoAtRecordingStart = metronomeTempoAtRecordingStart
        AudioManager.shared.checkReadyToPlay("TapRecorder.startRecording")
        AudioManager.shared.scheduleTapPlayers(ctx: "TapRecorder.startRecording")
    }
    
    public func endMetronomePrefix() {
        DispatchQueue.main.async {
            self.enableRecordingLight = true
        }
    }
    
    public func makeTap(useSoundPlayer:Bool)  {
        //dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let date = Date()
        self.tapTimes.append(date.timeIntervalSince1970)
        if useSoundPlayer {
            AudioManager.shared.playSound()
            //tapSoundPlayer.playSound()
        }
        else {
            let sound = SystemSoundID(1104)
            AudioServicesPlaySystemSound(sound)
        }
    }

    public func stopRecording(score:Score) -> ([Double]) {
        //tapSoundPlayer.stopAudio(ctx:"TapRecorder.stopRecording")
        //AudioManager.shared.stopAudio(ctx: "TapRecorder.stopRecording")
        self.tapTimes.append(Date().timeIntervalSince1970) // record value of last tap made
        self.tappedValues = []
        var last:Double? = nil
        for t in tapTimes {
            var diff = 0.0
            if last != nil {
                diff = (t - last!)
            }
            if last != nil {
                self.tappedValues.append(diff)
            }
            last = t
        }
        return self.tappedValues
    }
    
    //Return the standard note value for a millisecond duration given the tempo input
    //Handle dooted crotchets
    public func roundNoteValueToStandardValue(inValue:Double, tempo:Int) -> Double? {
        let inValueAtTempo = (inValue * Double(tempo)) / 60.0
        if inValueAtTempo < 0.25 {
            return 0.25
        }
        if inValueAtTempo < 0.75 {
            return 0.5
        }
        if inValueAtTempo < 1.25 {
            return 1.0
        }
        if inValueAtTempo < 1.75 {
            return 1.5
        }
        if inValueAtTempo < 2.5 {
            return 2.0
        }
        if inValueAtTempo < 3.5 {
            return 3.0
        }
        if inValueAtTempo < 4.5 {
            return 4.0
        }
        if inValueAtTempo < 5.5 {
            return 5.0
        }
        if inValueAtTempo < 6.5 {
            return 6.0
        }
        return Double(Int(inValueAtTempo))
    }

    ///Make a playable score of notes from the tap intervals
    public func makeScoreFromTaps(questionScore:Score, tappedTempo:Int, tapValues: [Double]) -> Score {
        let outputScore = Score(key: questionScore.key, timeSignature: questionScore.timeSignature, linesPerStaff: 1)
        let staff = Staff(score: outputScore, type: .treble, staffNum: 0, linesInStaff: 1)
        outputScore.createStaff(num: 0, staff: staff)
        
        ///If the last tapped note has duration > question last note value set that value to the last question note value + any trailing rests
        ///(Because we are not measuring how long it took the student to hit stop recording)
        let lastQuestionTimeslice = questionScore.getLastNoteTimeSlice()
        var lastValue:Double?
        if let ts = lastQuestionTimeslice {
            if ts.getTimeSliceNotes().count > 0 {
                lastValue = ts.getTimeSliceNotes()[0].getValue()
                let trailingRestsDuration = questionScore.getTrailingRestsDuration(index: ts.sequence + 1)
                lastValue! += trailingRestsDuration
            }
        }

        for i in 0..<tapValues.count {
            let tapDuration = tapValues[i]
            var recordedTapDuration = tapDuration * Double(tappedTempo) / 60.0
            let roundedTappedValue = roundNoteValueToStandardValue(inValue: tapDuration, tempo: tappedTempo)
            if var tappedValue = roundedTappedValue {
                if i == tapValues.count - 1 {
                    ///The last tap value is when the student ended the recording and they may have delayed the stop recording
                    ///So instead of using the tapped value, let the last note value be the last question note (+any trailing rests) value so the rhythm is not marked wrong
                    ///But only allow an extra delay of 2.0 beats. i.e. they can't delay hitting stop for too long
                    ///Also if student ends too quickly that neeeds to be reported as a rhythm error so only modify the tapped value if they are too long
                    if let lastValue = lastValue {
                        ///let the delay till the end of tapping be a percentage of the last note value
                        //let endTappingTolerance = 1.50
                        //let maxEndTapValue = max(lastQuestionNote!.getValue() * (endTappingTolerance), 2.0)
                        let maxEndTapValue = lastValue + 2.0
                        if tappedValue > lastValue && tappedValue <= maxEndTapValue {
                            //the student delayed the end of recording
                            tappedValue = lastValue
                            recordedTapDuration = tappedValue
                        }
                    }
                }
                let timeSlice = outputScore.createTimeSlice()
                let note = Note(timeSlice:timeSlice, num: 0, value: tappedValue, staffNum: 0)
                note.setIsOnlyRhythm(way: true)
                timeSlice.tapSecondsNormalizedToTempo = recordedTapDuration
                timeSlice.addNote(n: note)
            }
        }
        return outputScore
    }
        
    //From the recording of the first tick, calculate the tempo the rhythm was tapped at
    public func getTempoFromRecordingStart(tapValues:[Double], questionScore: Score) -> Int {
        let scoreTimeSlices = questionScore.getAllTimeSlices()
        if scoreTimeSlices.count == 0 {
            return 60
        }
        var firstScoreValue:Double
        if scoreTimeSlices[0].getTimeSliceNotes().count == 0 {
            ///first entry is a rest
            firstScoreValue = scoreTimeSlices[0].getTimeSliceEntries()[0].getValue()
        }
        else {
            firstScoreValue = scoreTimeSlices[0].getTimeSliceNotes()[0].getValue()
        }
        
        for i in 1..<scoreTimeSlices.count {
            let entries = scoreTimeSlices[i].getTimeSliceEntries()
            if entries.count > 0 {
                let entry = entries[0]
                if entry is Note {
                    break
                }
                else {
                    if entry is Rest {
                        firstScoreValue += entry.getValue()
                    }
                }
            }
        }
        //if self.tappedValues.count == 0 
        if tapValues.count == 0 {
            return 60
        }
        let firstTapValue = tapValues[0]
        let tempo = (firstScoreValue / firstTapValue) * 60.0
        return Int(tempo)
    }
    
    //From the recording calculate the average tempo of all taps
    public func getTempoFromRecordingAverage(tapValues:[Double], questionScore: Score) -> Int {
        let scoreTimeSlices = questionScore.getAllTimeSlices()
        if scoreTimeSlices.count == 0 {
            return 60
        }
        
        var currentScoreValue = 0.0
        var lastTapDuration:Double? = nil
        var tapIndex = 0
        var tempos:[Double] = []
        
        for i in 0..<scoreTimeSlices.count {
            let entries = scoreTimeSlices[i].getTimeSliceEntries()
            if entries.count > 0 {
                let entry = entries[0]
                if entry is Note {
                    if let tapDuration = lastTapDuration {
                        if tapDuration > 0 {
                            let tempo = (currentScoreValue / tapDuration) * 60.0
                            tempos.append(tempo)
                            let sum = tempos.reduce(0, +)
                            let average = sum / Double(tempos.count)
                            print("========= AVG TEMP === Tempos", tempos, "AVG:------>", average)

                            //if tempos.count > 4 {
                            if tempos.count > 3 {
                                break
                            }
                            currentScoreValue = 0
                        }
                    }
                    if tapIndex < tapValues.count {
                        lastTapDuration = tapValues[tapIndex]
                        tapIndex += 1
                        currentScoreValue += entry.getValue()
                    }
                }
                else {
                    if entry is Rest {
                        currentScoreValue += entry.getValue()
                    }
                }
            }
        }
        //if self.tappedValues.count == 0
        if tempos.count == 0 {
            return 60
        }
        let sum = tempos.reduce(0, +)
        let average = sum / Double(tempos.count)
        print("   ========= AVG Tempos", tempos, "AVG:------>", average)
        return Int(average)
    }
    
    //return the tempo of the students recording
    public func getRecordedTempo(questionScore:Score) -> Int {
        //let tempo = getTempoFromRecordingStart(tapValues: self.tappedValues, questionScore: questionScore)
        let tempo = getTempoFromRecordingAverage(tapValues: self.tappedValues, questionScore: questionScore)
        return tempo
    }
    
    //Read the user's tapped rhythm and return a score representing the ticks they ticked
    public func getTappedAsAScore(timeSignatue:TimeSignature, questionScore:Score, tapValues:[Double]) -> Score {
        //let recordedTempo = getTempoFromRecordingStart(tapValues: tapValues, questionScore: questionScore)
        let recordedTempo = getTempoFromRecordingAverage(tapValues: tapValues, questionScore: questionScore)
        let tappedScore = self.makeScoreFromTaps(questionScore: questionScore, tappedTempo: recordedTempo, tapValues: tapValues) //, tapValues: self.tapValues1)
        tappedScore.tempo = recordedTempo
        return tappedScore
    }
}


import Foundation

public enum AnswerState {
    case notEverAnswered
    case notRecorded
    case recorded
    case recording
    case tryingKeyboard
    case answered
    case submittedAnswer
}

///The answer a student gives to a question
public class Answer : ObservableObject, Identifiable, Codable {
    public var id:UUID
    public var correct: Bool = false
    public var explanation = ""

    ///Intervals
    public var correctIntervalHalfSteps = 0
    public var correctIntervalName = ""
    public var selectedIntervalName = ""
    
    ///Rhythm
    public var rhythmValues:[Double]?
    public var rhythmToleranceSetting:Int?
    
    ///Recording
    public var recordedData: Data?
    
    ///Sight reading
    public var sightReadingNotePitches:[Int] = []
    public var sightReadingNoteTimes:[Date] = []

    public init() {
        id = UUID()
        //self.questionMode = questionMode
    }
    
    public func copyAnwser() -> Answer {
        let a = Answer() //, questionMode: self.questionMode)
        a.correct = self.correct
        a.correctIntervalName = self.correctIntervalName
        a.correctIntervalHalfSteps = self.correctIntervalHalfSteps
        a.selectedIntervalName = self.selectedIntervalName
        a.explanation = self.explanation
        a.rhythmValues = self.rhythmValues
        a.rhythmToleranceSetting = self.rhythmToleranceSetting
        a.recordedData = self.recordedData
        a.sightReadingNotePitches = self.sightReadingNotePitches
        a.sightReadingNoteTimes = self.sightReadingNoteTimes
        return a
    }
    
    ///Convert note timestamps from the piano to note durations
    public func makeNoteValues() {
        self.rhythmValues = []
        var lastTime:Date = Date()
        for i in 0..<sightReadingNoteTimes.count {
            let noteTime = sightReadingNoteTimes[i]
            if i == 0 {
                lastTime = noteTime
                continue
            }
            self.rhythmValues!.append(noteTime.timeIntervalSince(lastTime))
            lastTime = noteTime
        }
    }
}


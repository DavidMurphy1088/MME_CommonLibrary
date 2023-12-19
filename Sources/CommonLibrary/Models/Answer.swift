import Foundation

public enum AnswerState {
    case notEverAnswered
    case notRecorded
    case recorded
    case recording
    case answered
    case submittedAnswer
}

//public class SightReadingNote { //Codable {
//    var midi: Int
//    var date: Date
//    init(midi:Int, date:Date) {
//        self.midi = midi
//        self.date = date
//    }
//}


///The answer a student gives to a question
public class Answer : ObservableObject, Identifiable, Codable {
    public var id:UUID
    //var questionMode: QuestionMode
    public var correct: Bool = false
    public var explanation = ""

    ///Intervals
    public var correctIntervalHalfSteps = 0
    public var correctIntervalName = ""
    public var selectedIntervalName = ""
    
    ///Rhythm
    //var tempo:Int?
    public var values:[Double]?
    
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
        a.values = self.values
        a.recordedData = self.recordedData
        a.sightReadingNotePitches = self.sightReadingNotePitches
        a.sightReadingNoteTimes = self.sightReadingNoteTimes
        return a
    }
}


import Foundation

public enum AnswerState {
    case notEverAnswered
    case notRecorded
    case recorded
    case recording
    case answered
    case submittedAnswer
}

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
    
    public init() { //}, questionMode:QuestionMode) {
        id = UUID()
        //self.questionMode = questionMode
    }
    
    public func copyAnwser() -> Answer {
        let a = Answer() //, questionMode: self.questionMode)
        a.correct = self.correct
        //a.selectedInterval = self.selectedInterval
        //a.correctInterval = self.correctInterval
        a.correctIntervalName = self.correctIntervalName
        a.correctIntervalHalfSteps = self.correctIntervalHalfSteps
        a.selectedIntervalName = self.selectedIntervalName
        a.explanation = self.explanation
        a.values = self.values
        a.recordedData = self.recordedData
        return a
    }
}


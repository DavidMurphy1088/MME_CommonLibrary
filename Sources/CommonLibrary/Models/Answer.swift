import Foundation

enum AnswerState {
    case notEverAnswered
    case notRecorded
    case recorded
    case recording
    case answered
    case submittedAnswer
}

///The answer a student gives to a question
class Answer : ObservableObject, Codable,Identifiable {
    var id:UUID
    //var questionMode: QuestionMode
    var correct: Bool = false
    var explanation = ""

    ///Intervals
    var correctIntervalHalfSteps = 0
    var correctIntervalName = ""
    var selectedIntervalName = ""
    
    ///Rhythm
    //var tempo:Int?
    var values:[Double]?
    
    ///Recording
    var recordedData: Data?
    
    init(ctx:String) { //}, questionMode:QuestionMode) {
        id = UUID()
        //self.questionMode = questionMode
    }
    
    func copyAnwser() -> Answer {
        let a = Answer(ctx: "copy") //, questionMode: self.questionMode)
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


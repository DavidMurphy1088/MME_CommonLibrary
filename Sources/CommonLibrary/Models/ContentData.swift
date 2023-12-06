import Foundation

public enum QuestionType {
    //intervals
    case intervalVisual
    case intervalAural
    
    //rhythms
    case rhythmVisualClap
    case melodyPlay
    case rhythmEchoClap
    
    case none
}

public enum AgeGroup: Int, CaseIterable, Identifiable {
    case Group_5To10 = 0
    case Group_11Plus = 1

    public var id: Self { self }
    
    public var displayName: String {
        switch self {
        case .Group_5To10:
            return "5 to 10"
        case .Group_11Plus:
            return "11 Plus"
        }
    }
}

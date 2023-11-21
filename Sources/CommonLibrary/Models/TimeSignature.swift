import Foundation

public class TimeSignature {
    public var top = 1
    public var bottom = 4
    public var isCommonTime = false
    
    public init(top:Int, bottom: Int) {
        self.top = top
        self.bottom = bottom
    }
}

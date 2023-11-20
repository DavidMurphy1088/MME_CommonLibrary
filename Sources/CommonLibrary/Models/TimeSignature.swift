import Foundation

class TimeSignature {
    var top = 1
    var bottom = 4
    var isCommonTime = false
    
    init(top:Int, bottom: Int) {
        self.top = top
        self.bottom = bottom
    }
}

//import SwiftUI
//import CoreData
//
//class PKey : ObservableObject {
//    var pitch: Int
//    @Published var pressed: Bool = false
//    init(n:Int) {
//        pitch = n
//    }
//}
//
//class WhiteKeys: ObservableObject {
//    var whiteKeyCount = 7
//    var keys:[PKey] = []
//    @Published var changed: Bool = false
//    init() {
//        for i in 0..<whiteKeyCount {
//            keys.append(PKey(n: Note.MIDDLE_C + i*2))
//            if i==3 {
//                keys[2].pressed = true
//            }
//        }
//    }
//}
//

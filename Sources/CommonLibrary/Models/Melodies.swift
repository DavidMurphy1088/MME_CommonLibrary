
import Foundation

class Melody : Identifiable {
    let id = UUID()
    let halfSteps:Int
    let name:String
    var timeSlices:[TimeSlice]
    var data:[String]

    init (halfSteps:Int, name:String) {
        self.name = name
        self.halfSteps = halfSteps
        self.timeSlices = []
        self.data = []
    }
    
//    func transpose(base:Note) -> [Note] {
//        var result:[Note] = []
//        let firstPitch = notes[0].midiNumber
//        let delta = firstPitch - base.midiNumber
//        for n in notes {
//            result.append(Note(timeSlice: nil, num: n.midiNumber - delta, value: n.getValue(), staffNum: 0))
//        }
//        return result
//    }
}

class Melodies {
    static public let shared = Melodies()
    var melodies:[Melody] = []
    
    func addMelody(melody:Melody) {
        self.melodies.append(melody)
    }
    
    ///Return a list of melodies for the given interval
    func getMelodies(halfSteps:Int) -> [Melody] {
        var melodies : [Melody] = []
        for melody in self.melodies {
            if melody.halfSteps == halfSteps {
                melodies.append(melody)
            }
        }
        return melodies
    }
    
}

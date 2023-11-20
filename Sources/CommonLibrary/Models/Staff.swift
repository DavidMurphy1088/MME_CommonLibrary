import Foundation
import AVKit
import AVFoundation

//https://mammothmemory.net/music/sheet-music/reading-music/treble-clef-and-bass-clef.html

///Used to record view positions of notes as they are drawn by a view so that a 2nd drwing pass can draw quaver beams to the right points
class NoteLayoutPositions: ObservableObject {
    @Published var positions:[Note: CGRect] = [:]

    var id:Int
    static var nextId = 0
    
    init(id:Int) {
        self.id = id
    }
    
    static func getShared() -> NoteLayoutPositions {
        let lp = NoteLayoutPositions(id: nextId)
        nextId += 1
        return lp
    }
    
    func storePosition(notes: [Note], rect: CGRect) {
        if notes.count > 0 {
            if notes[0].beamType != .none {
                let rectCopy = CGRect(origin: CGPoint(x: rect.minX, y: rect.minY), size: CGSize(width: rect.size.width, height: rect.size.height))
                DispatchQueue.main.async {
                    sleep(UInt32(0.25))
                    self.positions[notes[0]] = rectCopy
                }
            }
        }
    }
}

class BarLayoutPositions: ObservableObject {
    @Published var positions:[BarLine: CGRect] = [:]
    func storePosition(barLine:BarLine, rect: CGRect, ctx:String) {
        DispatchQueue.main.async {
            let rectCopy = rect //CGRect(origin: CGPoint(x: rect.minX, y: rect.minY), size: CGSize(width: rect.size.width, height: rect.size.height))
            self.positions[barLine] = rectCopy
        }
    }
}

enum StaffType {
    case treble
    case bass
}

class StaffPlacementsByKey {
    var staffPlacement:[NoteStaffPlacement] = []
}

class NoteOffsetsInStaffByKey {
    var noteOffsetByKey:[String] = []
    init () {
        //Defines which staff line (and accidental) is used to show a midi pitch in each key,
        //assuming key signature is not taken in account (it will be later in the note display code...)
        //offset, sign. sign = ' ' or -1=flat, 1=sharp (=natural,????)
        //modified July23 - use -1 for flat, 0 for natural, 1 for sharp. Done onlu so far for C and G
        //horizontal is the various keys
        //vertical starts at showing how C is shown in that key, then c#, d, d# etc up the scale
        //31Aug2023 - done for C, G, D, E
        //  Key                 C     D♭   D    E♭   E    F    G♭    G     A♭   A    B♭   B
        noteOffsetByKey.append("0     0    0    0    0    0    0,1   0     0    0,1  0    0")    //C
        noteOffsetByKey.append("0,1   1    0,1  1,0  0,1  1,0  1     0,1   1    0    1,0  0,1")  //C#, D♭
        noteOffsetByKey.append("1     1,1  1    1    1    1    1,1   1     1,1  1    1    1")    //D
        noteOffsetByKey.append("2,-1  2    2,-1 2    1,1  2,0  2     2,-1  2    1,2  2    1,1")  //D#, E♭
        noteOffsetByKey.append("2     2,1  2    2,1  2    2    2,1   2     2,1  2    2,1  2")    //E
        noteOffsetByKey.append("3     3    3    3    3    3    3     3     3    3,1  3    3")    //F
        noteOffsetByKey.append("3,1   4    3,1  4,0  3,1  4,0  4     3,1   4,0  3    4,0  3,1")  //F#, G♭
        noteOffsetByKey.append("4     4,1  4    4    4    4    4,1   4     4    4,1  4    4")    //G
        noteOffsetByKey.append("4,1   5    4,1  5    4,1  5,0  5     4,1   5    4    5,0  4,1")  //G#, A♭
        noteOffsetByKey.append("5     5,1  5    5,1  5    5    5,1   5     5,1  5    5    5")    //A
        noteOffsetByKey.append("6,-1  6    6,-1 6    6,-1 6    6     6,-1  6    6,0  6    5,1")  //A#, B♭
        noteOffsetByKey.append("6     6,1  6    6,1  6    6,1  6,1   6     6,1  6    6,1  6")    //B
    }
    
    func getValue(scaleDegree:Int, keyNum:Int) -> NoteStaffPlacement? {
        guard scaleDegree < self.noteOffsetByKey.count else {
            Logger.logger.reportError(self, "Invalid degree \(scaleDegree)")
            return nil
        }
        guard keyNum < 12 else {
            Logger.logger.reportError(self, "Invalid key \(scaleDegree)")
            return nil
        }
        
        let scaleDegreeComponentsLine = noteOffsetByKey[scaleDegree].components(separatedBy: " ")
        var scaleDegreeComponentsList:[String] = []
        for component in scaleDegreeComponentsLine {
            let c = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if c.count > 0 {
                scaleDegreeComponentsList.append(c)
            }
        }
        let scaleDegreeComponents = scaleDegreeComponentsList[keyNum]
        let offsetAndAccidental = scaleDegreeComponents.components(separatedBy: ",")
        let offset:Int? = Int(offsetAndAccidental[0])
        if let offset = offset {
            var accidental:Int? = nil
            if offsetAndAccidental.count > 1 {
                let accStr = offsetAndAccidental[1]
                accidental = Int(accStr)
            }
            let placement = NoteStaffPlacement(offsetFroMidLine: offset, accidental: accidental)
            return placement
        }
        else {
            Logger.logger.reportError(self, "Invalid data at row:\(scaleDegree), col:\(keyNum)")
            return nil
        }
    }
}

class Staff : ObservableObject, Identifiable {
    let id = UUID()
    @Published var publishUpdate = 0
    @Published var noteLayoutPositions:NoteLayoutPositions
    @Published var isHidden:Bool = false

    let score:Score
    var type:StaffType
    var staffNum:Int
    var lowestNoteValue:Int
    var highestNoteValue:Int
    var middleNoteValue:Int
    var staffOffsets:[Int] = []
    var noteStaffPlacement:[NoteStaffPlacement]=[]
    var linesInStaff:Int
    let noteOffsetsInStaffByKey = NoteOffsetsInStaffByKey()
    
    init(score:Score, type:StaffType, staffNum:Int, linesInStaff:Int) {
        self.score = score
        self.type = type
        self.staffNum = staffNum
        self.linesInStaff = linesInStaff
        lowestNoteValue = 20 //MIDI C0
        highestNoteValue = 107 //MIDI B7
        middleNoteValue = type == StaffType.treble ? 71 : Note.MIDDLE_C - Note.OCTAVE + 2
        noteLayoutPositions = NoteLayoutPositions(id: 0)

        //Determine the staff placement for each note pitch
        
        var keyNumber:Int = 0
        if score.key.keySig.accidentalCount == 1 {
            keyNumber = 7
        }
        if score.key.keySig.accidentalCount == 2 {
            keyNumber = 2
        }
        if score.key.keySig.accidentalCount == 3 {
            keyNumber = 9
        }
        if score.key.keySig.accidentalCount == 4 {
            keyNumber = 4
        }
        if score.key.keySig.accidentalCount == 5 {
            keyNumber = 11
        }
        
        for noteValue in 0...highestNoteValue {
            //Fix - longer? - offset should be from middle C, notes should be displayed on both staffs from a single traversal of the score's timeslices
            
            let placement = NoteStaffPlacement(offsetFroMidLine: 0)
            noteStaffPlacement.append(placement)
            if noteValue < middleNoteValue - 6 * Note.OCTAVE || noteValue >= middleNoteValue + 6 * Note.OCTAVE {
                continue
            }

            //            if noteValue == 73 || noteValue == 72 {
            //                var debug = 72
            //            }
            var offsetFromTonic = (noteValue - Note.MIDDLE_C) % Note.OCTAVE
            if offsetFromTonic < 0 {
                offsetFromTonic = 12 + offsetFromTonic
            }

            guard let noteOffset = noteOffsetsInStaffByKey.getValue(scaleDegree: offsetFromTonic, keyNum: keyNumber) else {
                Logger.logger.reportError(self, "No note offset data for note \(noteValue)")
                break
            }
            var offsetFromMidLine = noteOffset.offsetFromStaffMidline


            var octave:Int
            let referenceNote = type == .treble ? Note.MIDDLE_C : Note.MIDDLE_C - 2 * Note.OCTAVE
            if noteValue >= referenceNote {
                octave = (noteValue - referenceNote) / Note.OCTAVE
            }
            else {
                octave = (referenceNote - noteValue) / Note.OCTAVE
                octave -= 1
            }
            offsetFromMidLine += (octave - 1) * 7 //8 offsets to next octave
            offsetFromMidLine += type == .treble ? 1 : -1
            placement.offsetFromStaffMidline = offsetFromMidLine
            
            placement.accidental = noteOffset.accidental
            noteStaffPlacement[noteValue] = placement
        }
    }
//    
//    func keyDescription() -> String {
//        return self.score.key.description()
//    }
    
    func update() {
        DispatchQueue.main.async {
            self.publishUpdate += 1
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.publishUpdate = 0
        }
    }
    
    func keyColumn() -> Int {
        //    Key   C    D♭   D    E♭   E    F    G♭   G    A♭   A    B♭   B
        //m.append("0    0    0,0  0    0,0  0    0    0    0    0,0  0    0,0")  //C

        if score.key.keySig.accidentalType == AccidentalType.sharp {
            switch score.key.keySig.accidentalCount {
            case 0:
                return 0
            case 1:
                return 7
            case 2:
                return 2
            case 3:
                return 9
            case 4:
                return 4
            case 5:
                return 11
            case 6:
                return 6
            case 7:
                return 1
            default:
                return 0
            }
        }
        else {
            switch score.key.keySig.accidentalCount {
            case 0:
                return 0
            case 1:
                return 5
            case 2:
                return 10
            case 3:
                return 3
            case 4:
                return 8
            case 5:
                return 1
            case 6:
                return 6
            case 7:
                return 11
            default:
                return 0
            }
        }
     }
    
    //Tell a note how to display itself
    //Note offset from middle of staff is dependendent on the staff
//    func getNoteViewPlacement(note:Note) -> NoteStaffPlacement {
//
//        let defaultPlacement = noteStaffPlacement[note.midiNumber]
//        let placement = NoteStaffPlacement(midi: defaultPlacement.midi,
//                                           offsetFroMidLine: defaultPlacement.offsetFromStaffMidline,
//                                           accidental: defaultPlacement.accidental
//        )
//        return placement
//    }
    
    //Tell a note how to display itself
    //Note offset from middle of staff is dependendent on the staff
    func getNoteViewPlacement(note:Note) -> NoteStaffPlacement {
        let defaultPlacement = noteStaffPlacement[note.midiNumber]
        let placement = NoteStaffPlacement(offsetFroMidLine: defaultPlacement.offsetFromStaffMidline,
                                           accidental: defaultPlacement.accidental
        )
        return placement
    }
    
}
 

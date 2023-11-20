import Foundation
import SwiftUI

class TimeSliceEntry : ObservableObject, Identifiable, Equatable, Hashable {
    @Published var hilite = false

    let id = UUID()
    var staffNum:Int //Narrow the display of the note to just one staff
    var timeSlice:TimeSlice
    var sequence:Int = 0 //the timeslice's sequence position

    private var value:Double = Note.VALUE_QUARTER

    init(timeSlice:TimeSlice, value:Double, staffNum: Int = 0) {
        self.value = value
        self.staffNum = staffNum
        self.timeSlice = timeSlice
    }
    
    static func == (lhs: TimeSliceEntry, rhs: TimeSliceEntry) -> Bool {
        return lhs.id == rhs.id
    }
    
    func isDotted() -> Bool {
        return [0.75, 1.5, 3.0].contains(value)
    }
    
//    func log(ctx:String) -> Bool {
//        print("====>TimeSliceEntry", ctx, "ID", id, sequence, "hilit", self.hilite)
//        return true
//    }
    
    func getValue() -> Double {
        return self.value
    }
    
    //Cause notes that are set for specifc staff to be transparent on other staffs
    func getColor(staff:Staff, log:Bool? = false) -> Color {
        var out:Color? = nil
//        guard let timeSlice = timeSlice else {
//            return Color.black
//        }
        if timeSlice.statusTag == .inError {
            out = Color(.red)
        }
        if timeSlice.statusTag == .afterError {
            out = Color(.lightGray)
        }

        if timeSlice.statusTag == .hilightAsCorrect {
            out = Color(red: 0.0, green: 0.6, blue: 0.0)
        }
        if out == nil {
            out = Color(staffNum == staff.staffNum ? .black : .clear)
            //out = Color(.black)

        }

        return out!
    }

    func setValue(value:Double) {
        self.value = value
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func getNoteValueName() -> String {
        var name = self.isDotted() ? "dotted " : ""
        switch self.value {
        case 0.25 :
            name += "semi quaver"
        case 0.50 :
            name += "quaver"
        case 1.0 :
            name += "crotchet"
        case 1.5 :
            name += "dotted crotchet"
        case 2.0 :
            name += "minim"
        case 3.0 :
            name += "minim"
        default :
            name += "semibreve"
        }
        return name
    }
    
    static func getValueName(value:Double) -> String {
        var name = ""
        switch value {
        case 0.25 :
            name += "semi quaver"
        case 0.50 :
            name += "quaver"
        case 1.0 :
            name += "crotchet"
        case 1.5 :
            name += "dotted crotchet"
        case 2.0 :
            name += "minim"
        case 3.0 :
            name += "dotted minim"
        case 4.0 :
            name += "semibreve"
        default :
            name += "unknown value \(value)"
        }
        return name
    }
}

class BarLine : ScoreEntry {
}

class Tie : ScoreEntry {
}

class Rest : TimeSliceEntry {    
    override init(timeSlice:TimeSlice, value:Double, staffNum:Int) {
        super.init(timeSlice:timeSlice, value: value, staffNum: staffNum)
    }
    
    init(r:Rest) {
        super.init(timeSlice: r.timeSlice, value: r.getValue(), staffNum: r.staffNum)
    }
}

enum AccidentalType {
    case sharp
    case flat
}

enum HandType {
    case left
    case right
}

enum QuaverBeamType {
    case none
    case start
    case middle
    case end
}

enum StemDirection {
    case up
    case down
}

enum StatusTag {
    case noTag
    case inError
    case afterError //e.g. all rhythm after a rhythm error is moot
    case hilightAsCorrect //hilight the correct note that was expected
}

class NoteStaffPlacement {
    var offsetFromStaffMidline:Int
    var accidental: Int?
    
    init(offsetFroMidLine:Int, accidental:Int?=nil) {
        self.offsetFromStaffMidline = offsetFroMidLine
        self.accidental = accidental
    }
}

class Note : TimeSliceEntry, Comparable {    
    static let MIDDLE_C = 60 //Midi pitch for C4
    static let OCTAVE = 12
    
    static let VALUE_SEMIQUAVER = 0.25
    static let VALUE_QUAVER = 0.5
    static let VALUE_QUARTER = 1.0
    static let VALUE_HALF = 2.0
    static let VALUE_WHOLE = 4.0

    var midiNumber:Int
    var isOnlyRhythmNote = false
    var accidental:Int? = nil ///< 0 = flat, ==0 natural, > 0 sharp
    var rotated:Bool = false ///true if note must be displayed vertically rotated due to closeness to a neighbor.
    
    ///Placements for the note on treble and bass staff
    var noteStaffPlacements:[NoteStaffPlacement?] = [nil, nil]
    
    ///Quavers in a beam have either a start, middle or end beam type. A standlone quaver type has type beamEnd. A non quaver has beam type none.
    var beamType:QuaverBeamType = .none
    
    var stemDirection:StemDirection = .up
    var stemLength:Double = 0.0
    
    //the note where the quaver beam for this note ends
    var beamEndNote:Note? = nil
    
    static func < (lhs: Note, rhs: Note) -> Bool {
        return lhs.midiNumber < rhs.midiNumber
    }
    
    static func isSameNote(note1:Int, note2:Int) -> Bool {
        return (note1 % 12) == (note2 % 12)
    }
    
    init(timeSlice:TimeSlice, num:Int, value:Double = Note.VALUE_QUARTER, staffNum:Int, accidental:Int?=nil) {
        self.midiNumber = num
        super.init(timeSlice:timeSlice, value: value, staffNum: staffNum)
        self.accidental = accidental
    }
    
    init(note:Note) {
        self.midiNumber = note.midiNumber
        super.init(timeSlice:note.timeSlice, value: note.getValue(), staffNum: note.staffNum)
        self.accidental = note.accidental
        self.isOnlyRhythmNote = note.isOnlyRhythmNote
    }
    
    func setHilite(hilite: Bool) {
        DispatchQueue.main.async {
            self.hilite = hilite
        }
    }
        
    func setIsOnlyRhythm(way: Bool) {
        self.isOnlyRhythmNote = way
        if self.isOnlyRhythmNote {
            self.midiNumber = Note.MIDDLE_C + Note.OCTAVE - 1
        }
        
    }
    
    static func getNoteName(midiNum:Int) -> String {
        var name = ""
        let note = midiNum % 12 //self.midiNumber % 12
        switch note {
        case 0:
            name = "C"
        case 1:
            name = "C#"
        case 2:
            name = "D"
        case 3:
            name = "D#"
        case 4:
            name = "E"
        case 5:
            name = "F"
        case 6:
            name = "F#"
        case 7:
            name = "G"
        case 8:
            name = "G#"
        case 9:
            name = "A"
        case 10:
            name = "A#"
        case 11:
            name = "B"

        default:
            name = "\(note)"
        }
        return name
    }
    
    static func getAllOctaves(note:Int) -> [Int] {
        var notes:[Int] = []
        for n in 0...88 {
            if note >= n {
                if (note - n) % 12 == 0 {
                    notes.append(n)
                }
            }
            else {
                if (n - note) % 12 == 0 {
                    notes.append(n)
                }
            }
        }
        return notes
    }
    
    static func getClosestOctave(note:Int, toPitch:Int, onlyHigher: Bool = false) -> Int {
        let pitches = Note.getAllOctaves(note: note)
        var closest:Int = note
        var minDist:Int?
        for p in pitches {
            if onlyHigher {
                if p < toPitch {
                    continue
                }
            }
            let dist = abs(p - toPitch)
            if minDist == nil || dist < minDist! {
                minDist = dist
                closest = p
            }
        }
        return closest
    }
    
    ///Find the first note for this quaver group
    func getBeamStartNote(score:Score, np: NoteLayoutPositions) -> Note {
        let endNote = self
        if endNote.beamType != .end {
            return endNote
        }
        var result:Note? = nil
        var idx = score.scoreEntries.count - 1
        var foundEndNote = false
        while idx>=0 {
            let ts = score.scoreEntries[idx]
            if ts is TimeSlice {
                let notes = ts.getTimeSliceNotes()
                if notes.count > 0 {
                    let note = notes[0]
                    if note.sequence == endNote.sequence {
                        foundEndNote = true
                    }
                    else {
                        if foundEndNote {
                            if note.beamType == .start {
                                result = note
                                break
                            }
                            else {
                                if note.getValue() == Note.VALUE_QUAVER {
                                    if note.beamType == .end {
                                        break
                                    }
                                }
                                else {
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if ts is BarLine {
                if foundEndNote {
                    break
                }
            }

            idx = idx - 1
        }
        if result == nil {
            return endNote
        }
        else {
            return result!
        }
    }
    
    func getNoteDisplayCharacteristics(staff:Staff) -> NoteStaffPlacement {
        return self.noteStaffPlacements[staff.staffNum]!
    }
    
    ///The note has a default accidental determined by which key the score is in but can be overidden by content specifying a written accidental
    ///The written accidental must overide the default accidental and the note's offset adjusted accordingly.
    ///When a written accidental is specified this code checks the note offset positions for this staff (coming from the score's key) and decides how the note should move from its
    ///default staff offset based on the written accidental. e.g. a note at MIDI 75 would be defaulted to show as E ♭ in C major but may be speciifed to show as D# by a written
    ///accidentail. In that case the note must shift down 1 unit of offset.
    ///
    func setNotePlacementAndAccidental(staff:Staff, barAlreadyHasNote:Bool) {
        let defaultNoteData = staff.getNoteViewPlacement(note: self)
        var offsetFromMiddle = defaultNoteData.offsetFromStaffMidline
        var offsetAccidental:Int? = nil
        
        if self.isOnlyRhythmNote {
            offsetFromMiddle = 0
        }
        if let writtenAccidental = self.accidental {
            //Content provided a specific accidental
            offsetAccidental = writtenAccidental
            if writtenAccidental != defaultNoteData.accidental {
                let defaultNoteStaffPlacement = staff.noteStaffPlacement[self.midiNumber]
                let targetOffsetIndex = self.midiNumber - writtenAccidental
                let targetNoteStaffPlacement = staff.noteStaffPlacement[targetOffsetIndex]
                let adjustOffset = defaultNoteStaffPlacement.offsetFromStaffMidline - targetNoteStaffPlacement.offsetFromStaffMidline
                offsetFromMiddle -= adjustOffset
            }
        }
        else {
            //Determine if the note's accidental is implied by the key signature
            //Or a note has to have a natural accidental to offset the key signture
            let keySignatureHasNote = staff.score.key.hasNote(note: self.midiNumber)
            if let defaultAccidental = defaultNoteData.accidental {
                if !keySignatureHasNote {
                    if !barAlreadyHasNote {
                        offsetAccidental = defaultAccidental
                    }
                }
            }
            else {
                let keySignatureHasNote = staff.score.key.hasNote(note: self.midiNumber + 1)
                if keySignatureHasNote {
                    if !barAlreadyHasNote {
                        offsetAccidental = 0
                    }
                }
            }
        }
        let placement = NoteStaffPlacement(offsetFroMidLine: offsetFromMiddle, accidental: offsetAccidental)
        self.noteStaffPlacements[staff.staffNum] = placement
        //self.debug("setNoteDisplayCharacteristics")
    }
    
//    func debugx(_ context:String) -> Bool {
//        print("\n============ NOTE", context, self.midiNumber, self.value)
//        for i in 0..<self.noteStaffPlacements.count {
//            print(" staff", "offset", noteStaffPlacements[i]?.offsetFromStaffMidline ?? "_", "accidental", noteStaffPlacements[i]?.accidental ?? "_")
//        }
//        return true
//    }
}

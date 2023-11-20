import Foundation

class TagHigh : ObservableObject {
    @Published var content:String
    var popup:String?
    var enablePopup:Bool
    init(content:String, popup:String?, enablePopup:Bool) {
        self.content = content
        self.popup = popup
        self.enablePopup = enablePopup
    }
}

class TimeSlice : ScoreEntry {
    @Published var entries:[TimeSliceEntry]
    @Published var tagHigh:TagHigh?
    @Published var tagLow:String?
    @Published var notesLength:Int?
    @Published var statusTag:StatusTag = .noTag

    var score:Score
    var footnote:String?
    var barLine:Int = 0
    var beatNumber:Double = 0.0 //the beat in the bar that the timeslice is at
    
    //Used when recording a tap sequence into a score
    var tapDuration:Double
    
    init(score:Score) {
        self.score = score
        self.entries = []
        tapDuration = 0.0
    }
    
    func setStatusTag(_ tag: StatusTag) {
        DispatchQueue.main.async {
            self.statusTag = tag
        }
    }

    func getValue() -> Double {
        if entries.count > 0 {
            return entries[0].getValue()
        }
        return 0
    }
    
    func addNote(n:Note) {
        n.timeSlice = self
        self.entries.append(n)

        for i in 0..<score.staffs.count {
            n.setNotePlacementAndAccidental(staff: score.staffs[i], barAlreadyHasNote: score.noteCountForBar(pitch:n.midiNumber) > 1)
        }
        score.updateStaffs()
        score.addStemAndBeamCharaceteristics()
    }
    
    func addRest(rest:Rest) {
        self.entries.append(rest)
        score.updateStaffs()
        score.addStemAndBeamCharaceteristics()
    }

    func addChord(c:Chord) {
        for n in c.getNotes() {
            self.addNote(n: n)
        }
        score.addStemAndBeamCharaceteristics()
        score.updateStaffs()
    }
    
    func setTags(high:TagHigh, low:String) {
        //DispatchQueue.main.async {
            self.tagHigh = high
            self.tagLow = low
        //}
    }
    
    static func == (lhs: TimeSlice, rhs: TimeSlice) -> Bool {
        return lhs.id == rhs.id
    }
        
    func addTriadAt(timeSlice:TimeSlice, rootNoteMidi:Int, value: Double, staffNum:Int) {
        if getTimeSliceEntries().count == 0 {
            return
        }
        //if let score = score {
            let triad = score.key.makeTriadAt(timeSlice:timeSlice, rootMidi: rootNoteMidi, value: value, staffNum: staffNum)
            for note in triad {
                addNote(n: note)
            }
        //}
    }
    
    func anyNotesRotated() -> Bool {
        for n in entries {
            if n is Note {
                let note:Note = n as! Note
                if note.rotated {
                    return true
                }
            }
        }
        return false
    }
    
}

public class Chord : Identifiable {
    private var notes:[Note] = []
    
    public enum ChordType {
        case major
        case minor
        case diminished
    }
    
    public init() {
    }
    
    public func makeTriad(timeSlice:TimeSlice, root: Int, type:ChordType, staffNum: Int) {
        notes.append(Note(timeSlice:timeSlice, num: root, staffNum: staffNum))
        if type == ChordType.major {
            notes.append(Note(timeSlice:timeSlice, num: root+4, staffNum: staffNum))
        }
        else {
            notes.append(Note(timeSlice:timeSlice, num: root+3, staffNum: staffNum))
        }
        if type == ChordType.diminished {
            notes.append(Note(timeSlice:timeSlice, num: root+6, staffNum: staffNum))
        }
        else {
            notes.append(Note(timeSlice:timeSlice, num: root+7, staffNum: staffNum))
        }
    }
    
    public func addNote(note:Note) {
        self.notes.append(note)
        self.notes.sort()
        //check for adjoing 2nds which have to be displayed twisted
        for n in 0..<self.notes.count-1 {
            let note = self.notes[n]
            let above = self.notes[n+1]
            if above.midiNumber - note.midiNumber <= 3 {
                note.rotated = true
            }
        }
    }
    
    public func getNotes() -> [Note] {
        return self.notes
    }

    /// Dont double the 3rd
    /// Keep each voice within one octave of the one below except for tenor down to base
    public func makeSATBFourNote(timeSlice:TimeSlice) -> Chord {
        let result = Chord()
        var desiredPitch = Note.MIDDLE_C - Note.OCTAVE
        let baseNote = Note.getClosestOctave(note: self.notes[0].midiNumber, toPitch: desiredPitch)
        result.notes.append(Note(timeSlice:timeSlice, num: baseNote, staffNum: 1))
        let voiceGap = Note.OCTAVE/2 // + 3
        
        //choose the tenor as triad note 1 or 2
        let tenorCandidates = [1,2]
        desiredPitch = baseNote + voiceGap //+ 2// + voiceGap/2
        var minDiff = 1000
        var tenorChoiceIndex = 0
        var tenorNote = 0
        for c in tenorCandidates {
            let closest = Note.getClosestOctave(note: self.notes[c].midiNumber, toPitch: desiredPitch, onlyHigher: true)
            let diff = abs(closest - desiredPitch)
            if diff < minDiff {
                minDiff = diff
                tenorChoiceIndex = c
                tenorNote = closest
            }
        }
        result.notes.append(Note(timeSlice:timeSlice, num: tenorNote, staffNum: 1))
        
        //choose the alto
        desiredPitch = tenorNote + voiceGap
        var altoCandidates = [0, 2]
        if tenorChoiceIndex != 1 { //dont double the 3rd
            altoCandidates.append(1)
        }

        minDiff = Int.max
        var altoChoiceIndex = 0
        var altoNote = 0
        for c in altoCandidates {
            let closest = Note.getClosestOctave(note: self.notes[c].midiNumber, toPitch: desiredPitch, onlyHigher: true)
            let diff = abs(closest - desiredPitch)
            if diff < minDiff {
                minDiff = diff
                altoChoiceIndex = c
                altoNote = closest
            }
        }
        result.notes.append(Note(timeSlice:timeSlice, num: altoNote, staffNum: 0))

        //choose the soprano
        desiredPitch = altoNote + voiceGap
        var sopranoCandidates = [0, 2]
        if tenorChoiceIndex != 1 && altoChoiceIndex != 1 {
            sopranoCandidates = [1] //only the 3rd is allowed - the 3rd must be present
        }
        
        minDiff = Int.max
        var sopranoNote = 0
        for c in sopranoCandidates {
            let closest = Note.getClosestOctave(note: self.notes[c].midiNumber, toPitch: desiredPitch, onlyHigher: true)
            let diff = abs(closest - desiredPitch)
            if diff < minDiff {
                minDiff = diff
                sopranoNote = closest
            }
        }
        result.notes.append(Note(timeSlice:timeSlice, num: sopranoNote, staffNum: 0))
        return result
    }

//    func addSeventh() {
//        let n = self.notes[0].midiNumber
//        self.notes.append(Note(num: n+10))
//    }
    
//    func makeInversion(inv: Int) -> Chord {
//        let res = Chord()
//        for i in 0...self.notes.count-1 {
//            let j = (i + inv)
//            var n = self.notes[j % self.notes.count].midiNumber
//            if j >= self.notes.count {
//                n += 12
//            }
//            res.notes.append(Note(num: n))
//        }
//        return res
//    }
    
    ///Return a chord based on the notes of the toChordTriad that is a voice led cadence from the self chord
    public func makeCadenceWithVoiceLead(timeSlice:TimeSlice, toChordTriad: Chord) -> Chord {
        var result:[Int] = []
        
        let destinationRoot = toChordTriad.notes[0].midiNumber
        let leadingRoot = notes[0].midiNumber
        let closestRoot = Note.getClosestOctave(note: destinationRoot, toPitch: leadingRoot)
        result.append(closestRoot)
        
        for n in 1..<notes.count {

            let fromNote = notes[n].midiNumber
            
            var leastDiff = Int.max
            var bestNote = 0

            for m in toChordTriad.notes {
                let toNoteOctaves = Note.getAllOctaves(note: m.midiNumber)
                for toNoteOctave in toNoteOctaves {
                    if result.contains(toNoteOctave) {
                        continue
                    }
                    let diff = abs(toNoteOctave - fromNote)
                    if diff < leastDiff {
                        leastDiff = diff
                        bestNote = toNoteOctave
                    }
                }
            }
            result.append(bestNote)
            if n == 33 {
                break
            }
        }
        
        let resultChord = Chord()
        for n in 0..<result.count {
            resultChord.notes.append(Note(timeSlice:timeSlice, num: result[n], staffNum: n < 2 ? 1 : 0))
        }
        return resultChord
    }
    
    public func moveClosestTo(pitch: Int, index: Int) {
        let pitch = Note.getClosestOctave(note: self.notes[index].midiNumber, toPitch: pitch)
        let offset = self.notes[index].midiNumber - pitch
        for i in 0...self.notes.count-1 {
            self.notes[i].midiNumber -= offset
        }
    }
    
    public func toStr() -> String {
        var s = ""
        for note in self.notes {
            //var n = (note.num % Note.noteNames.count)...
            s += "\(note.midiNumber)  "
        }
        return s
    }
        
    public func order() {
        notes.sort {
            $0.midiNumber < $1.midiNumber
        }
    }
    
}

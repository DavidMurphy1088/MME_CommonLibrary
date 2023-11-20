import Foundation
import AVKit
import AVFoundation

public class ScoreEntry : ObservableObject, Identifiable, Hashable {
    public let id = UUID()
    var sequence:Int = 0

    public static func == (lhs: ScoreEntry, rhs: ScoreEntry) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func getTimeSliceEntries() -> [TimeSliceEntry] {
        var result:[TimeSliceEntry] = []
        if self is TimeSlice {
            let ts:TimeSlice = self as! TimeSlice
            let entries = ts.entries
            for entry in entries {
                //if entry is Note {
                    result.append(entry)
                //}
            }
        }
        return result
    }
    
    func getTimeSliceNotes(staffNum:Int? = nil) -> [Note] {
        var result:[Note] = []
        if self is TimeSlice {
            let ts:TimeSlice = self as! TimeSlice
            let entries = ts.entries
            for entry in entries {
                if entry is Note {
                    if let staffNum = staffNum {
                        let note = entry as! Note
                        if note.staffNum == staffNum {
                            result.append(note)
                        }
                    }
                    else {
                        result.append(entry as! Note)
                    }
                }
            }
        }
        return result
    }
}

class StudentFeedback : ObservableObject {
    var correct:Bool = false
    var feedbackExplanation:String? = nil
    var feedbackNotes:String? = nil
    var tempo:Int? = nil
}

//class StaffLayoutSize: ObservableObject {
//    @Published var lineSpacing:Double
//
//    init () {
//        //self.lineSpacing = 0.0
//        self.lineSpacing = 15.0
//    }
//
//    func setLineSpacing(_ v:Double) {
//        DispatchQueue.main.async {
//            self.lineSpacing = v
//        }
//    }
//
//
//}

public class Score : ObservableObject {
    let id:UUID
    
    var timeSignature:TimeSignature
    var key:Key
    @Published var barLayoutPositions:BarLayoutPositions
    @Published var barEditor:BarEditor?

    @Published var scoreEntries:[ScoreEntry] = []
    
    let ledgerLineCount =  2 //3//4 is required to represent low E
    var staffs:[Staff] = []
    
    var studentFeedback:StudentFeedback? = nil
    var tempo:Int?
    //var lineSpacing = 15.0
    var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 10.0 : 15.0

    private var totalStaffLineCount:Int = 0
    static var accSharp = "\u{266f}"
    static var accNatural = "\u{266e}"
    static var accFlat = "\u{266d}"
    var label:String? = nil
        
    init(key:Key, timeSignature:TimeSignature, linesPerStaff:Int) {
        self.id = UUID()
        self.timeSignature = timeSignature
        totalStaffLineCount = linesPerStaff + (2*ledgerLineCount)
        self.key = key
        barLayoutPositions = BarLayoutPositions()
        //self.staffLayoutSize = StaffLayoutSize()
    }

    func createTimeSlice() -> TimeSlice {
        let ts = TimeSlice(score: self)
        ts.sequence = self.scoreEntries.count
        self.scoreEntries.append(ts)
        if self.scoreEntries.count > 16 {
            if UIDevice.current.userInterfaceIdiom == .phone {
                ///With too many note on the stave 
                lineSpacing = lineSpacing * 0.95
            }
        }
        return ts
    }

    func createBarEditor(onEdit: @escaping (_ wasChanged:Bool) -> Void) {
        self.barEditor = BarEditor(score: self, onEdit: onEdit)
    }
    
    func getStaffHeight() -> Double {
        //leave enough space above and below the staff for the Timeslice view to show its tags
        let height = Double(getTotalStaffLineCount() + 2) * self.lineSpacing
        return height
    }
    
    func getBarCount() -> Int {
        var count = 0
        for entry in self.scoreEntries {
            if entry is BarLine {
                count += 1
            }
        }
        return count + 1
    }
    
    func getTotalStaffLineCount() -> Int {
        return self.totalStaffLineCount
    }
    
    func getAllTimeSlices() -> [TimeSlice] {
        var result:[TimeSlice] = []
        for scoreEntry in self.scoreEntries {
            if scoreEntry is TimeSlice {
                let ts = scoreEntry as! TimeSlice
                result.append(ts)
            }
        }
        return result
    }
    
    func addTriadNotes() {
        let taggedSlices = searchTimeSlices{ (timeSlice: TimeSlice) -> Bool in
            return timeSlice.tagHigh != nil
        }
        
        for tagSlice in taggedSlices {
            if let triad = tagSlice.tagLow {
                let notes = key.getTriadNotes(triadSymbol:triad)
                if let hiTag:TagHigh = tagSlice.tagHigh {
                    hiTag.popup = notes
                    if let loTag = tagSlice.tagLow {
                        tagSlice.setTags(high:hiTag, low:loTag)
                    }
                }
            }
        }
    }
    
    func getTimeSlicesForBar(bar:Int) -> [TimeSlice] {
        var result:[TimeSlice] = []
        var barNum = 0
        for scoreEntry in self.scoreEntries {
            if scoreEntry is BarLine {
                barNum += 1
                continue
            }
            if barNum == bar {
                if let ts = scoreEntry as? TimeSlice {
                    result.append(ts)
                }
            }
        }
        return result
    }

    func debugScorezz(_ ctx:String, withBeam:Bool) {
        print("\nSCORE DEBUG =====", ctx, "\tKey", key.keySig.accidentalCount, "StaffCount", self.staffs.count)
        for t in self.getAllTimeSlices() {
            if t.entries.count == 0 {
                print("ZERO ENTRIES")
                continue
            }
            for note in t.getTimeSliceNotes() {
                if withBeam {
                    print("  Seq", t.sequence, "type:", type(of: t.entries[0]), "midi:", note.midiNumber, "Value:", t.getValue() , "[beamType:", note.beamType,
                          "beamEnd", note.beamEndNote ?? "", "]")
                }
                else {
                    print("  Seq", t.sequence,
                          "[type:", type(of: t.entries[0]), "]",
                          "[midi:",note.midiNumber, "]",
                          "[Value:",note.getValue(),"]",
                          "[TapDuration:",t.tapDuration,"]",
                          "[Accidental:",note.accidental ?? "","]",
                          "[Staff:",note.staffNum,"]",
                          "[stem:",note.stemDirection, note.stemLength, "]",
                          "[placement:",note.noteStaffPlacements[0]?.offsetFromStaffMidline ?? "none", note.noteStaffPlacements[0]?.accidental ?? "none","]",
                          t.getValue() ,
                          "status",t.statusTag,
                          "tagHigh", t.tagHigh ?? ""
                    )
                }
            }
        }
    }
    
    ///Return the first timeslice index of where the scores differ
//    func getFirstDifferentTimeSlicex(compareScore:Score) -> Int? {
//         var result:Int? = nil
//         var scoreCtr = 0
//
//         let scoreTimeSlices = self.getAllTimeSlices()
//         let compareTimeSlices = compareScore.getAllTimeSlices()
//
//         for scoreTimeSlice in scoreTimeSlices {
//
//             if compareTimeSlices.count <= scoreCtr {
//                 result = scoreCtr
//                 break
//             }
//
//             let compareEntry = compareTimeSlices[scoreCtr]
//             let compareNotes = compareEntry.getTimeSliceEntries()
//             let scoreNotes = scoreTimeSlice.getTimeSliceEntries()
//
//             if compareNotes.count == 0 || scoreNotes.count == 0 {
//                 result = scoreCtr
//                 break
//             }
//
//             if scoreCtr == scoreTimeSlices.count - 1 {
//                 if scoreNotes[0].getValue() > compareNotes[0].getValue() {
//                     result = scoreCtr
//                     break
//                 }
//                 else {
//                     compareNotes[0].setValue(value: scoreNotes[0].getValue())
//                 }
//             }
//             else {
//                 if scoreNotes[0].getValue() != compareNotes[0].getValue() {
//                     result = scoreCtr
//                     break
//                 }
//             }
//             scoreCtr += 1
//         }
//         return result
//     }
    
    func setHiddenStaff(num:Int, isHidden:Bool) {
        DispatchQueue.main.async {
            if self.staffs.count > num {
                //self.hiddenStaffNo = num
                self.staffs[num].isHidden = isHidden
                for staff in self.staffs {
                    staff.update()
                }
            }
        }
    }
    
    func setStudentFeedback(studentFeedack:StudentFeedback? = nil) {
        //DispatchQueue.main.async {
            self.studentFeedback = studentFeedack
        //}
    }

    func getLastTimeSlice() -> TimeSlice? {
        var ts:TimeSlice?
        for index in stride(from: scoreEntries.count - 1, through: 0, by: -1) {
            let element = scoreEntries[index]
            if element is TimeSlice {
                ts = element as? TimeSlice
                break
            }
        }
        return ts
    }

    func updateStaffs() {
        for staff in staffs {
            staff.update()
        }
    }
    
    func createStaff(num:Int, staff:Staff) {
        if self.staffs.count <= num {
            self.staffs.append(staff)
        }
        else {
            self.staffs[num] = staff
        }
    }
    
    func getStaff() -> [Staff] {
        return self.staffs
    }
    
    func setKey(key:Key) {
        DispatchQueue.main.async {
            self.key = key
            self.updateStaffs()
        }
    }
    
    func addBarLine() {
        let barLine = BarLine()
        barLine.sequence = self.scoreEntries.count
        self.scoreEntries.append(barLine)
    }
    
    func addTie() {
        let tie = Tie()
        tie.sequence = self.scoreEntries.count
        self.scoreEntries.append(tie)
    }

    func clear() {
        self.scoreEntries = []
        for staff in staffs  {
            staff.clear()
        }
    }
    
    func getEntryForSequence(sequence:Int) -> ScoreEntry? {
        for entry in self.scoreEntries {
            if entry.sequence == sequence {
                return entry
            }
        }
        return nil
    }
    
    ///Determine if the stem for the note(s) should go up or down
    func getStemDirection(staff:Staff, notes:[Note]) -> StemDirection {
        var totalOffsets = 0
        for n in notes {
            if n.staffNum == staff.staffNum {
                let placement = staff.getNoteViewPlacement(note: n)
                totalOffsets += placement.offsetFromStaffMidline
            }
        }
        return totalOffsets <= 0 ? StemDirection.up: StemDirection.down
    }
    
    func addStemAndBeamCharaceteristics() {
        guard let timeSlice = self.getLastTimeSlice() else {
            return
        }
        if timeSlice.entries.count == 0 {
            return
        }
        addBeatValues()
        if timeSlice.entries[0] is Note {
            addStemCharaceteristics()
        }
    }
    
    ///For each time slice calculate its beat number in its bar
    func addBeatValues() {
        var beatCtr = 0.0
        for i in 0..<self.scoreEntries.count {
            if self.scoreEntries[i] is BarLine {
                beatCtr = 0
                continue
            }
            if let timeSlice = self.scoreEntries[i] as? TimeSlice {
                timeSlice.beatNumber = beatCtr
                beatCtr += timeSlice.getValue()
            }
        }
    }

    ///Determine whether quavers can be beamed within a bar's strong and weak beats
    func canBeBeamedTo(timeSignature:TimeSignature, startBeamTimeSlice:TimeSlice, lastBeat:Double) -> Bool {
        if timeSignature.top == 4 {
            let startBeatInt = Int(startBeamTimeSlice.beatNumber)
            if lastBeat > 2 {
                return [2, 3].contains(startBeatInt)
            }
            else {
                return [0, 1].contains(startBeatInt)
            }
        }
        if timeSignature.top == 3 {
            return Int(startBeamTimeSlice.beatNumber) == Int(lastBeat)
        }
        if timeSignature.top == 2 {
            let startBeatInt = Int(startBeamTimeSlice.beatNumber)
            //if lastBeat > 1 {
                return [0, 1].contains(startBeatInt)
//            }
//            else {
//                return [0].contains(startBeatInt)
//            }
        }
        return false
    }
    
    ///If the last note added was a quaver, identify any previous adjoining quavers and set them to be joined with a quaver bar
    ///Set the beginning, middle and end quavers for the beam
    private func addStemCharaceteristics() {
        let lastNoteIndex = self.scoreEntries.count - 1
        let scoreEntry = self.scoreEntries[lastNoteIndex]

        guard scoreEntry is TimeSlice else {
            return
        }

        let lastTimeSlice = scoreEntry as! TimeSlice
        let notes = lastTimeSlice.getTimeSliceNotes()
        if notes.count == 0 {
            return
        }

        let lastNote = notes[0]
        lastNote.sequence = self.getAllTimeSlices().count

        //The number of staff lines for a full stem length
        let stemLengthLines = 3.5

        if lastNote.getValue() != Note.VALUE_QUAVER {
            for staffIndex in 0..<self.staffs.count {
                let stemDirection = getStemDirection(staff: self.staffs[staffIndex], notes: notes)
                let staffNotes = lastTimeSlice.getTimeSliceNotes(staffNum: staffIndex)
                for note in staffNotes {
                    note.stemDirection = stemDirection
                    note.stemLength = stemLengthLines
                    ///Dont try yet to beam semiquavers
                    if lastNote.getValue() == Note.VALUE_SEMIQUAVER {
                        note.beamType = .end
                    }
                }
            }
            return
        }
        
        let staff = self.staffs[lastNote.staffNum]
        //apply the quaver beam back from the last note
        //let endQuaver = notes[0]
        var notesUnderBeam:[Note] = []
        notesUnderBeam.append(lastNote)
        
        ///Figure out the start, middle and end of this group of quavers
        for i in stride(from: lastNoteIndex - 1, through: 0, by: -1) {
            let scoreEntry = self.scoreEntries[i]
            if !(scoreEntry is TimeSlice) {
                break
            }
            let timeSlice = scoreEntry as! TimeSlice
            if timeSlice.entries.count > 0 {
                if timeSlice.entries[0] is Rest {
                    break
                }
            }
            let notes = timeSlice.getTimeSliceNotes()
            if notes.count > 0 {
                if notes[0].getValue() == Note.VALUE_QUAVER {
                    if !canBeBeamedTo(timeSignature: self.timeSignature, startBeamTimeSlice: timeSlice, lastBeat: lastTimeSlice.beatNumber) {
                        break
                    }
                    let note = notes[0]
                    notesUnderBeam.append(note)
                }
                else {
                    break
                }
            }
        }

        ///Check if beam is valid
        var totalValueUnderBeam = 0.0
        var valid = true

        for note in notesUnderBeam {
//            if note.beamType == .start {
//                if note.timeSlice?.beatNumber.truncatingRemainder(dividingBy: 1.0) != 0 {
//                    valid = false
//                    break
//                }
//            }
            totalValueUnderBeam += note.getValue()
        }
        
        if valid {
            valid = totalValueUnderBeam.truncatingRemainder(dividingBy: 1) == 0
        }
            
        ///Its not valid so unbeam
        if !valid {
            ///Discard the beam group because cant beam to an off-beat note
            notesUnderBeam = []
            notesUnderBeam.append(lastNote)
        }
        
        
        ///Determine if the quaver group has up or down stems based on the overall staff placement of the group
        var totalOffset = 0
        for note in notesUnderBeam {
            let placement = staff.getNoteViewPlacement(note: note)
            totalOffset += placement.offsetFromStaffMidline
        }
        
        ///Set each note's beam type and calculate the nett above r below the staff line for the quaver group (for the subsequnet stem up or down decison)
        let startNote = notesUnderBeam[0]
        let startPlacement = staff.getNoteViewPlacement(note: startNote)

        let endNote = notesUnderBeam[notesUnderBeam.count - 1]
        let endPlacement = staff.getNoteViewPlacement(note: endNote)

        var beamSlope:Double = Double(endPlacement.offsetFromStaffMidline - startPlacement.offsetFromStaffMidline)
        beamSlope = beamSlope / Double(notesUnderBeam.count - 1)

        var requiredBeamPosition = Double(startPlacement.offsetFromStaffMidline)
        
        for i in 0..<notesUnderBeam.count {
            let note = notesUnderBeam[i]
            if i == 0 {
                note.beamType = .end
                note.stemLength = stemLengthLines
            }
            else {
                if i == notesUnderBeam.count-1 {
                    note.beamType = .start
                    note.stemLength = stemLengthLines
                }
                else {
                    note.beamType = .middle
                    let placement = staff.getNoteViewPlacement(note: note)
                    ///adjust the stem length according to where the note is positioned vs. where the beam slope position requires
                    let stemDiff = Double(placement.offsetFromStaffMidline) - requiredBeamPosition
                    note.stemLength = stemLengthLines + (stemDiff / 2.0 * (totalOffset > 0 ? 1.0 : -1.0))
                }
            }
            requiredBeamPosition += beamSlope
            note.stemDirection = totalOffset > 0 ? .down : .up
        }
        
        ///Check no stranded beam starts. Every beam start must have a beam end so it is rendered correctly.
        ///Quavers under beams only have their stems rendered by the presence of an end note in their beam group
        func noteInTS(_ tsIndex:Int) -> Note? {
            if tsIndex < self.getAllTimeSlices().count {
                let ts = getAllTimeSlices()[tsIndex]
                if ts.getTimeSliceNotes().count > 0 {
                    return ts.getTimeSliceNotes()[0]
                }
            }
            return nil
        }

        for i in 0..<getAllTimeSlices().count {
            let note = noteInTS(i)
            if let note = note {
                if note.beamType == .start {
                    let nextNote = noteInTS(i+1)
                    if let nextNote = nextNote {
                        if !([QuaverBeamType.end, QuaverBeamType.middle].contains(nextNote.beamType)) {
                            note.beamType = .end
                            break
                        }
                    }
                }
            }
        }
        //debugScore("end of beaming", withBeam: true)
    }
    
    func copyEntries(from:Score, count:Int? = nil) {
        let staff = self.staffs[0]
        createStaff(num: 0, staff: Staff(score: self, type: staff.type, staffNum: 0, linesInStaff: staff.linesInStaff))

        self.scoreEntries = []
        var cnt = 0
        for entry in from.scoreEntries {
            if let fromTs = entry as? TimeSlice {
                let ts = self.createTimeSlice()
                for t in fromTs.getTimeSliceEntries() {
                    if let note = t as? Note {
                        ts.addNote(n: Note(note: note))
                    }
                    else {
                        if let rest = t as? Rest {
                            ts.addRest(rest: Rest(r: rest))
                        }
                    }
                }
            }
            else {
                self.scoreEntries.append(entry)
            }
            if let count = count {
                cnt += 1
                if cnt >= count {
                    break
                }
            }
        }
    }
    
    func errorCount() -> Int {
        var cnt = 0
        for timeSlice in self.getAllTimeSlices() {
            //let entries = timeSlice.getTimeSliceEntries()
            //if entries.count > 0 {
                if timeSlice.statusTag == .inError {
                    cnt += 1
                }
            //}
        }
        return cnt
    }
    
    func isNextTimeSliceANote(fromScoreEntryIndex:Int) -> Bool {
        if fromScoreEntryIndex > self.scoreEntries.count - 1 {
            return false
        }
        for i in fromScoreEntryIndex..<self.scoreEntries.count {
            if let timeSlice = self.scoreEntries[i] as? TimeSlice {
                if timeSlice.entries.count > 0 {
                    if timeSlice.entries[0] is Note {
                        return true
                    }
                    else {
                        return false
                    }
                }
            }
        }
        return false
    }
    
    ///Return a score based on the question score but modified to show where a tapped duration differs from the question
    func fitScoreToQuestionScore(tappedScore:Score, tolerancePercent:Double) -> (Score, StudentFeedback) {
        let outputScore = Score(key: self.key, timeSignature: self.timeSignature, linesPerStaff: 1)
        let staff = Staff(score: outputScore, type: .treble, staffNum: 0, linesInStaff: 1)
        outputScore.createStaff(num: 0, staff: staff)
            
        var errorsFlagged = false

        //self.debugScore("Question", withBeam: false)
        //let outputScoreTimeSliceValues = outputScore.scoreEntries
        var tapIndex = 0
        var explanation = ""
        //tappedScore.debugScore("StartFit", withBeam: false)
        for questionIndex in 0..<self.scoreEntries.count {
            guard let questionTimeSlice:TimeSlice = self.scoreEntries[questionIndex] as? TimeSlice else {
                //if !errorsFlagged {
                    outputScore.addBarLine()
                //}
                continue
            }
            if questionTimeSlice.entries.count == 0 {
                continue
            }
            let outputTimeSlice = outputScore.createTimeSlice()
            guard let questionNote = questionTimeSlice.entries[0] as? Note else {
                if !errorsFlagged {
                    outputTimeSlice.addRest(rest: Rest(timeSlice: outputTimeSlice, value: questionTimeSlice.getValue(), staffNum: 0))
                }
                continue
            }
            
            let trailingRestsDuration = self.getTrailingRestsDuration(index: questionIndex + 1)
            let questionNoteDuration = questionNote.getValue() + trailingRestsDuration
            var outputNoteValue = questionNote.getValue()
            if errorsFlagged {
                outputTimeSlice.statusTag = .afterError
            }
            else {
                if tapIndex >= tappedScore.getAllTimeSlices().count {
                    errorsFlagged = true
                    explanation = "• There was no tap"
                    outputTimeSlice.statusTag = .inError
                }
                else {
                    let tap = tappedScore.getAllTimeSlices()[tapIndex]
                    let delta = questionNoteDuration * tolerancePercent * 0.01
                    let lowBound = questionNoteDuration - delta
                    let hiBound = questionNoteDuration + delta
                    //if questionNoteDuration != tap.getValue() {
                    if tap.tapDuration < lowBound || tap.tapDuration > hiBound {
                        outputTimeSlice.statusTag = .inError
                        questionTimeSlice.statusTag = .hilightAsCorrect
                        outputNoteValue = tap.getValue()
                        errorsFlagged = true
                        let name = TimeSliceEntry.getValueName(value:questionNote.getValue())
                        //let tapName = TimeSliceEntry.getValueName(value:tap.getValue())
                        explanation = "• The question note is a \(name)"
                        if trailingRestsDuration > 0 {
                            explanation += " followed by a rest"
                        }
                        else {
                            explanation += ""
                        }
                        //explanation += "\n• Your tap was a \(tapName) and was too "
                        explanation += "\n• Your tap was too "
                        if questionNoteDuration > tap.getValue() {
                            explanation += "short 🫢"
                        }
                        else {
                            explanation += "long 🫢"
                        }
//                        if trailingRestsDuration > 0 {
//                            if tap.getValue() == questionNote.getValue() {
//                                explanation += "\n• It did not allow any time for the following rest"
//                            }
//                            else {
//                                if questionNoteDuration > tap.getValue() {
//                                    explanation += "\n• It did not allow enough time for the following rest"
//                                }
//                                else {
//                                    explanation += "\n• It allowed too much time for the following rest"
//                                }
//                            }
//                        }
                        //outputTimeSlice.entries[0].setValue(value: 0)
                        explanation += ""
                    }
                }
                let outputNote = Note(timeSlice: outputTimeSlice, num: questionNote.midiNumber, value: outputNoteValue, staffNum: questionNote.staffNum)
                outputNote.setIsOnlyRhythm(way: questionNote.isOnlyRhythmNote)
                outputTimeSlice.addNote(n: outputNote)
                tapIndex += 1
            }
        }
        //outputScore.debugScore("Output  ", withBeam: false)

        let feedback = StudentFeedback()
        feedback.feedbackExplanation = explanation
        
//        let out = outputScore.getAllTimeSlices()
//        print("==============", feedback.correct, feedback.feedbackExplanation)
//        for q in self.getAllTimeSlices() {
//            print("QuestionOut", type(of:q.entries[0]), q.entries[0].getValue(), q.statusTag)
//        }
//        for e in out {
//            print("   ScoreOut", type(of:e.entries[0]), e.entries[0].getValue(), e.statusTag)
//        }

        return (outputScore, feedback)
    }

    func getTrailingRestsDuration(index:Int) -> Double {
        var totalDuration = 0.0
        for i in index..<self.scoreEntries.count {
            if let ts = self.self.scoreEntries[i] as? TimeSlice {
                if ts.entries.count > 0 {
                    if let rest = ts.entries[0] as? Rest {
                        totalDuration += rest.getValue()
                    }
                    else {
                        break
                    }
                }
            }
        }
        return totalDuration
    }
    
    func clearTags() {
        for ts in getAllTimeSlices() {
            ts.setStatusTag(.noTag)
        }
    }
    
    func noteCountForBar(pitch:Int) -> Int {
        var count = 0
        for entry in self.scoreEntries.reversed() {
            if entry is BarLine {
                break
            }
            if let ts = entry as? TimeSlice {
                if ts.getTimeSliceNotes().count > 0 {
                    let note = ts.entries[0] as? Note
                    if note?.midiNumber == pitch {
                        count += 1
                    }
                }
            }
        }
        return count
    }
    
    func searchTimeSlices(searchFunction:(_:TimeSlice)->Bool) -> [TimeSlice]  {
        var result:[TimeSlice] = []
        for entry in self.getAllTimeSlices() {
            if searchFunction(entry) {
                result.append(entry)
            }
        }
        return result
    }
    
    func searchEntries(searchFunction:(_:ScoreEntry)->Bool) -> [ScoreEntry]  {
        var result:[ScoreEntry] = []
        for entry in self.scoreEntries {
            if searchFunction(entry) {
                result.append(entry)
            }
        }
        return result
    }
}


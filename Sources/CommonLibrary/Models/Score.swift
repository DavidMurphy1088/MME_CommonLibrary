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
    
    public func getTimeSliceEntries() -> [TimeSliceEntry] {
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
    
    public func getTimeSliceNotes(staffNum:Int? = nil) -> [Note] {
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

public class StudentFeedback : ObservableObject {
    public var correct:Bool = false
    public var feedbackExplanation:String? = nil
    public var feedbackNotes:String? = nil
    public var tempo:Int? = nil
    public var rhythmTolerance:Int? = nil
}

public class Score : ObservableObject {
    let id:UUID
    
    public var timeSignature:TimeSignature
    public var key:Key
    @Published public var barLayoutPositions:BarLayoutPositions
    @Published public var barEditor:BarEditor?

    @Published public var scoreEntries:[ScoreEntry] = []
    
    let ledgerLineCount =  2 //3//4 is required to represent low E
    public var staffs:[Staff] = []
    
    public var studentFeedback:StudentFeedback? = nil
    public var tempo:Int?
    
    //public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 10.0 : 8.0
    //public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 10.0 : 15.0
    public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 8.0 : 15.0

    private var totalStaffLineCount:Int = 0
    static var accSharp = "\u{266f}"
    static var accNatural = "\u{266e}"
    static var accFlat = "\u{266d}"
    public var label:String? = nil
    public var heightPaddingEnabled:Bool
    
    public init(key:Key, timeSignature:TimeSignature, linesPerStaff:Int, heightPaddingEnabled:Bool = true) {
        self.id = UUID()
        self.timeSignature = timeSignature
        totalStaffLineCount = linesPerStaff + (2*ledgerLineCount)
        self.key = key
        barLayoutPositions = BarLayoutPositions()
        self.heightPaddingEnabled = heightPaddingEnabled
    }

    public func createTimeSlice() -> TimeSlice {
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

    public func createBarEditor(onEdit: @escaping (_ wasChanged:Bool) -> Void) {
        self.barEditor = BarEditor(score: self, onEdit: onEdit)
    }
    
    public func getStaffHeight() -> Double {
        //leave enough space above and below the staff for the Timeslice view to show its tags
        //var height = Double(getTotalStaffLineCount() + 2) * self.lineSpacing
        var height = Double(getTotalStaffLineCount() + 2) * self.lineSpacing ///Jan2024 Leave room for notes on more ledger lines

        let cnt = staffs.filter { !$0.isHidden }.count
        if self.heightPaddingEnabled {
            ///Allow some extra height spacing when possible
            if cnt == 1 {
                //if !UIGlobalsCommon.isLandscape() {
                height = height * 1.6
                //}
            }
        }
        return height
    }
    
    public func getBarCount() -> Int {
        var count = 0
        for entry in self.scoreEntries {
            if entry is BarLine {
                count += 1
            }
        }
        return count + 1
    }
    
    public func setLineSpacing(spacing:Double) {
        self.lineSpacing = spacing
    }
    
    public func getTotalStaffLineCount() -> Int {
        return self.totalStaffLineCount
    }
    
    public func getAllTimeSlices() -> [TimeSlice] {
        var result:[TimeSlice] = []
        for scoreEntry in self.scoreEntries {
            if scoreEntry is TimeSlice {
                let ts = scoreEntry as! TimeSlice
                result.append(ts)
            }
        }
        return result
    }
    
    public func addTriadNotes() {
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
    
    public func getTimeSlicesForBar(bar:Int) -> [TimeSlice] {
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

    public func debugScore3(_ ctx:String, withBeam:Bool) {
        print("\nSCORE DEBUG =====", ctx, "\tKey", key.keySig.accidentalCount, "StaffCount", self.staffs.count)
        for t in self.getAllTimeSlices() {
            if t.entries.count == 0 {
                print("ZERO ENTRIES")
                continue
            }
            if t.getTimeSliceNotes().count > 0 {
                let note = t.getTimeSliceNotes()[0]
                //for ts in t.getTimeSlices() {
                    if withBeam {
                        print("  Seq", t.sequence, 
                              "type:", type(of: t.entries[0]),
                              "midi:", note.midiNumber,
                              "beat:", t.beatNumber,
                              "Value:", t.getValue() ,
                              "stemDirection", note.stemDirection,
                              "stemLength", note.stemLength,
                              "writtenAccidental", note.writtenAccidental,
                              "\t[beamType:", note.beamType,"]",
                              "beamEndNoteSeq:", note.beamEndNote?.timeSlice.sequence ?? "_",
                              "]")
                    }
                    else {
                        print("  Seq", t.sequence,
                              "[type:", type(of: t.entries[0]), "]",
                              "[midi:",note.midiNumber, "]",
                              "[TapDuration Seconds:",t.tapSecondsNormalizedToTempo,"]",
                              "[Note Value:", note.getValue(),"]",
                              "[status]",t.statusTag,
                              "[beat]",t.beatNumber,
                              "[writtenAccidental:",note.writtenAccidental ?? "","]",
                              "[Staff:",note.staffNum,"]"
//                              "[stem:",note.stemDirection, note.stemLength, "]",
//                              "[placement:",note.noteStaffPlacements[0]?.offsetFromStaffMidline ?? "none", note.noteStaffPlacements[0]?.accidental ?? "none","]",
//                              t.getValue() ,
//                              "tagHigh", t.tagHigh ?? ""
                        )
                    }
                //}
            }
        }
    }
    
    public func setHiddenStaff(num:Int, isHidden:Bool) {
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
    
    public func setStudentFeedback(studentFeedack:StudentFeedback? = nil) {
        //DispatchQueue.main.async {
            self.studentFeedback = studentFeedack
        //}
    }

    public func getLastTimeSlice() -> TimeSlice? {
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

    public func updateStaffs() {
        for staff in staffs {
            staff.update()
        }
    }
    
    public func createStaff(num:Int, staff:Staff) {
        if self.staffs.count <= num {
            self.staffs.append(staff)
        }
        else {
            self.staffs[num] = staff
        }
    }
    
    public func getStaff() -> [Staff] {
        return self.staffs
    }
    
    public func setKey(key:Key) {
        DispatchQueue.main.async {
            self.key = key
            self.updateStaffs()
        }
    }
    
    public func addBarLine() {
        let barLine = BarLine()
        barLine.sequence = self.scoreEntries.count
        self.scoreEntries.append(barLine)
    }
    
    public func addTie() {
        let tie = Tie()
        tie.sequence = self.scoreEntries.count
        self.scoreEntries.append(tie)
    }

    public func clear() {
        self.scoreEntries = []
        for staff in staffs  {
            staff.clear()
        }
    }
    
    public func getEntryForSequence(sequence:Int) -> ScoreEntry? {
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
    ///startBeam is the possible start of beam, lastBeat is the end of beam
//    func canBeBeamedTo(timeSignature:TimeSignature, startBeamTimeSlice:TimeSlice, lastBeat:Double) -> Bool {
//        //self.debugScore1("CanBeam start:\(startBeamTimeSlice.sequence) latBeat:\(lastBeat)", withBeam: true)
//        if timeSignature.top == 4 {
//            let startBeatInt = Int(startBeamTimeSlice.beatNumber)
//            if lastBeat > 2 {
//                return [2, 3].contains(startBeatInt)
//            }
//            else {
//                return [0, 1].contains(startBeatInt)
//            }
//        }
//        if timeSignature.top == 3 {
//            ///Check is integer to check start beat is on a main beat
//            ///If check integer then 3/4 with values : 1.5, 0.5, 0.5, 0.5 the 2nd is standalone and 3 and 4 are beamed - which is correct. without check, 3 is beamed to 2
//            ///but with check 1, .5,.5,  .5,.5 beams are 2 and 3 and 4 and 5 but not 2 thru 5 all together. But this is a less bad sin than the one above. So keep integer check inplace
//            ///Beaming code needs a rewrite but first needs 100% definite and simple to understand rules
//            if floor(startBeamTimeSlice.beatNumber) == ceil(startBeamTimeSlice.beatNumber) {
//                let startBeatInt = Int(startBeamTimeSlice.beatNumber)
//                return [0, 1, 2].contains(startBeatInt)
//            }
//            else {
//                return false
//            }
//        }
//        if timeSignature.top == 2 {
//            let startBeatInt = Int(startBeamTimeSlice.beatNumber)
//            return [0, 1].contains(startBeatInt)
//        }
//        return false
//    }
    
    private func determineStemDirections(staff:Staff, notesUnderBeam:[Note], linesForFullStemLength:Double) {
        
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
        
        //The number of staff lines for a full stem length
        
        var minStemLength = linesForFullStemLength
        
        for i in 0..<notesUnderBeam.count {
            let note = notesUnderBeam[i]
            if i == 0 {
                //note.beamType = .end
                note.stemLength = linesForFullStemLength
            }
            else {
                if i == notesUnderBeam.count-1 {
                    //note.beamType = .start
                    note.stemLength = linesForFullStemLength
                }
                else {
                    //note.beamType = .middle
                    let placement = staff.getNoteViewPlacement(note: note)
                    ///adjust the stem length according to where the note is positioned vs. where the beam slope position requires
                    let stemDiff = Double(placement.offsetFromStaffMidline) - requiredBeamPosition
                    note.stemLength = linesForFullStemLength + (stemDiff / 2.0 * (totalOffset > 0 ? 1.0 : -1.0))
                    if note.stemLength < minStemLength {
                        minStemLength = note.stemLength
                    }
                }
            }
            requiredBeamPosition += beamSlope
            note.stemDirection = totalOffset > 0 ? .down : .up
        }
        
        if minStemLength < 2 {
            let delta = 3 - minStemLength
            for i in 0..<notesUnderBeam.count {
                let note = notesUnderBeam[i]
                note.stemLength += delta
            }
        }
    }
    
    ///Determine whether quavers can be beamed within a bar's strong and weak beats
    ///StartBeam is the possible start of beam, lastBeat is the end of beam
    private func addStemCharaceteristics() {
        
        func setStem(timeSlice:TimeSlice, beamType:QuaverBeamType, linesForFullStemLength:Double) {
            for staffIndex in 0..<self.staffs.count {
                let stemDirection = getStemDirection(staff: self.staffs[staffIndex], notes: timeSlice.getTimeSliceNotes())
                let staffNotes = timeSlice.getTimeSliceNotes(staffNum: staffIndex)
                for note in staffNotes {
                    note.stemDirection = stemDirection
                    note.stemLength = linesForFullStemLength
                    note.beamType = beamType
                    ///Dont try yet to beam semiquavers
                }
            }
        }
        
        func saveBeam(timeSlicesUnderBeam:[TimeSlice], linesForFullStemLength:Double) -> [TimeSlice] {
            if timeSlicesUnderBeam.count == 0 {
                return []
            }
            for i in 0..<timeSlicesUnderBeam.count {
                if i == 0 {
                    if timeSlicesUnderBeam.count == 1 {
                        setStem(timeSlice: timeSlicesUnderBeam[i], beamType: .none, linesForFullStemLength: linesForFullStemLength)
                    }
                    else {
                        setStem(timeSlice: timeSlicesUnderBeam[i], beamType: .start, linesForFullStemLength: linesForFullStemLength)
                    }
                }
                else {
                    if i == timeSlicesUnderBeam.count - 1 {
                        setStem(timeSlice: timeSlicesUnderBeam[i], beamType: .end, linesForFullStemLength: linesForFullStemLength)
                    }
                    else {
                        setStem(timeSlice: timeSlicesUnderBeam[i], beamType: .middle, linesForFullStemLength: linesForFullStemLength)
                    }
                }
            }
            return []
        }
        
        enum InBeamState {
            case noBeam
            case beamStarted
        }

        var timeSlicesUnderBeam:[TimeSlice] = []
        let linesForFullStemLength = 3.5
        
        ///Make quaver beams onto the main beats
        
        for scoreEntry in self.scoreEntries {
            guard scoreEntry is TimeSlice else {
                timeSlicesUnderBeam = saveBeam(timeSlicesUnderBeam: timeSlicesUnderBeam, linesForFullStemLength: linesForFullStemLength)
                continue
            }
            let timeSlice = scoreEntry as! TimeSlice
            if timeSlice.getTimeSliceNotes().count == 0 {
                timeSlicesUnderBeam = saveBeam(timeSlicesUnderBeam: timeSlicesUnderBeam, linesForFullStemLength: linesForFullStemLength)
                continue
            }
            let note = timeSlice.getTimeSliceNotes()[0]
            if note.getValue() != Note.VALUE_QUAVER {
                setStem(timeSlice: timeSlice, beamType: .none, linesForFullStemLength: linesForFullStemLength)
                timeSlicesUnderBeam = saveBeam(timeSlicesUnderBeam: timeSlicesUnderBeam, linesForFullStemLength: linesForFullStemLength)
                continue
            }

            let mainBeat = Int(timeSlice.beatNumber)
            if timeSlice.beatNumber == Double(mainBeat) {
                timeSlicesUnderBeam = saveBeam(timeSlicesUnderBeam: timeSlicesUnderBeam, linesForFullStemLength: linesForFullStemLength)
                timeSlicesUnderBeam.append(timeSlice)
            }
            else {
                if timeSlicesUnderBeam.count > 0 {
                    timeSlicesUnderBeam.append(timeSlice)
                }
                else {
                    setStem(timeSlice: timeSlice, beamType: .none, linesForFullStemLength: linesForFullStemLength)
                }
            }
        }
        timeSlicesUnderBeam = saveBeam(timeSlicesUnderBeam: timeSlicesUnderBeam, linesForFullStemLength: linesForFullStemLength)
        
        ///Join up adjoining beams where possible. Existing beams only span one main beat and can be joined in some cases

        var lastNote:Note? = nil
        for scoreEntry in self.scoreEntries {
            guard let timeSlice = scoreEntry as? TimeSlice else {
                lastNote = nil
                continue
            }
            if timeSlice.getTimeSliceNotes().count == 0 {
                lastNote = nil
                continue
            }
            var note = timeSlice.getTimeSliceNotes()[0]
            if note.beamType == .none {
                lastNote = nil
                continue
            }
            if note.beamType == .start {
                if let lastNote = lastNote {
                    if lastNote.beamType == .end {
                        var timeSigAllowsJoin = true
                        if timeSignature.top == 4 {
                            /// 4/4 beats after 2nd cannot join to earlier beats
                            let beat = Int(note.timeSlice.beatNumber)
                            let startBeat = Int(lastNote.timeSlice.beatNumber)
                            timeSigAllowsJoin = beat < 2 || (startBeat >= 2)
                        }
                        if timeSigAllowsJoin {
                            lastNote.beamType = .middle
                            note.beamType = .middle
                        }
                    }
                }
            }
            lastNote = note
        }
        
        ///Determine stem directions for each quaver beam
        
        var notesUnderBeam:[Note] = []
        for scoreEntry in self.scoreEntries {
            guard let timeSlice = scoreEntry as? TimeSlice else {
                lastNote = nil
                continue
            }
            if timeSlice.getTimeSliceNotes().count == 0 {
                lastNote = nil
                continue
            }
            var note = timeSlice.getTimeSliceNotes()[0]
            if note.beamType != .none {
                notesUnderBeam.append(note)
                if note.beamType == .end {
                    let staff = self.staffs[note.staffNum]
                    determineStemDirections(staff:staff, notesUnderBeam: notesUnderBeam, linesForFullStemLength: linesForFullStemLength)
                    notesUnderBeam = []
                }
            }
        }
    }

    ///If the last note added was a quaver, identify any previous adjoining quavers and set them to be joined with a quaver bar
    ///Set the beginning, middle and end quavers for the beam
//    private func addStemCharaceteristicsOld() {
//        let lastNoteIndex = self.scoreEntries.count - 1
//        let scoreEntry = self.scoreEntries[lastNoteIndex]
//        guard scoreEntry is TimeSlice else {
//            return
//        }
//
//        let lastTimeSlice = scoreEntry as! TimeSlice
//        let notes = lastTimeSlice.getTimeSliceNotes()
//        if notes.count == 0 {
//            return
//        }
//
//        let lastNote = notes[0]
//        //lastNote.sequence1 = self.getAllTimeSlices().count
//
//        //The number of staff lines for a full stem length
//        let linesForFullStemLength = 3.5
//
//        if lastNote.getValue() != Note.VALUE_QUAVER {
//            for staffIndex in 0..<self.staffs.count {
//                let stemDirection = getStemDirection(staff: self.staffs[staffIndex], notes: notes)
//                let staffNotes = lastTimeSlice.getTimeSliceNotes(staffNum: staffIndex)
//                for note in staffNotes {
//                    note.stemDirection = stemDirection
//                    note.stemLength = linesForFullStemLength
//                    ///Dont try yet to beam semiquavers
//                    if lastNote.getValue() == Note.VALUE_SEMIQUAVER {
//                        note.beamType = .end
//                    }
//                }
//            }
//            return
//        }
//
//        let staff = self.staffs[lastNote.staffNum]
//        //apply the quaver beam back from the last note
//        var notesUnderBeam:[Note] = []
//        notesUnderBeam.append(lastNote)
//
//        ///Figure out the start, middle and end of this group of quavers
//        for i in stride(from: lastNoteIndex - 1, through: 0, by: -1) {
//            let scoreEntry = self.scoreEntries[i]
//            if !(scoreEntry is TimeSlice) {
//                break
//            }
//            let timeSlice = scoreEntry as! TimeSlice
//            if timeSlice.entries.count > 0 {
//                if timeSlice.entries[0] is Rest {
//                    break
//                }
//            }
//            let notes = timeSlice.getTimeSliceNotes()
//            if notes.count > 0 {
//                if notes[0].getValue() == Note.VALUE_QUAVER {
//                    if !canBeBeamedTo(timeSignature: self.timeSignature, startBeamTimeSlice: timeSlice, lastBeat: lastTimeSlice.beatNumber) {
//                        break
//                    }
//                    let note = notes[0]
//                    notesUnderBeam.append(note)
//                }
//                else {
//                    break
//                }
//            }
//        }
//
//        ///Check if beam is valid
//        var totalValueUnderBeam = 0.0
//        var valid = true
//
//        for note in notesUnderBeam {
////            if note.beamType == .start {
////                if note.timeSlice?.beatNumber.truncatingRemainder(dividingBy: 1.0) != 0 {
////                    valid = false
////                    break
////                }
////            }
//            totalValueUnderBeam += note.getValue()
//        }
//        
//        if valid {
//            valid = totalValueUnderBeam.truncatingRemainder(dividingBy: 1) == 0
//        }
//            
//        ///Its not valid so unbeam
//        if !valid {
//            ///Discard the beam group because cant beam to an off-beat note
//            notesUnderBeam = []
//            notesUnderBeam.append(lastNote)
//        }
//        
//        ///Determine if the quaver group has up or down stems based on the overall staff placement of the group
//        var totalOffset = 0
//        for note in notesUnderBeam {
//            let placement = staff.getNoteViewPlacement(note: note)
//            totalOffset += placement.offsetFromStaffMidline
//        }
//        
//        ///Set each note's beam type and calculate the nett above r below the staff line for the quaver group (for the subsequnet stem up or down decison)
//        let startNote = notesUnderBeam[0]
//        let startPlacement = staff.getNoteViewPlacement(note: startNote)
//
//        let endNote = notesUnderBeam[notesUnderBeam.count - 1]
//        let endPlacement = staff.getNoteViewPlacement(note: endNote)
//
//        var beamSlope:Double = Double(endPlacement.offsetFromStaffMidline - startPlacement.offsetFromStaffMidline)
//        beamSlope = beamSlope / Double(notesUnderBeam.count - 1)
//
//        var requiredBeamPosition = Double(startPlacement.offsetFromStaffMidline)
//        var minStemLength = linesForFullStemLength
//        
//        for i in 0..<notesUnderBeam.count {
//            let note = notesUnderBeam[i]
//            if i == 0 {
//                note.beamType = .end
//                note.stemLength = linesForFullStemLength
//            }
//            else {
//                if i == notesUnderBeam.count-1 {
//                    note.beamType = .start
//                    note.stemLength = linesForFullStemLength
//                }
//                else {
//                    note.beamType = .middle
//                    let placement = staff.getNoteViewPlacement(note: note)
//                    ///adjust the stem length according to where the note is positioned vs. where the beam slope position requires
//                    let stemDiff = Double(placement.offsetFromStaffMidline) - requiredBeamPosition
//                    note.stemLength = linesForFullStemLength + (stemDiff / 2.0 * (totalOffset > 0 ? 1.0 : -1.0))
//                    if note.stemLength < minStemLength {
//                        minStemLength = note.stemLength
//                    }
//                }
//            }
//            requiredBeamPosition += beamSlope
//            note.stemDirection = totalOffset > 0 ? .down : .up
//        }
//        
//        if minStemLength < 2 {
//            let delta = 3 - minStemLength
//            for i in 0..<notesUnderBeam.count {
//                let note = notesUnderBeam[i]
//                note.stemLength += delta
//            }
//        }
//        
//        ///Check no stranded beam starts. A note with beamStart without a beamEnd. Every beam start must have a beam end so it is rendered correctly.
//        ///Quavers under beams only have their stems rendered by the presence of an end note in their beam group
//        func getFirstNoteInTS(_ tsIndex:Int) -> Note? {
//            if tsIndex < self.getAllTimeSlices().count {
//                let ts = getAllTimeSlices()[tsIndex]
//                if ts.getTimeSliceNotes().count > 0 {
//                    return ts.getTimeSliceNotes()[0]
//                }
//            }
//            return nil
//        }
//
//        for i in 0..<getAllTimeSlices().count {
//            let note = getFirstNoteInTS(i)
//            if let note = note {
//                if note.beamType == .start {
//                    let nextNote = getFirstNoteInTS(i+1)
//                    if let nextNote = nextNote {
//                        if !([QuaverBeamType.end, QuaverBeamType.middle].contains(nextNote.beamType)) {
//                            note.beamType = .end
//                            ///Undo any stem direction that might have been previousy applied
//                            note.stemDirection = getStemDirection(staff: staff, notes: [note])
//                            note.stemLength = linesForFullStemLength
//                            break
//                        }
//                    }
//                }
//            }
//        }
//        debugScore44("end of beaming, scoreSize:\(lastNoteIndex+1)", withBeam: true)
//    }
    
    public func copyEntries(from:Score, count:Int? = nil) {
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
    
    public func errorCount() -> Int {
        var cnt = 0
        for timeSlice in self.getAllTimeSlices() {
            //let entries = timeSlice.getTimeSliceEntries()
            //if entries.count > 0 {
            if [StatusTag.pitchError, StatusTag.rhythmError].contains(timeSlice.statusTag) {
                    cnt += 1
                }
            //}
        }
        return cnt
    }
    
    public func isNextTimeSliceANote(fromScoreEntryIndex:Int) -> Bool {
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
    
    public func clearAllStatus() {
        for ts in self.getAllTimeSlices() {
            ts.setStatusTag(.noTag)
        }
    }
    ///Return a score based on the question score but modified to show where a tapped duration differs from the question
    public func fitScoreToQuestionScore(userScore:Score, onlyRhythm:Bool, tolerancePercent:Double) -> (Score, StudentFeedback) {
        let linesInStaff = onlyRhythm ? 1 : 5
        let outputScore = Score(key: self.key, timeSignature: self.timeSignature, linesPerStaff: linesInStaff)
        let staff = Staff(score: outputScore, type: .treble, staffNum: 0, linesInStaff: linesInStaff)
        outputScore.createStaff(num: 0, staff: staff)
            
        ///Stop analysis after a rhythm error (but not a pitch error)
        var stopAnalysis = false

        //userScore.debugScorexx("User at start FIT", withBeam: false)
        var tapIndex = 0
        var explanation = ""
        let noteType = onlyRhythm ? "tap" : "note"

        for questionIndex in 0..<self.scoreEntries.count {
            guard let questionTimeSlice:TimeSlice = self.scoreEntries[questionIndex] as? TimeSlice else {
                outputScore.addBarLine()
                continue
            }
            if questionTimeSlice.entries.count == 0 {
                continue
            }
            
            guard let questionNote = questionTimeSlice.entries[0] as? Note else {
                if !stopAnalysis {
                    let outputTimeSlice = outputScore.createTimeSlice()
                    outputTimeSlice.addRest(rest: Rest(timeSlice: outputTimeSlice, value: questionTimeSlice.getValue(), staffNum: 0))
                }
                continue
            }
            
            let trailingRestsDuration = self.getTrailingRestsDuration(index: questionIndex + 1)
            let questionNoteValue = questionNote.getValue() + trailingRestsDuration
            var outputNoteValue = questionNote.getValue()
            var outputMidiValue = questionNote.midiNumber
            if tapIndex < userScore.getAllTimeSlices().count {
                ///Make the midi the pitch played on the virtual keyboard
                if userScore.getAllTimeSlices()[tapIndex].getTimeSliceNotes().count > 0 {
                    outputMidiValue = userScore.getAllTimeSlices()[tapIndex].getTimeSliceNotes()[0].midiNumber
                }
            }

            if stopAnalysis {
                //outputTimeSlice.statusTag = .afterError
                ///Dont break yet.  Add empty timeslices to the output score so that it still lines up vertically with the question score
                //break
                ///Changed 21Dec2023 to include now in the output any remaining rhythm the student tapped.
                ///Rationale was for studnet to be able to hear their full rhythm regardless of any mistakes made
                if true {
                    if tapIndex < userScore.getAllTimeSlices().count {
                        for t in tapIndex..<userScore.getAllTimeSlices().count {
                            let outputTimeSlice = outputScore.createTimeSlice()
                            let ts = userScore.getAllTimeSlices()[t]
                            let note = Note(timeSlice: outputTimeSlice, num: ts.getTimeSliceNotes()[0].midiNumber, value: ts.getValue(), staffNum: 0)
                            note.isOnlyRhythmNote = questionNote.isOnlyRhythmNote
                            outputTimeSlice.statusTag = .afterError
                            outputTimeSlice.addNote(n: note)
                            
                        }
                    }
                    break
                }
            }
            else {
                let outputTimeSlice = outputScore.createTimeSlice()
                if tapIndex >= userScore.getAllTimeSlices().count {
                    stopAnalysis = true
                    explanation = "• There was no \(noteType) here"
                    outputTimeSlice.statusTag = .rhythmError
                }
                else {
                    let tap = userScore.getAllTimeSlices()[tapIndex]
                    let delta = questionNoteValue * tolerancePercent * 0.01
                    let lowBound = questionNoteValue - delta
                    let hiBound = questionNoteValue + delta
//                    if tapIndex == userScore.getAllTimeSlices().count - 1 {
//                        tap.tapSecondsNormalizedToTempo = questionNoteValue
//                    }
                    if tap.tapSecondsNormalizedToTempo < lowBound || tap.tapSecondsNormalizedToTempo > hiBound {
                        outputTimeSlice.statusTag = .rhythmError
                        questionTimeSlice.statusTag = .hilightAsCorrect
                        outputNoteValue = tap.getValue()
                        stopAnalysis = true
                        let name = TimeSliceEntry.getValueName(value:questionNote.getValue())
                        //let tapName = TimeSliceEntry.getValueName(value:tap.getValue())
                        explanation = "• The question note is a \(name)"
                        if trailingRestsDuration > 0 {
                            explanation += " followed by a rest"
                        }
                        else {
                            explanation += ""
                        }
                        if !UIGlobalsCommon.isLandscape() {
                            explanation += "\n• "
                        }
                        else {
                            explanation += " - "
                        }
                        explanation += "Your \(noteType) was too "
                        if questionNoteValue > tap.getValue() {
                            explanation += "short 🫢"
                        }
                        else {
                            explanation += "long 🫢"
                        }
                    }
                    else {
                        if !onlyRhythm {
                            if tap.getTimeSliceNotes().count > 0 {
                                let tappedNote = tap.getTimeSliceNotes()[0]
                                if tappedNote.midiNumber != questionNote.midiNumber {
                                    explanation = "Wrong note"
                                    outputTimeSlice.statusTag = .pitchError
                                    questionTimeSlice.statusTag = .hilightAsCorrect
                                    outputNoteValue = tap.getValue()
                                    outputMidiValue = tappedNote.midiNumber
                                }
                            }
                        }
                    }
                }
                let outputNote = Note(timeSlice: outputTimeSlice, num: outputMidiValue, value: outputNoteValue, staffNum: questionNote.staffNum)
                outputNote.setIsOnlyRhythm(way: questionNote.isOnlyRhythmNote)
                outputTimeSlice.addNote(n: outputNote)
                tapIndex += 1
            }
        }

        let feedback = StudentFeedback()
        feedback.feedbackExplanation = explanation

        //outputScore.debugScorexx("Output Fit", withBeam: false)
        return (outputScore, feedback)
    }

    public func getTrailingRestsDuration(index:Int) -> Double {
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
    
    public func getEndRestsDuration() -> Double {
        var totalDuration = 0.0
        for e in self.getAllTimeSlices().reversed() {
            if e.getTimeSliceEntries().count > 0 {
                let entry = e.getTimeSliceEntries()[0]
                if entry is Note {
                    break
                }
                totalDuration += entry.getValue()
            }
        }
        return totalDuration
    }

    func clearTags() {
        for ts in getAllTimeSlices() {
            ts.setStatusTag(.noTag)
        }
    }
    
    func getNotesForLastBar(pitch:Int? = nil) -> [Note] {
        var notes:[Note] = []
        for entry in self.scoreEntries.reversed() {
            if entry is BarLine {
                break
            }
            if let ts = entry as? TimeSlice {
                if ts.getTimeSliceNotes().count > 0 {
                    if let note = ts.entries[0] as? Note {
                        if let pitch = pitch {
                            if note.midiNumber == pitch {
                                notes.append(note)
                            }
                        }
                        else {
                            notes.append(note)
                        }
                    }
                }
            }
        }
        return notes
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


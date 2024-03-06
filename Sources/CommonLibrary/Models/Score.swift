import Foundation
import AVKit
import AVFoundation

public class RhythmTolerance {
    static func getTolerancePercent(_ setting:Int) -> Double {
//        switch setting {
//        case 0:
//            return 38.0
//            //return 30.0
//        case 1:
//            return 47.0
//        case 2:
//            return 56.0
//        default:
//            return 65.0
//        }        switch setting {
        switch setting {
            case 0:
                return 34.0
            case 1:
                return 43.0
            case 2:
                return 55.0
            default:
                return 65.0
            }
    }
    
    static public func getToleranceName(_ setting:Int) -> String {
        switch setting {
        case 0:
            return "Hardest"
        case 1:
            return "Hard"
        case 2:
            return "Moderate"
        case 3:
            return "Easy"
        default:
            return "Unknown"
        }
    }
}

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
    @Published public var showTempos:Bool? = nil //nil=>dont show on/off UI, false=>show regular notes, on=>show tempo colored notes

    let ledgerLineCount =  2 //3//4 is required to represent low E
    public var staffs:[Staff] = []
    
    public var studentFeedback:StudentFeedback? = nil
    public var tempo:Int?
    
    //public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 10.0 : 8.0
    //public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 10.0 : 15.0
    public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 8.0 : 15.0
    //public var lineSpacing = UIDevice.current.userInterfaceIdiom == .phone ? 8.0 : 10.0

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
                let notes = key.getTriadNoteNames(triadSymbol:triad)
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

    public func debugScore5(_ ctx:String, withBeam:Bool, toleranceLevel:Int) {
        let tolerance = RhythmTolerance.getTolerancePercent(toleranceLevel)
        print("\nSCORE DEBUG =====", ctx, "\tKey", key.keySig.accidentalCount, 
              //"StaffCount", self.staffs.count,
                "toleranceLevel:\(toleranceLevel)",
                "toleranceLevel:\(tolerance)"
        )
        for t in self.getAllTimeSlices() {
            if t.entries.count == 0 {
                print("ZERO ENTRIES")
                continue
            }
            if t.getTimeSliceNotes().count > 0 {
                let note = t.getTimeSliceNotes()[0]
                    if withBeam {
                        print("  Seq", t.sequence, 
                              "type:", type(of: t.entries[0]),
                              "midi:", note.midiNumber,
                              "beat:", t.beatNumber,
                              "Value:", t.getValue() ,
                              "stemDirection", note.stemDirection,
                              "stemLength", note.stemLength,
                              "writtenAccidental", note.writtenAccidental ?? 0,
                              "\t[beamType:", note.beamType,"]",
                              "beamEndNoteSeq:", note.beamEndNote?.timeSlice.sequence ?? "_",
                              "]")
                    }
                    else {
                        print("  Seq", t.sequence,
                              "[type:", type(of: t.entries[0]), "]",
                              "[midi:",note.midiNumber, "]",
                              "[TapDuration Seconds:",String(format: "%.4f", t.tapSecondsNormalizedToTempo ?? 0),"]",
                              "[Note Value:", note.getValue(),"]",
                              "[status]",t.statusTag,
                              "[beat]",t.beatNumber,
                              "[writtenAccidental:",note.writtenAccidental ?? "","]",
                              "[Staff:",note.staffNum,"]"
                        )
                    }
            }
            else {
                //let rest = t.
                print("  Seq", t.sequence,
                      "[type:", type(of: t.entries[0]), "]",
                      "[rest:","R ", "]",
                      "[TapDuration Seconds:",String(format: "%.4f", t.tapSecondsNormalizedToTempo ?? 0),"]",
                      "[Note Value:", t.getValue(),"]",
                      "[status]",t.statusTag,
                      "[beat]",t.beatNumber,
                      "[writtenAccidental:","_","]",
                      "[Staff:","_","]"
                    )
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
    
    public func setShowTempos(way:Bool) {
        DispatchQueue.main.async {
            self.showTempos = way
            if way {
                self.calculateTapToValueRatios()
            }
            else {
                self.resetTapToValueRatios()
            }
        }
    }

    public func setStudentFeedback(studentFeedack:StudentFeedback? = nil) {
        //DispatchQueue.main.async {
            self.studentFeedback = studentFeedack
        //}
    }

//    public func getLastTimeSlice1() -> TimeSlice? {
//        var ts:TimeSlice?
//        for index in stride(from: scoreEntries.count - 1, through: 0, by: -1) {
//            let element = scoreEntries[index]
//            if element is TimeSlice {
//                ts = element as? TimeSlice
//                break
//            }
//        }
//        return ts
//    }    
    
    public func getLastNoteTimeSlice() -> TimeSlice? {
        var result:TimeSlice?
        for index in stride(from: scoreEntries.count - 1, through: 0, by: -1) {
            let entry = scoreEntries[index]
            if let ts = entry as? TimeSlice {
                if ts.getTimeSliceNotes().count > 0 {
                    result = ts
                    break
                }
            }
        }
        return result
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
        guard let timeSlice = self.getLastNoteTimeSlice() else {
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
            let note = timeSlice.getTimeSliceNotes()[0]
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
            let note = timeSlice.getTimeSliceNotes()[0]
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
            if [StatusTag.pitchError, StatusTag.rhythmError].contains(timeSlice.statusTag) {
                cnt += 1
            }
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
            ts.setStatusTag("clearAllStatus", .noTag)
        }
    }
    
    ///Return a score based on the question score but modified to show where a tapped duration differs from the question
    //public func fitScoreToQuestionScore(userScore:Score, onlyRhythm:Bool, tolerancePercent:Double) -> (Score, StudentFeedback) {
    public func fitScoreToQuestionScore(userScore:Score, onlyRhythm:Bool, toleranceSetting:Int) -> (Score, StudentFeedback) {
        let linesInStaff = onlyRhythm ? 1 : 5
        let outputScore = Score(key: self.key, timeSignature: self.timeSignature, linesPerStaff: linesInStaff)
        let staff = Staff(score: outputScore, type: .treble, staffNum: 0, linesInStaff: linesInStaff)
        outputScore.createStaff(num: 0, staff: staff)
        //userScore.debugScore3("Input Fit", withBeam: false)
        
        ///Stop analysis after a rhythm error (but not a pitch error)
        var userRhythmErrorIndex:Int? = nil
        //var userPitchErrorIndex:Int? = nil

//        self.debugScore4     ("Ques score at start FIT", withBeam: false, toleranceLevel: toleranceSetting)
//        userScore.debugScore4("User score at start FIT", withBeam: false, toleranceLevel: toleranceSetting)
        var tapIndex = 0
        var explanation = ""
        let tapType = onlyRhythm ? "tap" : "note"
        
        var questionPosition = 0
        for questionIndex in 0..<self.scoreEntries.count {
            questionPosition = questionIndex
            guard let questionTimeSlice:TimeSlice = self.scoreEntries[questionIndex] as? TimeSlice else {
                if userRhythmErrorIndex == nil {
                    outputScore.addBarLine()
                }
                continue
            }
            if questionTimeSlice.entries.count == 0 {
                continue
            }
            
            guard let questionNote = questionTimeSlice.entries[0] as? Note else {
                if userRhythmErrorIndex == nil {
                    let outputTimeSlice = outputScore.createTimeSlice()
                    outputTimeSlice.addRest(rest: Rest(timeSlice: outputTimeSlice, value: questionTimeSlice.getValue(), staffNum: 0))
                }
                continue
            }
//            print("===========ANAL00Start questionIndex:", questionIndex, "questValue", questionNote.getValue(),
//                  "userCount:", userScore.getAllTimeSlices().count, "tapIndex:", tapIndex)

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
            
            let outputTimeSlice = outputScore.createTimeSlice()

            if tapIndex >= userScore.getAllTimeSlices().count {
                ///Set the error index beyond the user score length
                userRhythmErrorIndex = tapIndex
                outputTimeSlice.statusTag = .rhythmError
            }
            else {
                let tap = userScore.getAllTimeSlices()[tapIndex]
                let tolerancePercent = RhythmTolerance.getTolerancePercent(toleranceSetting)
                //let delta = questionNoteValue * tolerancePercent * 0.01
                //let delta = 1.0 * tolerancePercent * 0.01
                ///Use the tolerance relative to a short note's value. For longer notes (minim, smibrive) limit the tolerance if above 1.0
                let delta = min(1.0, questionNoteValue) * tolerancePercent * 0.01

                let lowBound = questionNoteValue - delta
                let hiBound = questionNoteValue + delta
                if tap.tapSecondsNormalizedToTempo == nil {
                    break
                }
                if tap.tapSecondsNormalizedToTempo! < lowBound || tap.tapSecondsNormalizedToTempo! > hiBound {
                    outputTimeSlice.statusTag = .rhythmError
                    questionTimeSlice.setStatusTag("fitScore", StatusTag.hilightAsCorrect)
                    outputNoteValue = tap.getValue()
                    userRhythmErrorIndex = tapIndex
                    let name = TimeSliceEntry.getValueName(value:questionNote.getValue())
                    if tapIndex <= 1 {
                        explanation = "• You had a false start"
                    }
                    else {
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
                        explanation += "Your \(tapType) was too "
                        if questionNoteValue > tap.getValue() {
                            explanation += "short"
                        }
                        else {
                            explanation += "long"
                        }
                    }
                }
                else {
                    if !onlyRhythm {
                        if tap.getTimeSliceNotes().count > 0 {
                            let tappedNote = tap.getTimeSliceNotes()[0]
                            if tappedNote.midiNumber != questionNote.midiNumber {
                                explanation = "Wrong note"
                                outputTimeSlice.statusTag = .pitchError
                                questionTimeSlice.setStatusTag("fitScore", StatusTag.hilightAsCorrect)
                                outputNoteValue = tap.getValue()
                                outputMidiValue = tappedNote.midiNumber
                                //userPitchErrorIndex = tapIndex
                            }
                        }
                    }
                }
            }
            let outputNote = Note(timeSlice: outputTimeSlice, num: outputMidiValue, value: outputNoteValue, staffNum: questionNote.staffNum)
            if tapIndex < userScore.getAllTimeSlices().count {
                let tap = userScore.getAllTimeSlices()[tapIndex] //DPM
                outputNote.timeSlice.tapSecondsNormalizedToTempo = tap.tapSecondsNormalizedToTempo //DPM
            }
            outputNote.setIsOnlyRhythm(way: questionNote.isOnlyRhythmNote)
            outputTimeSlice.addNote(n: outputNote)
            if userRhythmErrorIndex != nil {
                break
            }
            else {
                tapIndex += 1
            }
        }
        
        let tapVerb = onlyRhythm ? "tap" : "play"
        var tapsAfterEnd = false
        ///Check if error was flagged on the last tap. It can be casued by multiple reasons that should be described individually.
        if let lastOutput = outputScore.getLastNoteTimeSlice() {
//            print("===========ANAL RHYTHM ERROR", "questCount:", self.scoreEntries.count , "questPosition:" , questionPosition,
//                  "userCount:", userScore.getAllTimeSlices().count, "tapIndex:", tapIndex, "errIndex:", userRhythmErrorIndex)
            if let userRhythmErrorIndex = userRhythmErrorIndex {
                if userRhythmErrorIndex == (userScore.getAllTimeSlices().count) {
                    ///The error index is beyond the end of the student taps.
                    ///The user stopped tapping before the question end but the rhythm was correct up until then.
                    explanation = "• There was no \(tapType) here"
                }
                else {
                    ///The error index is within the student taps.
                    if questionPosition < self.scoreEntries.count - 1 {
                        ///The student made less taps than question taps.
                        if tapIndex == userScore.getAllTimeSlices().count -  1 {
                            ///The tap duration was wrong (short or long) on their last tap and
                            ///the duration of that last tap was measured by the end of tap recording, not a subsequent tap
                            let trailingRestsValue = getTrailingRestsDuration(index: questionPosition + 1)
                            if trailingRestsValue == 0 {
                                explanation += ", you didn't \(tapVerb) all the \(tapType)s"
                            }
                        }
                        else {
                            ///Student made a mistake on a tap other than their last tap so no need to further modify the existing explanation
                        }
                    }
                    else {
                        ///Student got to the end of the question but there was a rhythm error on their last tap
                        let lastTap = userScore.getAllTimeSlices()[tapIndex]
                        let lastQuestion = getAllTimeSlices()[getAllTimeSlices().count-1]
                        if tapIndex < userScore.getAllTimeSlices().count -  1 {
                            explanation += ", there were extra \(tapType)s at the end"
                            tapsAfterEnd = true
                            //tapIndex += 1
                        }
                        else {
//                            if lastTap.tapSecondsNormalizedToTempo! > lastQuestion.getValue() {
//                                explanation += ", you waited too long to end"
//                            }
//                            else {
//                                explanation += ", you ended too quickly"
//                            }
                        }
                    }
                }
            }
            else {
                ///All student taps were correct and the student tap for the last question tap was correct but its duration was set by a subsequent tap (rather than ending the recording)
                if tapIndex < userScore.getAllTimeSlices().count  {
                    explanation = "• Correct but there were extra \(tapType)s at the end"
                    tapsAfterEnd = true
                    tapIndex -= 1
                }

            }
            if explanation.count > 0 {
                explanation += " 🫢"
            }
        }
        
        ///Ensure the student hears all their taps even when there are errors
        ///Tap index (zero based) is at the note that was in error and that error was larady written to the output score
        if userScore.getAllTimeSlices().count > 0 {
            if tapIndex+1 < userScore.getAllTimeSlices().count  {
//                print("===========ANAL FILL NOTES", "questCount:", self.scoreEntries.count , "questPosition:" , questionPosition,
//                      "tapIndex:", tapIndex, "userCount:", userScore.getAllTimeSlices().count, "errIndex:", userRhythmErrorIndex)

                for t in tapIndex+1..<userScore.getAllTimeSlices().count {
                    let outputTimeSlice = outputScore.createTimeSlice()
                    let ts = userScore.getAllTimeSlices()[t]
                    let note = Note(timeSlice: outputTimeSlice, num: ts.getTimeSliceNotes()[0].midiNumber, value: ts.getValue(), staffNum: 0)
                    note.isOnlyRhythmNote = onlyRhythm
                    if tapsAfterEnd {
                        outputTimeSlice.statusTag = .rhythmError
                    }
                    else {
                        ///Dont show the notes on the stave since we want to retain the veritical alignment of where the rhythm error was made.
                        ///But record the notes in the output so that the audio playback includes them.
                        outputTimeSlice.statusTag = onlyRhythm ? .afterErrorInvisible : .afterErrorVisible
                    }
                    outputTimeSlice.addNote(n: note)
                }
            }
        }
        let feedback = StudentFeedback()
        feedback.feedbackExplanation = explanation

        //outputScore.debugScore33("Output Fit 11111", withBeam: false)
        return (outputScore, feedback)
    }
    
    public func resetTapToValueRatios() {
        for i in 0..<self.scoreEntries.count {
            if let ts = self.scoreEntries[i] as? TimeSlice {
                ts.tapTempoRatio = nil
            }
        }
    }
        
    public func calculateTapToValueRatios() {
        ///Calculate tapped time to note value with any trailing rests
        ///The tapped value for a note must be compared against the note's value plus and traling rests
        var lastValue:Double = 0
        var lastNoteIndex:Int?
        
        func set(index:Int, lastValue:Double) {
            if let ts:TimeSlice = self.scoreEntries[index] as? TimeSlice {
                if let tapped = ts.tapSecondsNormalizedToTempo {
                    if lastValue > 0 {
                        let ratio = tapped / lastValue
                        ts.tapTempoRatio = ratio
                    }
                }
            }
        }
        
        for i in 0..<self.scoreEntries.count {
            if let ts = self.scoreEntries[i] as? TimeSlice {
                if ts.entries.count > 0 {
                    if let note = ts.entries[0] as? Note {
                        if let index = lastNoteIndex {
                            set(index: index, lastValue: lastValue)
                            lastValue = 0
                        }
                        lastValue += ts.getValue()
                        lastNoteIndex = i
                    }
                    if let note = ts.entries[0] as? Rest {
                        lastValue += ts.getValue()
                    }
                }
            }
        }
        if let index = lastNoteIndex {
            set(index: index, lastValue: lastValue)
        }
        
        ///calculate the min, max ratios
        var minRatio:Double?
        var maxRatio:Double?
        ///exclude the last tap which is often long and then skews the result
        for i in 0..<self.scoreEntries.count-1 {
            if let ts = self.scoreEntries[i] as? TimeSlice {
                if let ratio = ts.tapTempoRatio {
                    if minRatio == nil || ratio < minRatio! {
                        minRatio = ratio
                    }
                    if maxRatio == nil || ratio > maxRatio! {
                        maxRatio = ratio
                    }
                }
            }
        }
        guard let maxRatio = maxRatio else {
            return
        }
        guard let minRatio = minRatio else {
            return
        }

        ///Scale all the ratios according to the min, max. Fill the space 0..1 so that the slowest ratio is 0 an dthe highest ratio is 1
        for i in 0..<self.scoreEntries.count {
            if let ts = self.self.scoreEntries[i] as? TimeSlice {
                if let ratio = ts.tapTempoRatio {
                    let scaled = (ratio - minRatio) / (maxRatio - minRatio)
                    //print("====== ADJUST", ts.sequence, "\tratio", ratio, "scaled", scaled)
                    ts.tapTempoRatio = scaled
                }
            }
        }
    }
    
    public func isOnlyRhythm() -> Bool {
        if let last = self.getLastNoteTimeSlice() {
            if last.getTimeSliceNotes().count > 0 {
                if last.getTimeSliceNotes().count > 0 {
                    let lastNote = last.getTimeSliceNotes()[0]
                    return lastNote.isOnlyRhythmNote
                }
            }
        }
        return false
    }
    
    public func getTrailingRestsDuration(index:Int) -> Double {
        var totalDuration = 0.0
        if index < self.scoreEntries.count {
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
            ts.setStatusTag("clearTags", StatusTag.noTag)
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


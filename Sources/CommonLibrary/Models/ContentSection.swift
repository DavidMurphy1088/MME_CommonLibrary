import Foundation
import AVFoundation
import Combine

public enum ExamStatus {
    case notInExam
    case inExam
    case inExamReview
}

public class QuestionStatus: Codable, ObservableObject {
    //@Published
    public var status:Int = 0
    init(_ i:Int) {
        self.status = i
    }
    public func setStatus(_ i:Int) {
        DispatchQueue.main.async {
            self.status = i
        }
    }
}

public class ContentSectionData: Codable {
    public var type:String
    public var data:[String]
    public var row:Int
    public init(row:Int, type:String, data:[String]) {
        self.row = row
        self.type = type
        self.data = data
    }
}

public class ContentSection: ObservableObject, Identifiable { //Codable,
    @Published public var selectedIndex:Int? //The row to go into
    @Published public var postitionToIndex:Int? //The row to postion to
    
    //Publish changes when a stored answer is set after an example is submitted so the list of examples updates
    @Published public var storedAnswer:Answer?

    public var id = UUID()
    public var parent:ContentSection?
    public var name: String
    public var type:String
    public let contentSectionData:ContentSectionData
    public var subSections:[ContentSection] = []
    public var isActive:Bool
    public var level:Int
    public var questionStatus = QuestionStatus(0)
    public var homeworkIsAssigned:Bool = false
    
    public init(parent:ContentSection?, name:String, type:String, data:ContentSectionData? = nil, isActive:Bool = true) {
        self.parent = parent
        self.name = name
        self.isActive = isActive
        self.type = type

        if data == nil {
            self.contentSectionData = ContentSectionData(row: 0, type: "", data: [])
        }
        else {
            self.contentSectionData = data!
        }
        var par = parent
        var level = 0
        var path = name
        while par != nil {
            level += 1
            path = par!.name+"."+path
            par = par!.parent
        }
        self.level = level
        setHomeworkStatus()
    }
    
    public func setHomeworkStatus()  {
        //TODO if !UIGlobals.companionAppActive {
            self.homeworkIsAssigned = false
            return
        //}
        let path = self.getPathAsArray()
        if path.count == 0 {
            return
        }
        let leafs = path[path.count-1].split(separator: " ")
        if leafs.count < 2 {
            return
        }
        if leafs[0] != "Example" {
            return
        }
        guard let exNum = Int(leafs[1]) else {
            return
        }
        if exNum > 7 {
            return
        }
        self.homeworkIsAssigned = true
    }
    
    public func setStoredAnswer(answer:Answer, ctx:String) {
        DispatchQueue.main.async {
            self.storedAnswer = answer
        }
    }
    
    public func setSelected(_ i:Int) {
        DispatchQueue.main.async {
            ///Force the selected Index to trigger a change event
            self.selectedIndex = nil
            DispatchQueue.global(qos: .background).async {
                sleep(1)
                DispatchQueue.main.async {
                    self.postitionToIndex = i
                    DispatchQueue.global(qos: .background).async {
                        sleep(1)
                        DispatchQueue.main.async {
                            self.selectedIndex = i
                        }
                    }
                }
            }
        }
    }
    
    public func getGrade() -> Int {
        var grade:Int = 1
        let paths = getPathAsArray()
        for path in paths {
            if path.starts(with: "Grade ") {
                let p = path.split(separator: " ")
                if p.count == 2 {
                    if let gradeInt = Int(p[1]) {
                        grade = gradeInt
                        break
                    }
                }
            }
        }
        return grade
    }

    public func saveAnswerToFile(answer: Answer) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(answer)
            let jsonString = String(data: jsonData, encoding: .utf8)
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let documentsURL = documentsURL {
                let fileName = self.getPath() + ".txt"
                let fileURL = documentsURL.appendingPathComponent(fileName)
                let content = jsonString // "This is an example."
                if let content = content {
                    let data = content.data(using: .utf8)
                    try data?.write(to: fileURL, options: .atomic)
                }
            } else {
                Logger.logger.reportError(self, "Failed answer save, no document URL")
            }
        } catch {
            Logger.logger.reportError(self, "Failed answer save \(error)")
        }
    }
    
    func loadAnswerFromFile() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let decoder = JSONDecoder()
        if let documentsURL = documentsURL {
            let fileName = self.getPath() + ".txt"
            let fileURL = documentsURL.appendingPathComponent(fileName)
            do {
                let data = try Data(contentsOf: fileURL)
                let answer = try decoder.decode(Answer.self, from: data)
                self.setStoredAnswer(answer: answer, ctx: "From file")
            }
            catch {
                //Logger.logger.reportError(self, "Failed to parse JSON \(error)")
            }
        }
        else {
            Logger.logger.reportError(self, "Failed answer read, no document URL")
        }
    }
    
    public func isExamTypeContentSection() -> Bool {
        if type == "Exam" {
            return true
        }
        return false
    }

    public func hasExamModeChildren() -> Bool {
        for s in self.subSections {
            if s.isExamTypeContentSection() {
                return true
            }
        }
        return false
    }

    ///Recursivly search all children with a true test supplied by the caller
    public func deepSearch(testCondition:(_ section:ContentSection)->Bool) -> Bool {
        if testCondition(self) {
            return true
        }
        for section in self.subSections {
            if testCondition(section) {
                return true
            }
            if section.deepSearch(testCondition: testCondition) {
                return true
            }
        }
        return false
    }
    
    ///Search all parents with a true test supplied by the caller
    public func parentSearch(testCondition:(_ section:ContentSection)->Bool) -> Bool {
        if testCondition(self) {
            return true
        }
        if let parent = self.parent  {
            if testCondition(parent) {
                return true
            }
            if parent.parentSearch(testCondition: testCondition) {
                return true
            }
        }
        return false
    }
    
    ///Recursivly search all children with a true test supplied by the caller
    public func contentSearch(testCondition:(_ section:ContentSection)->Bool) -> [ContentSection] {
        var result:[ContentSection] = []
        if testCondition(self) {
            result.append(self)
        }
        for section in self.subSections {
            let childs = section.contentSearch(testCondition: testCondition)
            if !childs.isEmpty {
                for c in childs {
                    result.append(c)
                }
            }
        }
        return result
    }

    
    public func debug() {
        let spacer = String(repeating: " ", count: 4 * (level))
        print(spacer, "--->", "path:[\(self.getPath())]", "\tname:", self.name, "\ttype:[\(self.type)]")
        let sorted:[ContentSection] = subSections.sorted { (c1, c2) -> Bool in
            //return c1.loadedRow < c2.loadedRow
            return c1.name < c2.name
        }
        for s in self.subSections {
            s.debug()
        }
    }
    
    public func isQuestionType() -> Bool {
        if type.first == "_" {
            return false
        }
        let components = self.type.split(separator: "_")
        if components.count != 2 {
            return false
        }
        if let n = Int(components[1]) {
            return n >= 0 && n <= 5
        }
        else {
            return false
        }
    }
    
    public func getQuestionCount() -> Int {
        var c = 0
        for section in self.subSections {
            if section.isQuestionType() {
                c += 1
            }
        }
        return c
    }
    
    public func getNavigableChildSections() -> [ContentSection] {
        var navSections:[ContentSection] = []
        for section in self.subSections {
            if section.deepSearch(testCondition: {
                section in
                return !(["Ins", "T&T"].contains(section.type))
                //return section.isQuestionType()
            }
            )
            {
                navSections.append(section)
            }
        }
        return navSections
    }
        
    public func getTitle() -> String {
        //This appears to be unused ???? Nov 2023 - can it be removed???
        //if let path = Bundle.main.path(forResource: "NameToTitleMap", ofType: "plist"),
        if let path = Bundle.module.path(forResource: "NameToTitleMap", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            if let stringValue = dict[self.name] as? String {
                return stringValue
            }
        }
        
        /// Remove leading zero in example number
        if name.range(of: "example", options: .caseInsensitive) != nil {
            let substrings = name.components(separatedBy: " ")
            if substrings.count > 1 {
                let numStr = substrings[1]
                if numStr.first == "0" {
                    let num = Int(numStr)
                    if let num = num {
                        return substrings[0] + " \(num)"
                    }
                }
            }
        }

        return self.name
    }
    
    public func getPath() -> String {
        var path = ""
        var section = self
        while true {
            path = section.name + path
            if let parent = section.parent {
                section = parent
                if parent.parent != nil {
                    path = "." + path
                }
            }
            else {
                break
            }
        }
        return path
    }
    
    public func getPathAsArray() -> [String] {
        var path:[String] = []
        var section = self
        while true {
            if section.name.count > 0 {
                path.append(section.name)
            }
            if let parent = section.parent {
                section = parent
            }
            else {
                break
            }
        }
        return path.reversed()
    }
    
    public func getExamTakingStatus() -> ExamStatus {
        guard let parent = parent else {
            return .notInExam
        }
        if parent.isExamTypeContentSection() {
            if storedAnswer == nil {
                return .inExam
            }
            else {
                return .inExamReview
            }
        }
        else {
            return .notInExam
        }
    }
    
    public func getPathTitle() -> String {
        var title = ""
        var section = self
        while true {
            title = section.getTitle() + title
            if let parent = section.parent {
                section = parent
                if parent.parent != nil {
                    title = "." + title
                }
            }
            else {
                break
            }
        }
        return title
    }

    public func getChildSectionByType(type: String) -> ContentSection? {
        if self.type == type {
            return self
        }
        else {
            for child in self.subSections {
                //not beyond next level...
                //var found = child.getChildSectionByType(type: type)
                if child.type == type {
                    return child
                }
            }
        }
        return nil
    }
    
    public func hasStoredAnswers() -> Bool {
        for section in self.subSections {
            if section.storedAnswer != nil {
                return true
            }
        }
        return false
    }
    
    public func getScore(staffCount:Int, onlyRhythm:Bool, warnNotFound:Bool=true) -> Score {
        return parseData(staffCount: staffCount, onlyRhythm: onlyRhythm)
    }
    
    public func parseData(staffCount:Int, onlyRhythm:Bool, warnNotFound:Bool=true) -> Score {
        let data = self.contentSectionData.data
        var key:Key?
        var timeSignature:TimeSignature?
        var score:Score?
        let defaultScore = Score(key: Key(type: .major, keySig: KeySignature(type: .sharp, keyName: "")), timeSignature: TimeSignature(top: 4, bottom: 4), linesPerStaff: 1)

        let tuples:[String] = data
        
        for i in 0..<tuples.count {
            let trimmedTuple = tuples[i].trimmingCharacters(in: .whitespacesAndNewlines)
            var tuple = trimmedTuple.replacingOccurrences(of: "(", with: "")
            tuple = tuple.replacingOccurrences(of: ")", with: "")
            let parts = tuple.components(separatedBy: ",")

            if i == 0 {
                let keySignature = KeySignature(type: .sharp, keyName: parts[0])
                key = Key(type: .major, keySig: keySignature)
                continue
            }
            if i == 1 {
                if parts.count == 1 {
                    let ts = TimeSignature(top: 4, bottom: 4)
                    ts.isCommonTime = true
                    timeSignature = ts
                    continue
                }

                if parts.count == 2 {
                    let ts = TimeSignature(top: Int(parts[0]) ?? 0, bottom: Int(parts[1]) ?? 0)
                    //result.append()
                    timeSignature = ts
                    continue
                }
                Logger.logger.reportError(self, "Unknown time signature tuple at \(i) :  \(self.getTitle()) \(tuple)")
                continue
            }
            
            if score == nil {
                if let key = key {
                    if let timeSignature = timeSignature {
                        score = Score(key: key, timeSignature: timeSignature, linesPerStaff: 5)
                        for i in 0..<staffCount {
                            let staff = Staff(score: score!, type: .treble, staffNum: i, linesInStaff: onlyRhythm ? 1 : 5)
                            score!.createStaff(num: i, staff: staff)
                        }
                    }
                }
            }
            
            if parts.count == 1  {
                if parts[0] == "B" {
                    if let score = score {
                        score.addBarLine()
                    }
                }
                if parts[0] == "T" {
                    if let score = score {
                        score.addTie()
                    }
                }
                continue
            }

            if parts.count == 2  {
                if parts[0] == "R" {
                    if let score = score {
                        let timeSlice = score.createTimeSlice()
                        let restValue = Double(parts[1]) ?? 1
                        let rest = Rest(timeSlice: timeSlice, value: restValue, staffNum: 0)
                        timeSlice.addRest(rest: rest)
                        continue
                    }
                }
            }

            if parts.count == 2 || parts.count == 3 || parts.count == 4 {
                var notePitch:Int?
                var value:Double?
                var accidental:Int?
                var triad:String?

                for i in 0..<parts.count {
                    if i == 0 {
                        notePitch = Int(parts[i])
                        continue
                    }
                    if i == 1 {
                        value = Double(parts[i]) ?? 1
                        continue
                    }
                    accidental = Int(parts[i])
                    if accidental == nil {
                        if ["V","I"].contains(parts[i]) {
                            triad = parts[i]
                        }
                    }
                }
                if let notePitch = notePitch {
                    if let value = value {
                        if let score = score {
                            let timeSlice = score.createTimeSlice()
                            let note = Note(timeSlice: timeSlice, num: onlyRhythm ? 71 : notePitch, value: value, staffNum: 0, accidental: accidental)
                            note.staffNum = 0
                            note.isOnlyRhythmNote = onlyRhythm
                            timeSlice.addNote(n: note)
                            if let triad = triad {
                                addTriad(score: score, timeSlice: timeSlice, note: note, triad: triad, value: note.getValue())
                            }
                        }
                    }
                }
                continue
            }
            Logger.logger.reportError(self, "Unknown tuple at \(i) :  \(self.getTitle()) \(tuple)")
        }
        if let score = score {
            //score.debugScorex("ContentSection Parse", withBeam: false)
            return score
        }
        else {
            return defaultScore
        }
    }
        
    public func addTriad(score:Score, timeSlice:TimeSlice, note:Note, triad:String, value:Double) {
        let bstaff = Staff(score: score, type: .bass, staffNum: 1, linesInStaff: 5)
        score.createStaff(num: 1, staff: bstaff)
        let key = score.key
        
        var pitch = key.firstScaleNote()
        if triad == "V" {
            pitch += 7
        }
        if pitch < 41 {
            pitch += 12
        }
        else {
            if pitch > 52 {
                pitch -= 12
            }
        }
        let root = Note(timeSlice:timeSlice, num: pitch, staffNum: 0)
        timeSlice.setTags(high: TagHigh(content:Note.getNoteName(midiNum: root.midiNumber),
                                        popup: nil,
                                        enablePopup: self.getExamTakingStatus() != .inExam),
                          low: triad)
        for i in [0,4,7] {
            let note = Note(timeSlice: timeSlice, num: pitch + i, value:value, staffNum: 1)
            timeSlice.addNote(n: note)
        }
    }
    
    public func playExamInstructions(withDelay:Bool, onLoaded: @escaping (_ status:RequestStatus) -> Void, onNarrated: @escaping () -> Void) {
        let filename = "Instructions.m4a"
        var pathSegments = getPathAsArray()
        //remove the exam title from the path
        pathSegments.remove(at: 2)
        var dataRecevied = false

        GoogleAPI.shared.getAudioDataByFileName(pathSegments: pathSegments, fileName: filename, reportError: true) {status, fromCache, data in
            if status == .failed {
                onLoaded(.failed)
            }
            else {
                if !dataRecevied {
                    dataRecevied = true
                    onLoaded(.success)
                    DispatchQueue.global(qos: .background).async {
                        if data != nil {
                            if fromCache {
                                ///Dont start speaking at the instant the view is loaded
                                if withDelay {
                                    ///Nov5,2023 DONT DELETE -  this appears to be required otherwise the audio player gets
                                    ///all the data but does not play the audio and does not throw any error.
                                    ///With the sleep the audio is heard. And the audio is heard if the audio data comes from an external lookup - i.e. is delayed
                                    sleep(1)
                                }
                            }
                        }
                        AudioRecorder.shared.playFromData(data: data!, onDone: onNarrated)
                    }
                }
            }
        }
    }
}


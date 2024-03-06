import Foundation

public class ExampleData : ObservableObject {
    @Published public var dataStatus:RequestStatus = .waiting
    var logger = Logger.logger
    private let googleAPI = GoogleAPI.shared
    private let rootContentSection:ContentSection
    
    public init(sheetName:String, rootContentSection:ContentSection) {
        self.dataStatus = .waiting
        self.rootContentSection = rootContentSection
        getSheet(sheetName: sheetName, context: "Examples", loadFunction: loadSheetData)
        getSheet(sheetName: "MelodiesSheetID", context: "Melodies", loadFunction: loadMelodies)
        getSheet(sheetName: "MTFreeLicenses", context: "Licenses", loadFunction: LicenceManager.shared.loadEmailLicenses)
    }
    
    private func getSheet(sheetName:String, context:String, loadFunction: @escaping (_ sheetRows: [[String]]) -> Void) {
        googleAPI.getContentSheet(sheetName: sheetName) { status, data in
            if status == .success {
                if let data = data {
                    struct JSONSheet: Codable {
                        let range: String
                        let values:[[String]]
                    }
                    do {
                        let jsonData = try JSONDecoder().decode(JSONSheet.self, from: data)
                        let sheetRows = jsonData.values
                        //self.loadSheetData(sheetRows: sheetRows)
                        loadFunction(sheetRows)
                        Logger.logger.log(self, "\(context) Loaded \(sheetRows.count) rows from sheet rows")
                        self.setDataReady(context: context, way: status)
                    }
                    catch {
                        self.logger.log(self, "\(context) cannot parse JSON content")
                    }
                }
                else {
                    self.setDataReady(context: context, way: .failed)
                    self.logger.log(self, "\(context) no content data")
                }
            }
            else {
                self.setDataReady(context:context, way: status)
            }
        }
    }
    

    func loadMelodies(sheetRows:[[String]]) {
        for rowCells in sheetRows {
            if rowCells.count < 4 {
                continue
            }

            if rowCells[0].hasPrefix("//")  {
                continue
            }
            guard let halfSteps = Int(rowCells[1]) else {
                continue
            }
            let name = rowCells[2]
            if name.count == 0 {
                continue
            }
            let score = Score(key: Key(type: .major, keySig: KeySignature(type: .sharp, count: 0)), timeSignature: TimeSignature(top: 4, bottom: 4), linesPerStaff: 1)
            score.createStaff(num: 0, staff: Staff(score: score, type: .treble, staffNum: 0, linesInStaff: 5))
            let melody = Melody(halfSteps: halfSteps, name: name)
            for i in 3..<rowCells.count {
                let parts = rowCells[i].components(separatedBy: ",")
                if parts.count < 2 {
                    continue
                }
                let timeSlice = TimeSlice(score: score)
                guard let value = Double(parts[1]) else {
                    continue
                }
                if parts[0] == "R" {
                    let rest = Rest(timeSlice: timeSlice, value: value, staffNum: 0)
                    timeSlice.addRest(rest: rest)
                }
                else {
                    guard let pitch = Int(parts[0]) else {
                        continue
                    }
                    let note = Note(timeSlice: timeSlice, num:pitch, value:Double(value), staffNum: 0)
                    if parts.count == 3 {
                        let accidental = Int(parts[2])
                        if [0,1,2].contains(accidental) {
                            note.writtenAccidental = accidental
                        }
                    }
                    timeSlice.addNote(n: note)
                }
                melody.timeSlices.append(timeSlice)
            }
            melody.data = Array(rowCells.dropFirst(3))
            Melodies.shared.addMelody(melody: melody)
        }
    }
    
    func loadSheetData(sheetRows:[[String]]) {
        var rowNum = 0
        let keyStart = 2
        let keyLength = 4
        let typeIndex = 7
        let dataStart = typeIndex + 2
        var contentSectionCount = 0
        var lastContentSectionDepth:Int?
        var levelContents:[ContentSection?] = Array(repeating: nil, count: keyLength)
        
        for rowCells in sheetRows {

            rowNum += 1
            if rowCells.count > 0 {
                if rowCells[0].hasPrefix("//")  {
                    continue
                }
            }
            let contentType = rowCells.count < typeIndex ? "" : rowCells[typeIndex].trimmingCharacters(in: .whitespaces)
            
            var rowHasAKey = false
            for cellIndex in keyStart..<keyStart + keyLength {
                if cellIndex < rowCells.count {
                    let keyData = rowCells[cellIndex].trimmingCharacters(in: .whitespaces)
                    if !keyData.isEmpty {
                        rowHasAKey = true
                        break
                    }
                }
            }
                            
            for cellIndex in keyStart..<keyStart + keyLength {
                var keyData:String? = nil
                if cellIndex < rowCells.count {
                    keyData = rowCells[cellIndex].trimmingCharacters(in: .whitespaces)
                }
                //a new section for type with no section name
                if let lastContentSectionDepth = lastContentSectionDepth {
                    if cellIndex > lastContentSectionDepth {
                        if !rowHasAKey {
                            if !contentType.isEmpty {
                                keyData = "_" + contentType + "_"
                            }
                        }
                    }
                }

                if let keyData = keyData {
                    if !keyData.isEmpty {
                        let keyLevel = cellIndex - keyStart
                        let parent = keyLevel == 0 ? rootContentSection : levelContents[keyLevel-1]

                        let contentData:[String]
                        if rowCells.count > dataStart {
                            contentData = Array(rowCells[dataStart...])
                        }
                        else {
                            contentData = []
                        }
                        let name = keyData.trimmingCharacters(in: .whitespacesAndNewlines)
                        let contentSection = ContentSection(
                            parent: parent,
                            name: name,
                            type: contentType.trimmingCharacters(in: .whitespacesAndNewlines),
                            data: ContentSectionData(row: rowNum,
                                                     type: contentType.trimmingCharacters(in: .whitespacesAndNewlines),
                                                     data: contentData))
                        contentSectionCount += 1
                        levelContents[keyLevel] = contentSection
                        parent?.subSections.append(contentSection)
                        if rowHasAKey {
                            lastContentSectionDepth = cellIndex
                        }
                        if let parent = contentSection.parent {
                            if parent.isExamTypeContentSection() {
                                contentSection.loadAnswerFromFile()
                            }
                            else {
//                                if Settings.shared.companionOn {
//                                    contentSection.loadAnswerFromFile()
//                                }
                            }
                        }
                        //MusicianshipTrainerApp.root.debug()
                    }
                }
            }
        }
        //rootContentSection.debug()
    }

    //load data from Google Drive Sheet

    func setDataReady(context:String, way:RequestStatus) {
        DispatchQueue.main.async {
            Logger.logger.log(self, "\(context) data was set as \(way)")
            self.dataStatus = way
        }
    }
    
}


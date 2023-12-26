import Foundation
import AVKit
import AVFoundation

public class KeySignature {
    public var accidentalType:AccidentalType
    var sharps:[Int] = [] //Notes of this pitch dont require individual accidentals, their accidental is implied by the key signature
    public var accidentalCount:Int
    //var maxAccidentals = 7
    
    public init(type:AccidentalType, count:Int) {
        self.accidentalType = type
        self.accidentalCount = count
        setAccidentals()
    }
    
    public init(keyName:String, type:Key.KeyType) {
        self.accidentalType = .sharp
        self.accidentalCount = 0
        
        var count:Int?
        if type == .major {
            switch keyName {
            case "C":
                count = 0
            case "G":
                count = 1
            case "D":
                count = 2
            case "A":
                count = 3
            case "E":
                count = 4
            case "B":
                count = 5
            default:
                count = 0
            }
        }
        else {
            switch keyName {
            case "A♭":
                count = 7
            default:
                count = 0
            }
        }
        
        if let count = count {
            self.accidentalCount = count
            setAccidentals()
        }
        else {
            Logger.logger.reportError(self, "Unknown Key \(keyName), \(type)")
        }
        //            if !(["C", "G", "D", "A", "E", "B", "A♭"].contains(keyName)) {
        //                Logger.logger.reportError(self, "Unknown Key \(keyName)")
        //            }
    }
    
    func setAccidentals() {
        if accidentalType == .sharp {
            if self.accidentalCount == 1 {
                //self.accidentalCount = 1
                sharps.append(Note.MIDDLE_C + 6) //F#
            }
            if self.accidentalCount == 2 {
                //self.accidentalCount = 2
                sharps.append(Note.MIDDLE_C + 6) //F#
                sharps.append(Note.MIDDLE_C + 1) //C#
            }
            if self.accidentalCount == 3 {
                //self.accidentalCount = 3
                sharps.append(Note.MIDDLE_C + 6) //F#
                sharps.append(Note.MIDDLE_C + 1) //C#
                sharps.append(Note.MIDDLE_C + 7) //G#
            }
            if self.accidentalCount == 4 {
                //self.accidentalCount = 4
                sharps.append(Note.MIDDLE_C + 6) //F#
                sharps.append(Note.MIDDLE_C + 1) //C#
                sharps.append(Note.MIDDLE_C + 8) //G#
                sharps.append(Note.MIDDLE_C + 3) //D#
            }
            if self.accidentalCount == 5 {
                //self.accidentalCount = 5
                sharps.append(Note.MIDDLE_C + 6) //F#
                sharps.append(Note.MIDDLE_C + 1) //C#
                sharps.append(Note.MIDDLE_C + 8) //G#
                sharps.append(Note.MIDDLE_C + 3) //D#
                sharps.append(Note.MIDDLE_C + 10) //A#
            }
        }
        else {
            if self.accidentalCount == 7 {
            }
        }
    }
}

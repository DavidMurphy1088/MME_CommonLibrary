import Foundation
import AVKit
import AVFoundation

public class KeySignature {
    public var accidentalType:AccidentalType
    var sharps:[Int] = [] //Notes of this pitch dont require individual accidentals, their accidental is implied by the key signature
    public var accidentalCount:Int
    var maxAccidentals = 7
    
    public init(type:AccidentalType, keyName:String) {
        self.accidentalType = type
        self.accidentalCount = 0
        if keyName != "" {
            if !(["C", "G", "D", "A", "E", "B"].contains(keyName)) {
                Logger.logger.reportError(self, "Unknown Key \(keyName)")
            }
        }
        if keyName == "G" {
            self.accidentalCount = 1
            sharps.append(Note.MIDDLE_C + 6) //F#
        }
        if keyName == "D" {
            self.accidentalCount = 2
            sharps.append(Note.MIDDLE_C + 6) //F#
            sharps.append(Note.MIDDLE_C + 1) //C#
        }
        if keyName == "A" {
            self.accidentalCount = 3
            sharps.append(Note.MIDDLE_C + 6) //F#
            sharps.append(Note.MIDDLE_C + 1) //C#
            sharps.append(Note.MIDDLE_C + 7) //G#
        }
        if keyName == "E" {
            self.accidentalCount = 4
            sharps.append(Note.MIDDLE_C + 6) //F#
            sharps.append(Note.MIDDLE_C + 1) //C#
            sharps.append(Note.MIDDLE_C + 8) //G#
            sharps.append(Note.MIDDLE_C + 3) //D#
        }
        if keyName == "B" {
            self.accidentalCount = 5
            sharps.append(Note.MIDDLE_C + 6) //F#
            sharps.append(Note.MIDDLE_C + 1) //C#
            sharps.append(Note.MIDDLE_C + 8) //G#
            sharps.append(Note.MIDDLE_C + 3) //D#
            sharps.append(Note.MIDDLE_C + 10) //A#
        }
    }


}

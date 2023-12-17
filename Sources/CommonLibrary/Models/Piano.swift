import SwiftUI
import CommonLibrary
import Combine
import Foundation

///A protocol for views that use the piano that need custom handling of the key view or key pressed action
public protocol PianoUserProtocol: View {
    associatedtype KeyDisplayView: View
    associatedtype KeyActionHandler: View
    init()
    func getKeyDisplayView(key:PianoKey) -> KeyDisplayView
    func getActionHandler(piano:Piano) -> KeyActionHandler
    func receiveNotificationOfKeyPress(key:PianoKey) -> Void
}

public enum KeyColor {
    case white
    case black
}

public class PianoKey: ObservableObject, Equatable {
    @Published var wasLastKeyPressed = false
    @Published var wasPressed = false
    @Published var changed = false

    public let midi:Int
    public let color:KeyColor

    public static func == (lhs: PianoKey, rhs: PianoKey) -> Bool {
        return lhs.midi == rhs.midi
    }
    
    init(midi:Int) {
        self.midi = midi
        let offset = midi % 12
        color = [0,2,4,5,7,9,11].contains(offset) ? .white : .black
    }
    
    func setLastKeyPressed(way:Bool) {
        DispatchQueue.main.async {
            self.wasLastKeyPressed = way
        }
    }
    
    ///Caller forces the key's view to update
    public func redisplay() {
        self.changed.toggle()
    }
}

public class Piano: ObservableObject {
    let id = UUID()
    var startMidi = 0
    @Published var keys:[PianoKey]
    let midiSampler = AudioSamplerPlayer.getShared().getSampler()
    var lastGestureTime:Date? = nil
    @Published var lastMidiPressed:Int?
    var soundNotes = true
    
    public init(startMidi:Int, number:Int, soundNotes:Bool) {
        self.startMidi = startMidi
        keys = []
        self.soundNotes = soundNotes
        for i in 0...number {
            let key = PianoKey(midi: startMidi + i)
            keys.append(key)
        }
    }
    
    public func getKeys() -> [PianoKey] {
        return keys
    }
    public static func midiIsBlack(midi:Int) -> Bool {
        let offset = midi % 12
        return [1,3,6,8,10].contains(offset)
    }
    
    public func getKeyForMidi(midi:Int) -> PianoKey? {
        for key in self.keys {
            if key.midi == midi {
                return key
            }
        }
        return nil
    }
    
    public func getLastMidiPressed() -> Int? {
        return lastMidiPressed
    }

    func setWasLastKeyPressed(pressedKey:PianoKey, notifyWatchers:Bool = true) {
        DispatchQueue.main.async {
            pressedKey.setLastKeyPressed(way: true)
            pressedKey.wasPressed = true
            if notifyWatchers {
                self.lastMidiPressed = pressedKey.midi
            }
            for key in self.keys {
                if key.midi != pressedKey.midi {
                    if key.wasLastKeyPressed {
                        key.setLastKeyPressed(way: false)
                        break
                    }
                }
            }
        }
    }
    
    public func clearLastPressed() {
        DispatchQueue.main.async {
            for key in self.keys {
                key.setLastKeyPressed(way: false)
            }
        }
    }

    func wasAnyKeyPressed() -> Bool {
        for key in self.keys {
            if key.wasPressed {
                return true
            }
        }
        return false
    }

    public func processGesture(key:PianoKey, gesture: DragGesture.Value) -> Bool {
        var doTap = false
        if let lastTime = lastGestureTime {
            let diff = gesture.time.timeIntervalSince(lastTime)
            if diff > 0.20 {
                doTap = true
            }
        }
        else {
            doTap = true
        }
        if doTap {
            self.lastGestureTime = gesture.time
            if self.soundNotes {
                self.playNote(midi: key.midi)
            }
            setWasLastKeyPressed(pressedKey: key)
            return true
        }
        else {
            return false
        }
    }

    public func setAllKeysUnPressed() {
        DispatchQueue.main.async {
            self.lastMidiPressed = nil
            for index in 0..<self.keys.count {
                self.keys[index].wasPressed = false
                self.keys[index].wasLastKeyPressed = false
                //self.keys[index].userFinger = nil
                //self.keys[index].showInfo = false
            }
        }
    }
    
    func getLastKeyPressed() -> PianoKey {
        for key in self.keys {
            if key.wasLastKeyPressed {
                return key
            }
        }
        return PianoKey(midi: 0)
    }
    
    public func pressKey(midi:Int) {
        for key in keys {
            if key.midi == midi {
                self.setWasLastKeyPressed(pressedKey: key, notifyWatchers: false)
                self.playNote(midi: midi)
                break
            }
        }
    }

    public func playNote(midi:Int) {
        midiSampler.startNote(UInt8(midi), withVelocity:64, onChannel:UInt8(0))
    }
    
    func debug1(_ ctx:String, midi:Int? = nil) {
        for key in self.keys {
            var show = true
            if let midi = midi {
                show = key.midi == midi
            }
            if show {
                print("  ", "midi", key.midi,
                      //"\tinScale", key.inScale,
                      //"\tCorrectFinger", key.correctFinger ?? "_", "\tReqFinger", key.requiresFingerPrompt,
                      "\tpressed", key.wasPressed)
            }
        }
    }

}

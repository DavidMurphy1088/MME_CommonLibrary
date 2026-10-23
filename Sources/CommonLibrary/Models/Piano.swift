import SwiftUI
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
    ///Key press with the time the finger actually touched the key (from UITouch.timestamp, converted to a Date).
    ///Default implementation (below) forwards to receiveNotificationOfKeyPress(key:) for users that don't need the time.
    func receiveNotificationOfKeyPress(key:PianoKey, at time:Date) -> Void
}

public extension PianoUserProtocol {
    func receiveNotificationOfKeyPress(key:PianoKey, at time:Date) {
        receiveNotificationOfKeyPress(key: key)
    }
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
    //let midiSampler = AudioManager.shared.getMidiAudioUnitSampler()
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

    ///Handle a finger-down on a key reported by PianoKeyTouchPad (one call per finger-down).
    ///RATIONALE: unlike processGesture there is no 0.20s filter. That filter used ONE lastGestureTime for the whole
    ///piano, so two DIFFERENT notes played less than 0.2s apart (fast quavers/semiquavers) dropped the second note,
    ///which also misaligned every following note and pitch in the marking.
    public func processKeyDown(key:PianoKey) {
        if self.soundNotes {
            self.playNote(midi: key.midi)
        }
        setWasLastKeyPressed(pressedKey: key)
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

    ///How long a key's note may ring before it is stopped, if no other key is pressed first (seconds)
    let maxNoteRingSeconds:Double = 0.75
    ///The note currently sounding from this keyboard
    private var soundingMidi:Int?
    ///Counts presses of each key, so a delayed stop only applies to the press that scheduled it
    private var pressCountByMidi:[Int:Int] = [:]

    ///Play a note from an on-screen key press.
    ///How long the note rings:
    ///  - The previous note stops as soon as the next key is pressed (smooth, joined notes, so each note
    ///    sounds for as long as the student actually held it in time).
    ///  - Any note still sounding after maxNoteRingSeconds is stopped, so a last or isolated note doesn't ring on.
    ///Stopping a note lets the piano sound fade naturally (sampler release), it is not cut off dead.
    ///Only on-screen key presses come here; score playback (Metronome) is not affected.
    public func playNote(midi:Int) {
        if let previous = soundingMidi {
            ///Stop the previous note. Also done when the same key is pressed again so it restarts cleanly.
            AudioManager.shared.stopPitch(note: previous)
        }
        AudioManager.shared.playPitch(midiPitch: midi)
        soundingMidi = midi

        let pressCount = (pressCountByMidi[midi] ?? 0) + 1
        pressCountByMidi[midi] = pressCount
        DispatchQueue.main.asyncAfter(deadline: .now() + maxNoteRingSeconds) { [weak self] in
            guard let self = self else { return }
            ///Only stop if this key hasn't been pressed again since (a newer press has its own timer)
            if self.pressCountByMidi[midi] == pressCount {
                AudioManager.shared.stopPitch(note: midi)
                if self.soundingMidi == midi {
                    self.soundingMidi = nil
                }
            }
        }
    }
    
    func debug1(_ ctx:String, midi:Int? = nil) {
        ///C4: debug print output removed
    }

}

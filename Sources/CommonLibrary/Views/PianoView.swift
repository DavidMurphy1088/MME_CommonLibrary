import Foundation
import SwiftUI
import Combine
import UIKit

///A transparent UIKit view laid over each piano key that reports each finger-down with the time it happened.
///RATIONALE (same as the rhythm drum's TapPad):
///  - DragGesture reports many events per press, which needed the 0.20s filter that dropped fast notes.
///    touchesBegan is called exactly ONCE per finger-down.
///  - The old code read Date() after starting the note's sound, so the recorded time included a variable delay.
///    UITouch.timestamp is when iOS detected the touch. It is on the device uptime clock, so it is converted to a
///    Date here (now minus how long ago the touch happened) so the rest of the app, including the Stop Recording
///    time (Date()), stays on one clock. The conversion itself adds no meaningful error.
struct PianoKeyTouchPad: UIViewRepresentable {
    let onKeyDown: (Date) -> Void

    final class TouchView: UIView {
        var onKeyDown: ((Date) -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                let secondsAgo = ProcessInfo.processInfo.systemUptime - touch.timestamp
                onKeyDown?(Date(timeIntervalSinceNow: -secondsAgo))
            }
        }
    }

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.backgroundColor = .clear          ///Invisible; the key drawing shows through, clear views still receive touches
        view.isMultipleTouchEnabled = true     ///Allow the next key to go down before the previous finger lifts
        view.onKeyDown = onKeyDown
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onKeyDown = onKeyDown
    }
}

public struct KeyboardView<PianoUser>: View where PianoUser: PianoUserProtocol {
    @ObservedObject var piano:Piano
    let user:any PianoUserProtocol

    @State var whiteKeyWidth = 1.0
    @State var blackKeyWidth = 0.0
    @State var clickNumber = 0
    @State var whiteKeyHeight = 0.0
    @State var anyKeyPressed:Bool = false
    @State var handViewHeight = 0.0
    @State var explanationShowing = false

    public init(piano:Piano, user:any PianoUserProtocol) {
        self.piano = piano
        self.user = user
    }
        
    func getBlackSpacing(index:Int) -> CGFloat {
        if index >= piano.keys.count-1 {
            return 0
        }
        if piano.keys[index].color == .white && piano.keys[index+1].color == .white {
            return whiteKeyWidth
        }
        return 0.0
    }
    
    func getName(ascending:Bool) -> String {
        let name = "piano"
        return name
    }

    func buttonsView() -> some View {
        HStack {
        }
    }

    public var body: some View {
        VStack {
            buttonsView()
            //let user = PianoUser()
            ZStack(alignment: .topLeading) { // Aligning to the top and leading edge

                ///White notes
                HStack(spacing: 0) {
                    ForEach(0..<piano.keys.count, id: \.self) { index in
                        if piano.keys[index].color == .white {
                            PianoKeyView<PianoUser>(id: index, piano: piano, pianoKey: piano.keys[index], user: user as! PianoUser)
                                .frame(width: whiteKeyWidth, height: whiteKeyHeight)
                                ///One call per finger-down, with the touch's own time (see PianoKeyTouchPad)
                                .overlay(
                                    PianoKeyTouchPad { touchTime in
                                        ///Record the press time first, then sound and highlight the key
                                        user.receiveNotificationOfKeyPress(key: piano.keys[index], at: touchTime)
                                        piano.processKeyDown(key: piano.keys[index])
                                    }
                                )
                        }
                    }
                }
                .border(Color.black, width: 2)

                ///Black notes
                HStack(spacing: 0) {
                    ForEach(0..<piano.keys.count, id: \.self) { index in
                        if piano.keys[index].color == .black {
                            PianoKeyView<PianoUser>(id: index, piano: piano, pianoKey: piano.keys[index], user: user as! PianoUser)
                            .frame(width: blackKeyWidth, height: whiteKeyHeight * 1.0)
                            ///One call per finger-down, with the touch's own time (see PianoKeyTouchPad)
                            ///The black key's frame is full white-key height but PianoKeyOulineView only DRAWS the top 60%.
                            ///Limit the touch area to that drawn 60% so touches below the black key fall through to the
                            ///white key underneath (as with the old DragGesture, which only responded where the key was drawn).
                            .overlay(alignment: .top) {
                                PianoKeyTouchPad { touchTime in
                                    user.receiveNotificationOfKeyPress(key: piano.keys[index], at: touchTime)
                                    piano.processKeyDown(key: piano.keys[index])
                                }
                                .frame(height: whiteKeyHeight * 0.6)
                            }
                            Spacer().frame(width: whiteKeyWidth - blackKeyWidth)
                        }
                        else {
                            Spacer().frame(width: getBlackSpacing(index: index))
                        }
                    }
                }
                .padding(.leading, whiteKeyWidth - blackKeyWidth / 2.0)
                HStack {
                    ///Spacers throw off alignment of keyboard in center of screen
                    //Spacer()
                    if let user = user as? PianoUser {
                        user.getActionHandler(piano: piano)
                    }
                    //Spacer()
                }
            }
        }
        //.border(Color .red)
        .onAppear() {
            let screenSize = UIGlobalsCommon.screenBounds
            let screenWidth = screenSize.width
            var keyCount = piano.keys.count
            if UIGlobalsCommon.isLandscape() {
                ///avoid short squat keys in landscape when there are only a few keys
                keyCount = max(piano.keys.count, 20)
            }
            ///Some keys (black) are narrower so use 1.6 multiplier
            self.whiteKeyWidth = (screenWidth * 1.6) / Double(keyCount)
            self.whiteKeyHeight = screenSize.height / 3.5
            self.handViewHeight = self.whiteKeyHeight * 0.20
            blackKeyWidth = whiteKeyWidth * 0.7
            AudioManager.shared.checkReadyToPlay("KeyboardView .OnAppear")
        }
        .onDisappear() {
            AudioManager.shared.extLog("KeyboardView .OnDisappear")
        }
    }
}

public struct PianoView<PianoUserView>: View where PianoUserView: PianoUserProtocol {
    @ObservedObject var piano:Piano
    let user:PianoUserView
    
    public init(piano:Piano, user:PianoUserView) {
        self.piano = piano
        self.user = user
    }
    
    public var body: some View {
        VStack {
            KeyboardView<PianoUserView>(piano: piano, user: user)
                //.border(Color .blue)
                
        }
    }
}

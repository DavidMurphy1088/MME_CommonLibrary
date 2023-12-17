import Foundation
import SwiftUI
import CommonLibrary
import Combine

struct KeyboardView<PianoUser>: View where PianoUser: PianoUserProtocol {
    @ObservedObject var piano:Piano

    @State var whiteKeyWidth = 1.0
    @State var blackKeyWidth = 0.0
    @State var clickNumber = 0
    @State var whiteKeyHeight = 0.0
    @State var anyKeyPressed:Bool = false
    @State var handViewHeight = 0.0
    @State var explanationShowing = false
    
    init(piano:Piano) {
        self.piano = piano
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
        
    var body: some View {
        VStack {
            buttonsView()
            let user = PianoUser()
            ZStack(alignment: .topLeading) { // Aligning to the top and leading edge

                ///White notes
                HStack(spacing: 0) {
                    ForEach(0..<piano.keys.count, id: \.self) { index in
                        if piano.keys[index].color == .white {
                            PianoKeyView<PianoUser>(id: index, piano: piano, pianoKey: piano.keys[index], user: user)
                                .frame(width: whiteKeyWidth, height: whiteKeyHeight)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged(
                                            { gesture in
                                                piano.processGesture(key:piano.keys[index], gesture: gesture)
                                                if piano.keys[index].midi == 69 {
                                                    explanationShowing = true
                                                }
                                            }
                                        )
                                )
                        }
                    }
                }
                .border(Color.black, width: 2)

                ///Black notes
                HStack(spacing: 0) {
                    ForEach(0..<piano.keys.count, id: \.self) { index in
                        if piano.keys[index].color == .black {
                            PianoKeyView<PianoUser>(id: index, piano: piano, pianoKey: piano.keys[index], user: user)
                            .frame(width: blackKeyWidth, height: whiteKeyHeight * 1.0)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged(
                                        { gesture in
                                            piano.processGesture(key:piano.keys[index], gesture: gesture)
                                        }
                                    )
                                )
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
                    user.getActionHandler(piano: piano)
                    //Spacer()
                }
            }
        }
        //.border(Color .red)

        .onAppear() {
            let screenSize = UIScreen.main.bounds
            let screenWidth = screenSize.width
            ///Some keys (black) are narrower
            self.whiteKeyWidth = (screenWidth * 1.6) / Double(piano.keys.count)
            self.whiteKeyHeight = screenSize.height / 3.5
            self.handViewHeight = self.whiteKeyHeight * 0.20
            blackKeyWidth = whiteKeyWidth * 0.7
            Settings.shared.useUpstrokeTaps = false
        }
    }
}

struct PianoView<PianoUserView>: View where PianoUserView: PianoUserProtocol {
    @ObservedObject var piano:Piano

    var body: some View {
        VStack {
            KeyboardView<PianoUserView>(piano: piano)
                //.border(Color .blue)
        }
    }
}

import Foundation
import SwiftUI

///View that a key wil display
protocol InsideKeyViewType: View {
    init(key :PianoKey)
}

struct PianoKeyOulineView : View {
    @ObservedObject var piano:Piano
    @ObservedObject var pianoKey:PianoKey
    
    var cornerRadius: CGFloat = 6
    var borderColor: Color = .black
    var borderWidth: CGFloat = 1
    
    func getColor(_ key:PianoKey) -> Color {
        if key == piano.getLastKeyPressed() {
            return Color(.systemTeal)
        }
        else {
            return pianoKey.color == .white ? Color.white : Color.black
        }
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let height = pianoKey.color == .white ? geometry.size.height : geometry.size.height * 0.6
                let rect = CGRect(x: 0, y: 0, width: geometry.size.width, height: height)
                Path { path in
                    // Start from the top left corner
                    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
                    // Draw the top edge
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
                    // Draw the right edge
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        
                    // Draw the bottom right rounded corner
                    path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                                radius: cornerRadius,
                                startAngle: Angle(degrees: 0),
                                endAngle: Angle(degrees: 90),
                                clockwise: false)
        
                    // Draw the bottom edge
                    path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        
                    // Draw the bottom left rounded corner
                    path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                                radius: cornerRadius,
                                startAngle: Angle(degrees: 90),
                                endAngle: Angle(degrees: 180),
                                clockwise: false)
        
                    // Draw the left edge and close the path
                    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                }
                .fill(getColor(pianoKey))
                .overlay(
                    ///Make a rounded bottom of key
                    Path { path in
                        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
                    }
                    .stroke(borderColor, lineWidth: borderWidth)
                )
            }
        }
    }
}

struct PianoKeyView<PianoUser>: View where PianoUser: PianoUserProtocol {
    let id:Int
    @ObservedObject var piano:Piano
    @ObservedObject var pianoKey:PianoKey
    let user:PianoUser
    let userOffset = 50.0
    @State var lastKeyPressedTime:Date? = nil

    func noteDisplay(pianoKey:PianoKey) -> some View {
        VStack {
        }
    }
        
    var body: some View {
        VStack {
            ZStack {
                PianoKeyOulineView(piano: piano, pianoKey: pianoKey)
                    //.border(Color .green)
                VStack {
                    //Text("\(pianoKey.midi)")
                    user.getKeyDisplayView(key:pianoKey)
                        .offset(y: pianoKey.color == .white ? 1.5 * userOffset : 0 - userOffset)
                }
            }
        }
    }
}


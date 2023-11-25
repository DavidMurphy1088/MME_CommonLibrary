
import Foundation
import SwiftUI
import CoreData

public class UIGlobals {
    public static var colorDefault = Color.white
    
    public static var colorInstructionsDefault = Color.blue.opacity(0.10)
    public static var colorBackgroundDefault = Color(red: 1.0, green: 1.0, blue: 0.95)
    public static var colorScoreDefault = Color(red: 0.85, green: 1.0, blue: 1.0)
    public static var colorNavigationDefault = Color(red: 0.95, green: 1.0, blue: 1.0)

    ///Behind instructions to match background of the Navigation View below which is unchangeable from grey
    //static var colorNavigationBackground = Color(red: 0.95, green: 0.95, blue: 0.95)
    //static var colorNavigationBackground = Color(red: 0.7, green: 0.0, blue: 0.0)
    
    public static let buttonPaddingiPad:Int = 12
    public static let buttonPaddingiPhone:Int = 6

    public static let cornerRadius:CGFloat = 8
    
    public static let borderColor:CGColor = CGColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    
    public static let borderLineWidth:CGFloat = 2
    
    public static let circularIconSize = 40.0
    public static let circularIconBorderSize = 4.0

    //static let font = Font.custom("Lora", size: 24)
    public static let font = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
    //static let fontiPhone = Font.custom("Lora", size: 16)
    public static let fontiPhone = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)

    public static let navigationFont =    Font.custom("Courgette-Regular", size: UIDevice.current.userInterfaceIdiom == .pad ? 26 : 18)
    public static let correctAnswerFont = Font.custom("Courgette-Regular", size: UIDevice.current.userInterfaceIdiom == .pad ? 40 : 18)

    public static func showDeviceOrientation() -> Bool {
        let orientation = UIDevice.current.orientation
        print("showDeviceOrientation --> IS PORTRAIT", orientation.isPortrait,"IS LANDSCAPE", orientation.isLandscape,
              "isGeneratingDeviceOrientationNotifications", UIDevice.current.isGeneratingDeviceOrientationNotifications,
              "RAW", orientation.rawValue)
        switch orientation {
        case .portrait:
            print("Portrait")
        case .portraitUpsideDown:
            print("Portrait Upside Down")
        case .landscapeLeft:
            print("Landscape Left")
        case .landscapeRight:
            print("Landscape Right")
        case .faceUp:
            print("Face Up")
        case .faceDown:
            print("Face Down")
        default:
            print("Unknown")
        }
        return true
    }
    public static var rhythmTolerancePercent:Double = 30.0
    public static var rhythmTapSoundOn = false
}

public func hintButtonView(_ txt:String, selected:Bool = false) -> some View {
    VStack {
        HStack {
            Text(txt).hintAnswerButtonStyle(selected: selected)
            Image(systemName: "hand.point.up.left").font(.largeTitle).foregroundColor(.white)
            Text(" ")
        }
        .background(.teal)
    }
    .cornerRadius(UIGlobals.cornerRadius)
}

struct StandardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

extension Text {

    private func buttonPadding() -> CGFloat {
        return CGFloat(UIDevice.current.userInterfaceIdiom == .phone ? UIGlobals.buttonPaddingiPhone : UIGlobals.buttonPaddingiPad)
    }
    
    public func defaultButtonStyle(enabled:Bool = true) -> some View {
        self
            .font(UIDevice.current.userInterfaceIdiom == .pad ? UIGlobals.font : UIGlobals.fontiPhone)
            .foregroundColor(.white)
            .padding(buttonPadding())
            .background(enabled ? .blue : .gray)
            .cornerRadius(UIGlobals.cornerRadius)
    }
    
    public func submitAnswerButtonStyle(enabled:Bool = true) -> some View {
        self
            .font(UIDevice.current.userInterfaceIdiom == .pad ? UIGlobals.font : UIGlobals.fontiPhone)
            .foregroundColor(.white)
            .padding(buttonPadding())
            .background(enabled ? .green : .gray)
            .cornerRadius(UIGlobals.cornerRadius)
    }
    
    public func hintAnswerButtonStyle(selected:Bool) -> some View {
        self
            .font(UIDevice.current.userInterfaceIdiom == .pad ? UIGlobals.font : UIGlobals.fontiPhone)
            .foregroundColor(.white)
            .padding(buttonPadding())
            .background(selected ? .orange : .teal)
            .cornerRadius(UIGlobals.cornerRadius)
    }

    public func defaultTextStyle() -> some View {
        self
            .font(UIGlobals.font)
            .foregroundColor(.black)
    }

    public func defaultContainer(selected:Bool) -> some View {
        self
            .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.black : Color.clear, lineWidth: 1)
                //.background(selectedIntervalIndex == index ? Color(.systemTeal) : Color.clear)
                .background(selected ? Settings.shared.colorInstructions : Color.clear)
        )
    }
    
    public func selectedButtonStyle(selected: Bool) -> some View {
        self
            .font(UIDevice.current.userInterfaceIdiom == .pad ? UIGlobals.font : UIGlobals.fontiPhone)
            .foregroundColor(.white)
            .padding(buttonPadding())
            //.background(enabled ? .blue : .gray)
            .background(selected ? .orange : .blue)
            .cornerRadius(UIGlobals.cornerRadius)
//            .padding(8)
//            .background (
//                ZStack {
//                    if selected {
//                        RoundedRectangle(cornerRadius: 10)
//                            .stroke(Color.blue, lineWidth: 3)
//                            .padding(4)  // This gives space outside the button edge.
//                    }
//                }
//            )
    }
    
    public func disabledButtonStyle() -> some View {
        self
            .font(UIDevice.current.userInterfaceIdiom == .pad ? UIGlobals.font : UIGlobals.fontiPhone)
            .foregroundColor(.white)
            .padding(buttonPadding())
            .background(Color(red: 0.7, green: 0.7, blue: 0.7))
            .cornerRadius(UIGlobals.cornerRadius)
            .padding(8)
    }
}

class UICommons {
    static let buttonCornerRadius:Double = 20.0
    static let buttonPadding:Double = 8
    static let colorAnswer = Color.green.opacity(0.4)
}




import SwiftUI
import CoreData

public struct MetronomeView: View {
    let timeSignature:TimeSignature
    let helpText:String
    var frameHeight:Double
    var backgroundColor:Color
    
    @State var isPopupPresented:Bool = false
    @ObservedObject var metronome = Metronome.getMetronomeWithCurrentSettings(ctx: "MetronomeView")
    
    public init(timeSignature:TimeSignature, helpText:String, frameHeight:Double, backgroundColor:Color) {
        self.timeSignature = timeSignature
        self.helpText = helpText
        self.frameHeight = frameHeight
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if metronome.tickingIsActive == false {
                        metronome.startTicking(timeSignature: timeSignature)
                    }
                    else {
                        metronome.stopTicking()
                    }
                }, label: {
                    if let imageURL = Bundle.module.url(forResource: "metronome", withExtension: "png") {
                        if let imageData = try? Data(contentsOf: imageURL),
                           let uiImage = UIImage(data: imageData) {
//                            Image(uiImage: uiImage)
//                                .resizable()
//                                .scaledToFit()
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            ///Needs more hiehgt on phone to even show
                                .frame(height: UIDevice.current.userInterfaceIdiom == .phone ? frameHeight * 0.8 : frameHeight * 0.5)
                                .padding(.horizontal, frameHeight * 0.1)
                                .padding(.vertical, frameHeight * 0.1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: frameHeight * 0.1)
                                        .stroke(metronome.tickingIsActive ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .padding(.horizontal, frameHeight * 0.1)
                        } else {
                            Text("Failed to load image")
                        }
                    } else {
                        Text("Image not found")
                    }
                })
                
//                if UIDevice.current.userInterfaceIdiom == .pad {
//                    Image("note_transparent")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .scaledToFit()
//                        .frame(width: frameHeight / 6.0)
//                }
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Text("\(Int(metronome.getTempo())) BPM").foregroundColor(.black)
                }
                else {
                    Text("\(Int(metronome.getTempo()))").foregroundColor(.black)
                }
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Text(metronome.tempoName).padding().foregroundColor(.black)
                }
                
                if metronome.allowChangeTempo {
                    Slider(value: Binding<Double>(
                        get: { Double(metronome.getTempo()) },
                        set: {
                            metronome.setTempo("Metronome View, Slider change", tempo: Int($0))
                        }
                    ), in: Double(metronome.tempoMinimumSetting)...Double(metronome.tempoMaximumSetting), step: 1)
                    .padding()
                }
                
                Button(action: {
                    isPopupPresented.toggle()
                }) {
                    VStack {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Text("Metronome")
                        }
                        Image(systemName: "questionmark.circle")
                    }
                }
                .padding()
                .popover(isPresented: $isPopupPresented) { //, arrowEdge: .bottom) {
                    VStack {
                        Text(helpText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                    .padding()
                    .background(
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 1)
                            .padding()
                        )
                    .padding()
                }
            }
        }
        .frame(height: frameHeight)
        .roundedBorderRectangle()
        //.background(Settings.shared.colorScore)
        //.background(backgroundColor)
    }
}





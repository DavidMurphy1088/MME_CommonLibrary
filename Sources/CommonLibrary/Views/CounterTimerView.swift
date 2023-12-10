import SwiftUI
import Combine

public struct CountdownTimerView: View {
    let size:Double
    let timerColor:Color
    let startNotification: (() -> Void)?
    let endNotification: (() -> Void)?
    var timeLimit:Binding<Double>
    
    @State var timeRemaining = 0.0
    @State private var timer: AnyCancellable?
    @State private var isActive = false
        
    public init(size:Double, timerColor:Color, timeLimit:Binding<Double>,
                startNotification: (() -> Void)?, endNotification: (() -> Void)?) {
        self.size = size
        self.timerColor = timerColor
        self.timeLimit = timeLimit
        self.startNotification = startNotification
        self.endNotification = endNotification
    }
    
    public var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                if self.isActive {
                    //self.timer?.cancel()
                    //self.timer = nil
                    timeRemaining = 0
                } else {
                    timeRemaining = timeLimit.wrappedValue
                    if let startNotification = startNotification {
                        startNotification()
                    }

                    self.timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                        .sink { _ in
                            if self.timeRemaining > 0 {
                                self.timeRemaining -= 1
                            } else {
                                self.timer?.cancel()
                                self.isActive = false
                                if let endNotification = endNotification {
                                    endNotification()
                                }
                            }
                        }
                }
                self.isActive.toggle()
            }) {
                Text(isActive ? "Stop Timer" : "Start Timer")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            CircularProgressView(progress: timeRemaining,
                                 timeRemaining: Int(timeRemaining),
                                 color: timerColor)
                .frame(width: size, height: size)
                .padding(20)
        }
    }
}

struct CircularProgressView: View {
    var progress: CGFloat
    var timeRemaining: Int
    var color:Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .opacity(timeRemaining == 0 ? 1.0 : 0.3)
                .foregroundColor(timeRemaining == 0 ? Color.red : color)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(timeRemaining == 0 ? Color.red : color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .aspectRatio(contentMode: .fit)
            
            Text("\(timeRemaining)").font(.title2)//.padding()
        }
    }
}

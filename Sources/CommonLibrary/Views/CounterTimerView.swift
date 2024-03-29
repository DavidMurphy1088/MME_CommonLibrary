import SwiftUI
import Combine

public struct CountdownTimerView: View {
    let size:Double
    let timerColor:Color
    let startNotification: (() -> Void)?
    let endNotification: (() -> Void)?
    var timeLimit:Binding<Double>
    var allowRestart:Bool
    
    @State var timeRemaining = 0.0
    @State private var timer: AnyCancellable?
    @State private var isActive = false
    @State private var activationsCount = 0
    
    public init(size:Double, timerColor:Color,
                allowRestart:Bool,
                timeLimit:Binding<Double>,
                startNotification: (() -> Void)?,
                endNotification: (() -> Void)?) {
        self.size = size
        self.timerColor = timerColor
        self.allowRestart = allowRestart
        self.timeLimit = timeLimit
        self.startNotification = startNotification
        self.endNotification = endNotification
    }
    
    func showBackground() -> Bool {
        return allowRestart || activationsCount == 0
    }
    
    public var body: some View {
        //VStack(spacing: 20) {
        ///Tried HStack but HStack makes the button not aling well with other screen buttons below 
        VStack() {
            VStack {
                if self.isActive {
                    Button(action: {
                        timeRemaining = 0
                        self.isActive = false
                    }) {
                        Text("Stop Timer")
                    }
                }
                else {
                    if allowRestart || self.activationsCount == 0 {
                        Button(action: {
                            self.isActive = true
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
                                        activationsCount += 1
                                    }
                                }
                        }) {
                            if self.allowRestart || activationsCount == 0 {
                                Text("Start Timer")
                            }
                        }
                    }
                }
            }
            .padding(showBackground() ? 10 : .zero)
            .background(showBackground() ? Color.blue : Color.clear)
            .foregroundColor(showBackground() ? .white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            CircularProgressView(progress: timeRemaining / timeLimit.wrappedValue,
                                 timeRemaining: Int(timeRemaining),
                                 color: timerColor)
                .frame(width: size, height: size)
                //.padding(20)
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
                //.trim(from: 0, to: 0.60)
                .stroke(timeRemaining == 0 ? Color.red : color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .aspectRatio(contentMode: .fit)
            
            Text("\(timeRemaining)").font(.title2)//.padding()
        }
    }
}

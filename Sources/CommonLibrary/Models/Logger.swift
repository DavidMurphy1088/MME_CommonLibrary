import Foundation

public class LogMessage : Identifiable {
    public var id:UUID = UUID()
    public var number:Int
    public var message:String
    init(num:Int, _ msg:String) {
        self.message = msg
        self.number = num
    }
}

public class Logger : ObservableObject {
    public static var logger = Logger()
    @Published var loggedMsg:String? = nil
    @Published var errorNo:Int = 0
    @Published public var errorMsg:String? = nil
    public var recordedMsgs:[LogMessage] = []
    
    public init() {
    }
    
    public func reportError(_ reporter:AnyObject, _ context:String, _ err:Error? = nil) {
        var msg = String("🛑 *** ERROR *** ErrNo:\(errorNo): " + String(describing: type(of: reporter))) + " " + context
        if let err = err {
            msg += ", "+err.localizedDescription
        }
        print(msg)
        recordedMsgs.append(LogMessage(num: recordedMsgs.count, msg))
        DispatchQueue.main.async {
            //print("===>Logger::publishing", self.id.uuidString.prefix(8), msg)
            self.errorMsg = msg
            self.errorNo += 1
        }
    }
        
    public func reportErrorString(_ context:String, _ err:Error? = nil) {
        reportError(self, context, err)
    }

    public func log(_ reporter:AnyObject, _ msg:String) {
        let msg = String(describing: type(of: reporter)) + ":" + msg
        print("Logger ------>", msg)
        recordedMsgs.append(LogMessage(num: recordedMsgs.count, msg))
//      TODO  if !MusicianshipTrainerApp.productionMode {
//            DispatchQueue.main.async {
//                self.loggedMsg = msg
//            }
//        }
    }
    
}

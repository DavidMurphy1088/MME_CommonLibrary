import Foundation

public class LogMessage : Identifiable {
    public var id:UUID = UUID()
    public var number:Int
    public var message:String
    public let logTime = Date()
    
    init(num:Int, _ msg:String) {
        self.message = msg
        self.number = num
    }
    
    public func getLogEvent() -> String {
        var out = String(number)+"   "
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let logTime = formatter.string(from: self.logTime)
        out += logTime + " " + message
        return out
    }
}

public class AppLogger : ObservableObject {
    public static var logger = AppLogger()
    @Published var loggedMsg:String? = nil
    @Published var errorNo:Int = 0
    @Published public var errorMsg:String? = nil
    public var loggedMsgs:[LogMessage] = []
    
    public init() {
    }
    
    private func getTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy HH:mm:ss"
        let now = Date()
        let s = dateFormatter.string(from: now)
        return s
    }
    
    public func reportError(_ reporter:AnyObject, _ context:String, _ err:Error? = nil) {
        var msg = String("\(getTime()) 🛑 =========== ERROR =========== ErrNo:\(errorNo): " + String(describing: type(of: reporter))) + " " + context
        if let err = err {
            msg += ", "+err.localizedDescription
        }
        print(msg)
        loggedMsgs.append(LogMessage(num: loggedMsgs.count, msg))
        DispatchQueue.main.async {
            self.errorMsg = msg
            self.errorNo += 1
        }
    }
        
    public func reportErrorString(_ context:String, _ err:Error? = nil) {
        reportError(self, context, err)
    }

    public func log(_ reporter:AnyObject, _ msg:String) {
        let msg = String(describing: type(of: reporter)) + ":" + msg
        print("\(getTime()) Logger:", msg)
        loggedMsgs.append(LogMessage(num: loggedMsgs.count, msg))
    }
    
}

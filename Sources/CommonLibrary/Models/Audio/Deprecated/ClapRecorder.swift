//import SwiftUI
//import CoreData
//import AVFoundation
//
////Record a student clapping
//
//class ClapRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, ObservableObject {
//    //http://www.mirbsd.org/~tg/soundfont/
//    //https://sites.google.com/site/soundfonts4u/
//    
//    var captureSession:AVCaptureSession = AVCaptureSession()
//    var captureCtr = 0
//    
//    static let requiredDecibelChangeInitial = 5 //16
//    static let requiredBufSizeInitial = 32
//    
//    private var requiredDecibelChange = 10
//    private var requiredBufSize = 16
//
//    var audioPlayers:[AVAudioPlayer] = []
//    
//    var decibelBuffer:[DecibelBufferRow] = []
//    var logBuffer:[DecibelBufferRow] = []
//
//    var clapCnt = 0
//    @Published var clapCounter = 0
//
//    //Record a decibel level at a specified time for logging
//    class DecibelBufferRow: Encodable {
//        static private var startTime:TimeInterval = 0
//        private var ctr:Int
//        private var time:TimeInterval
//        private var decibelsAvg:Double
//        var decibels:Double
//        public var clap:Bool
//
//        init(ctr:Int, time:TimeInterval, decibels:Double, decibelsAvg:Double) {
//            self.ctr = ctr
//            self.time = time
//            if ctr == 0 {
//                DecibelBufferRow.startTime = time
//            }
//            self.decibels = decibels
//            self.decibelsAvg = decibelsAvg
//            self.clap = false
//        }
//        
//        func getRow() -> String {
//            var r = "" //String(ctr) + "\t"
//            r += String(format: "%.2f", (time - DecibelBufferRow.startTime)) + "\t"
//            r += String(decibels + 50.0)
//            if clap {
//                r += "\t" + String(50.0)
//            }
//            return r
//        }
//    }
//    
//    override init() {
//    }
//    
//    func setRequiredDecibelChange(change:Int) {
//        self.requiredDecibelChange = change
//        //print("recorder required dec change changed to: \(change)")
//    }
//    
//    func setRequiredBufferSize(change:Int) {
//        self.requiredBufSize = change
//        self.decibelBuffer = []
//        //print("recorder required buffer size change changed to: \(change)")
//    }
//
//    func fmt(_ inx:Double) -> String {
//        return String(format: "%.4f", inx)
//    }
//        
//    func startRecording() {
//        self.captureSession = AVCaptureSession()
//        let captureDevice = AVCaptureDevice.default(for: AVMediaType.audio)
//        var audioInput : AVCaptureDeviceInput? = nil
//          
//        do {
//            try captureDevice?.lockForConfiguration()
//            audioInput = try AVCaptureDeviceInput(device: captureDevice!)
//            captureDevice?.unlockForConfiguration()
//        } catch let error {
//            Logger.logger.reportError(self, "ClapRecorder:capture", error as NSError)
//        }
//
//        // Add audio input
//        if captureSession.canAddInput(audioInput!) {
//            captureSession.addInput(audioInput!)
//        } else {
//            Logger.logger.reportError(self, "ClapRecorder:add Input")
//        }
//        
//        let audioOutput = AVCaptureAudioDataOutput()
//        audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
//        
//        if captureSession.canAddOutput(audioOutput) {
//            captureSession.addOutput(audioOutput)
//        } else {
//            Logger.logger.reportError(self, "ClapRecorder:add output")
//        }
//        captureCtr = 0
//        //logBuffer = []
//        DispatchQueue.global(qos: .background).async {
//            //print("Started recording")
//            self.captureSession.startRunning()
//        }
//    }
//    
//    func stopRecording() {
//        DispatchQueue.global(qos: .background).async {
//            //print("Stopped recording")
//            self.captureSession.stopRunning()
//        }
//    }
//}

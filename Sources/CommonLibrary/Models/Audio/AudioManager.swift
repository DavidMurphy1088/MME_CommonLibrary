import Foundation
import AVFoundation

///Notification of session interruptions. e.g. phone call
extension AudioManager {
    @objc func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                  return
        }

        switch type {
        case .began:
            // Interruption began, pause or stop the audio
            Logger.logger.reportError(self, "AudioManager.handleAudioSessionInterruption. Interruption started")

        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                Logger.logger.reportError(self, "AudioManager.handleAudioSessionInterruption. Interruption ended")
                if options.contains(.shouldResume) {
                    // Interruption ended. Attempt to resume playback, if appropriate
                    //resumeAudio()
                }
            }

        @unknown default:
            Logger.logger.reportError(self, "AudioManager.handleAudioSessionInterruption. Interruption unknown type")
            break
        }
    }
}

public class AudioManager {
    public static let shared = AudioManager()
    private static var instanceCount = 0
    
    ///Best Practice:For the majority of apps, the best practice is to initialize AVAudioEngine once and use its methods to control its state throughout the app's lifecycle.
    private var audioEngine:AVAudioEngine?// = AVAudioEngine()
    private var audioUnitSampler:AVAudioUnitSampler? //()
    
    private let audioPlayersCount = 32 //Must be > max number of notes in any melody
    private var audioPlayerNodes: [AVAudioPlayerNode] = []
    private var playerNodeIndex = 0
    private var lastReset:Date?
    private let id = UUID()
    private let audioResourceName = "audiomass-output"
    
    private init() {
        initAudio("init")
    }
    
    private func log(_ ctx:String, _ msg:String) {
        let uuidString = id.uuidString
        let last4 = String(uuidString.suffix(4))
        let audioID = String(audioEngine.hashValue)
        let audioID4 = audioID.suffix(4)
        Logger.logger.log(self, "AudioManagerID:\(last4) AVAudioEngine:\(audioID4) ctx:\(ctx) \(msg)")
    }
    
    public func extLog(_ msg:String) {
        log("ExtLog --->", msg)
    }
    
    public func checkReadyToPlay(_ ctx:String) {
        guard let audioEngine = audioEngine else {
            return
        }
        log(ctx, "CheckReadyToPlay")
        if audioEngine.isRunning {
            return
        }
        Logger.logger.reportError(self, "\(ctx) CheckReadyToPlay - Audio engine is stopped, so resetting")
        fullReset()
    }
    
    public func fullReset() {
        //DispatchQueue.main.async {
            if let audioEngine = self.audioEngine {
                self.log("fullReset", "Start RESETING AUDIO")
                audioEngine.stop()
                for player in self.audioPlayerNodes {
                    audioEngine.disconnectNodeInput(player)
                    audioEngine.detach(player)
                }
                self.audioPlayerNodes = []
                if let sampler = self.audioUnitSampler {
                    audioEngine.disconnectNodeInput(sampler)
                    audioEngine.detach(sampler)
                }
                audioEngine.reset()
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                } catch {
                    print("Error deactivating audio session: \(error)")
                }
            }
            self.playerNodeIndex = 0
            self.initAudio("Reset")
            self.log("fullReset", "End RESETING AUDIO...")
        //}
    }
    
    private func initAudio(_ ctx:String) {
        AudioManager.instanceCount += 1
        //lastContext = "AudioManager initAudio"

        self.audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            return
        }
        log(ctx, "InitAudio. Create audio engine, sampler and playerNodes")

        self.audioUnitSampler = AVAudioUnitSampler()
        guard let audioUnitSampler = self.audioUnitSampler else {
            return
        }
        
        setAudioSession("initAudio")
        
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: nil) { notification in
            if let audioEngine = self.audioEngine {
                if audioEngine.isRunning {
                    self.log(ctx, "AVAudioEngineConfigurationChange, audio engine is RUNNING")
                } else {
                    self.log(ctx, "AVAudioEngineConfigurationChange, audio engine is STOPPED")
                    Logger.logger.reportError(self, "AVAudioEngineConfigurationChange, audio engine is STOPPED. AVAudioEngine instance:\(audioEngine.hashValue)")
//                    var sessionInfo = "Session Category: \(AVAudioSession.sharedInstance().category) "
//                    sessionInfo = " Category options:\(AVAudioSession.sharedInstance().categoryOptions)"
                }
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        
        ///Play note pitches in a score
        loadSoundFont(audioUnitSampler: audioUnitSampler)
        audioEngine.attach(audioUnitSampler)
        audioEngine.connect(audioUnitSampler, to: audioEngine.mainMixerNode, format: nil)
        
        ///Load sound for optional drum sound taps
        //loadTapPlayers(ctx: "initAudio", audioEngine: audioEngine)
        
        ///Cant start audioEngine until nodes are connected
        do {
            try audioEngine.start()
            log(ctx, "audioEngine was started OK")
        } catch {
            Logger.logger.reportError(self, "[\(ctx)] Could not start the audio engine: \(error)")
        }
    }
    
    ///AVAudioEngine and AVKit VideoPlayer Competition: Both frameworks require exclusive access to the audio hardware on iOS devices. 
    ///When you initiate video playback using AVKit VideoPlayer, it takes control of the audio hardware, causing AVAudioEngine to stop and subsequently trigger the AVAudioEngineConfigurationChange notification.
    ///If you only need AVAudioEngine before or after video playback, pause it while the video is playing:
//    public func pause(_ ctx:String, pause:Bool) {
//        if let audioEngine = audioEngine {
//            Logger.logger.log(self, "[\(ctx)] Pause engine for video way:\(pause). AVAudioEngine instance:\(audioEngine.hashValue)")
//            if pause {
//                audioEngine.pause()
//            }
//            else {
//                do {
//                    try audioEngine.start()
//                    setAudioSession("Restart after pause. Is engine started \(audioEngine.isRunning). AVAudioEngine instance:\(audioEngine.hashValue)")
//                }
//                catch {
//                    Logger.logger.reportError(self, "[\(ctx)] Could not restart the audio engine after video: \(error)")
//                }
//            }
//        }
//    }
    
    private func loadSoundFont(audioUnitSampler:AVAudioUnitSampler) {
        //https://www.rockhoppertech.com/blog/the-great-avaudiounitsampler-workout/#soundfont
        //https://sites.google.com/site/soundfonts4u/
        //let soundFontNames = [("Piano", "Nice-Steinway-v3.8")] //, ("Guitar", "GuitarAcoustic")]
        /// From https://www.producersbuzz.com/downloads/download-free-soundfonts-sf2/top-18-free-piano-soundfonts-sf2/
        let soundFontNames = [("Piano", "Piano")] //, ("Guitar", "GuitarAcoustic")]
        //let soundFontNames = [("Piano", "Yamaha-Grand-Lite-v2.0")] //, ("Guitar", "GuitarAcoustic")]
        
        let samplerFileName = soundFontNames[0].1
        if let url = Bundle.module.url(forResource: samplerFileName, withExtension: "sf2") {
            let ins = 0
            for instrumentProgramNumber in ins..<256 {
                do {
                    try audioUnitSampler.loadSoundBankInstrument(at: url,
                                                                 program: UInt8(instrumentProgramNumber),
                                                                 bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                                 bankLSB: UInt8(kAUSampler_DefaultBankLSB))
                    break
                }
                catch {
                    break
                }
            }
        }
        else {
            Logger.logger.reportError(self, "Cannot loadSoundBankInstrument \(samplerFileName)")
        }
        log("loadSoundFont", "Sampler loaded sound font")
    }
    
    public func getAVAudioUnitSampler() -> AVAudioUnitSampler? {
        return audioUnitSampler
    }
    
    public func getAudioEngine() -> AVAudioEngine? {
        return self.audioEngine
    }
            
    private func setAudioSession(_ ctx:String) {
        let audioSession = AVAudioSession.sharedInstance()
        //lastContext = ctx
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            log(ctx, "Set audio session for first call. Set .playAndRecord")
        } catch {
            Logger.logger.reportErrorString("[\(ctx)] Set audio session failed", error)
        }
    }
    
    ///---------------- Tap sounds ----------------
//    public func scheduleTapPlayers(ctx:String) { //call this whenever starting tapp
//        if let fileURL = Bundle.module.url(forResource: audioResourceName, withExtension: "mp3"),
//           let file = try? AVAudioFile(forReading: fileURL) {
//            for i in 0..<audioPlayersCount {
//                let node = audioPlayerNodes[i]
//                //audioEngine.connect(node, to: audioEngine.mainMixerNode, format: file.processingFormat)
//                node.reset()
//                node.scheduleFile(file, at: nil, completionHandler: nil)
//                node.volume = 1.0
//            }
//            Logger.logger.log(self, "[\(ctx)] loaded sound for \(audioPlayersCount) AVAudioPlayers")
//        }
//        else {
//            Logger.logger.reportError(self, "[\(ctx)] Failed load AVAudioPlayer sound")
//        }
//    }
    
    public func scheduleTapPlayers(ctx:String) {
        guard let audioEngine = self.audioEngine else {
            return
        }
        for node in audioPlayerNodes {
            node.stop()
            audioEngine.detach(node)
        }
        self.log(ctx, "LoadTapSoundPlayers, detached \(audioPlayersCount) audio players")
        audioPlayerNodes = []
        for _ in 0..<audioPlayersCount {
            let playerNode = AVAudioPlayerNode()
            audioPlayerNodes.append(playerNode)
            audioEngine.attach(playerNode)
        }
        //Load a sound with minimum latency for tapping a rhythm
        if let fileURL = Bundle.module.url(forResource: audioResourceName, withExtension: "mp3"),
           let file = try? AVAudioFile(forReading: fileURL) {
            for i in 0..<audioPlayersCount {
                let node = audioPlayerNodes[i]
                audioEngine.connect(node, to: audioEngine.mainMixerNode, format: file.processingFormat)
                node.scheduleFile(file, at: nil, completionHandler: nil)
                node.volume = 1.0
            }
        }
        else {
            Logger.logger.reportError(self, "[\(ctx)] Failed load AVAudioPlayer sound")
        }
        self.log(ctx, "LoadTapSoundPlayers, scheduled \(audioPlayersCount) audio players")
    }
    
//    public func stopAudio(ctx:String) {
//        guard let audioEngine = self.audioEngine else {
//            return
//        }
//        for i in 0..<audioPlayersCount {
//            audioPlayerNodes[i].stop()
//        }
////        for i in 0..<audioPlayersCount {
////            audioEngine.detach(audioPlayerNodes[i])
////        }
//        Logger.logger.log(self, "\(ctx) StopAudio count:\(audioPlayersCount)")
////        audioEngine.stop() //Bad idea .... dont stop it
//    }

    public func playSound() {
        if playerNodeIndex >= audioPlayerNodes.count {
            playerNodeIndex = 0
        }
        self.audioPlayerNodes[playerNodeIndex].play()
        playerNodeIndex += 1
    }

}

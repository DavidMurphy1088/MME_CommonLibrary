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
            //pauseAudio()
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
    public  static let shared = AudioManager()
    private static var instanceCount = 0
    
    ///Best Practice:For the majority of apps, the best practice is to initialize AVAudioEngine once and use its methods to control its state throughout the app's lifecycle.
    private var audioEngine:AVAudioEngine?// = AVAudioEngine()
    private var audioUnitSampler:AVAudioUnitSampler? //()

    //public var callNumber = 0
    private var lastContext = ""
    
    private var audioPlayerNodes: [AVAudioPlayerNode] = []
    private var playerNodeIndex = 0
    private let audioPlayersCount = 32
    private var lastReset:Date?

    private init() {
        initAudio("init")
    }
    
    public func fullReset(manual:Bool) {
        if let lastReset = lastReset {
            if Date().timeIntervalSince(lastReset) < 5 {
                return
            }
        }
        lastReset = Date()
        DispatchQueue.main.async {
            Logger.logger.log(self, "Start RESETING AUDIO...instance:\(AudioManager.instanceCount)")
            if let audioEngine = self.audioEngine {
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
            self.lastContext = "Reset"
            self.initAudio("Reset")
            Logger.logger.log(self, "End RESETING AUDIO...")
        }
    }
    
    private func initAudio(_ ctx:String) {
        Logger.logger.log(self, "[\(ctx)] initAudio. Create audio engine, sampler and playerNodes. Instance:\( AudioManager.instanceCount)")
        AudioManager.instanceCount += 1
        lastContext = "AudioManager initAudio"

        self.audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            return
        }
        self.audioUnitSampler = AVAudioUnitSampler()
        guard let audioUnitSampler = self.audioUnitSampler else {
            return
        }
        
        setAudioSession("initAudio")
        
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: nil) { notification in
            if let audioEngine = self.audioEngine {
                if audioEngine.isRunning {
                    Logger.logger.log(self,"[\(ctx)] AVAudioEngineConfigurationChange, audio engine is RUNNING")
                } else {
                    Logger.logger.reportError(self, "AVAudioEngineConfigurationChange, audio engine is STOPPED. The last context was \(self.lastContext)")
                    self.fullReset(manual: false)
                }
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        
        loadSoundFont(audioUnitSampler: audioUnitSampler)
        audioEngine.attach(audioUnitSampler)
        audioEngine.connect(audioUnitSampler, to: audioEngine.mainMixerNode, format: nil)
        loadTapSoundPlayers(ctx: "initAudio", audioEngine: audioEngine)
        
        ///Cant start iaudioEngine until nodes are connected
        do {
            try audioEngine.start()
            Logger.logger.log(self, "[\(ctx)] audioEngine was started OK")
        } catch {
            Logger.logger.reportError(self, "[\(ctx)] Could not start the audio engine: \(error)")
        }
    }
    
    private func loadSoundFont(audioUnitSampler:AVAudioUnitSampler) {
        //https://www.rockhoppertech.com/blog/the-great-avaudiounitsampler-workout/#soundfont
        //https://sites.google.com/site/soundfonts4u/
        //let soundFontNames = [("Piano", "Nice-Steinway-v3.8")] //, ("Guitar", "GuitarAcoustic")]
        /// From https://www.producersbuzz.com/downloads/download-free-soundfonts-sf2/top-18-free-piano-soundfonts-sf2/
        //let soundFontNames = [("Piano", "Piano")] //, ("Guitar", "GuitarAcoustic")]
        let soundFontNames = [("Piano", "Small Pianos Bank")] //, ("Guitar", "GuitarAcoustic")]
        
        let samplerFileName = soundFontNames[0].1
        
        ///18May23 -For some unknown reason and after hours of investiagtion this loadSoundbank must oocur before every play, not just at init time
        
        if let url = Bundle.module.url(forResource: samplerFileName, withExtension: "sf2") {
            let ins = 0
            for instrumentProgramNumber in ins..<256 {
                do {
                    try audioUnitSampler.loadSoundBankInstrument(at: url, program: UInt8(instrumentProgramNumber), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(kAUSampler_DefaultBankLSB))
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
        Logger.logger.log(self, "Sampler loaded sound font")
    }
    
    public func getAVAudioUnitSampler() -> AVAudioUnitSampler? {
        return audioUnitSampler
    }
    
    public func getAudioEngine() -> AVAudioEngine? {
        return self.audioEngine
    }
            
    public func log(_ ctx:String) {
        Logger.logger.log(self, "AudioManager log :: [\(ctx)]")
    }
    
    private func setAudioSession(_ ctx:String) {
        let audioSession = AVAudioSession.sharedInstance()
        lastContext = ctx
        //if callNumber == 0 {
            do {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
                try audioSession.setActive(true)
                Logger.logger.log(self, "[\(ctx)] Set audio session for first call. Set .playAndRecord")
            } catch {
                Logger.logger.reportErrorString("[\(ctx)] Set audio session failed", error)
            }
//        }
//        else {
//            Logger.logger.log(self, "[\(ctx)] Ignored set audio session play, sessionCategory:\(audioSession.category)")
//        }
        //callNumber += 1
    }
    
    ///---------------- Tap sounds ----------------
    
    public func loadTapSoundPlayers(ctx:String, audioEngine:AVAudioEngine) {
        audioPlayerNodes = []
        for _ in 0..<audioPlayersCount {
            let playerNode = AVAudioPlayerNode()
            audioPlayerNodes.append(playerNode)
            audioEngine.attach(playerNode)
        }
        //Load a sound with minimum latency for tapping a rhythm
        let name = "audiomass-output"
        //if let fileURL = Bundle.main.url(forResource: name, withExtension: "mp3"),
        if let fileURL = Bundle.module.url(forResource: name, withExtension: "mp3"),
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
        Logger.logger.log(self, "\(ctx) LoadTapSoundPlayers count:\(audioPlayersCount)")
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
        //self.audioPlayerNodes[playerNodeIndex].stop()
        playerNodeIndex += 1
    }

}

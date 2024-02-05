import Foundation
import AVFoundation

///Notification of temporary session interruptions. e.g. phone call. Should get a .begin then a .ended
extension AudioManager {
    @objc func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                  return
        }

        switch type {
        case .began:
            /// Interruption began, pause or stop the audio
            /// ///The typical case for this app is that the user played a student video example. This causes the .begin, .end sequence of interruption
            let running = self.audioEngine?.isRunning
            Logger.logger.log(self, "AudioManager.handleAudioSessionInterruption. Interruption started, engine running?:\(running)")

        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                let running = self.audioEngine?.isRunning
                Logger.logger.log(self, "AudioManager.handleAudioSessionInterruption. Interruption ended, engine running?:\(running) Options:\(options)")
                if let engine = self.audioEngine {
                    if !engine.isRunning {
                        do {
                            try engine.start()
                            Logger.logger.log(self, "AudioManager.handleAudioSessionInterruption. Audio engine was restarted OK after interruption")
                        }
                        catch {
                            Logger.logger.reportError(self, "Could not start the audio engine after interruption: \(error)")
                        }
                    }
                }
                if options.contains(.shouldResume) {
                    // Interruption ended. Attempt to resume playback, if appropriate
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
    private var midiAudioUnitSampler:AVAudioUnitSampler? //()
    
    ///Used if user wants audio sounds for each rhythm tap
    private let tappingAudioPlayersCount = 32 //Must be > max number of notes in any melody
    private var tappingAudioPlayerNodes: [AVAudioPlayerNode] = []
    
    private var playerNodeIndex = 0
    private var lastReset:Date?
    private let id = UUID()
    private let audioResourceName = "audiomass-output"
    private var logEventNum = 0

    private init() {
        initAudio("init")
    }
    
    private func log(_ ctx:String, _ msg:String) {
        let uuidString = id.uuidString
        let last4 = String(uuidString.suffix(4))
        let audioID = String(audioEngine.hashValue)
        let audioID4 = audioID.suffix(4)
        Logger.logger.log(self, "\(logEventNum) AudioManagerID:\(last4) AVAudioEngine:\(audioID4) ctx:\(ctx) \(msg)")
        logEventNum += 1
    }
    
    public func extLog(_ msg:String) {
        log("ExtLog --->", msg)
    }
    
    ///Various events are capable of causing the audio engine to stop. e.g. a browser playing video or some other app running
    ///So check whenver audioEngine is needed that its running.
    public func checkReadyToPlay(_ ctx:String) {
        guard let audioEngine = audioEngine else {
            return
        }
        if audioEngine.isRunning {
            log(ctx, "CheckReadyToPlay - Audio engine is ready to play")
            return
        }
        log(ctx, "CheckReadyToPlay - Audio engine is not ready so resetting it")
        ///Full reset never worked on first return to keyboard appearing - pitches were silent. It required a 2nd appearance of the keyboad view
        //////Whereas only reloading the midi sampler does appear to aloow first appearance of keyboard to sound pitches
        //self.fullReset()
        if !audioEngine.isRunning {
            do {
                //audioEngine.reset()
                if let sampler = midiAudioUnitSampler {
                    loadSoundFont(audioUnitSampler: sampler)
                }
                try audioEngine.start()
                Logger.logger.log(self, "CheckReadyToPlay - Audio engine was restarted OK after interruption")
            }
            catch {
                Logger.logger.reportError(self, "CheckReadyToPlay - Could not start the audio engine after interruption: \(error)")
            }
        }

        if audioEngine.isRunning {
            self.log(ctx, "CheckReadyToPlay - Audio engine is ready to play after reset")
        }
        else {
            Logger.logger.reportError(self, "CheckReadyToPlay - Audio engine is not ready to play after reset")
        }
    }
    
    public func fullReset() {
        if let audioEngine = self.audioEngine {
            self.log("fullReset", "Start RESETING AUDIO")
            audioEngine.stop()
            for player in self.tappingAudioPlayerNodes {
                audioEngine.disconnectNodeInput(player)
                audioEngine.detach(player)
            }
            self.tappingAudioPlayerNodes = []
            if let sampler = self.midiAudioUnitSampler {
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
        ///self.audioEngine = nil
        self.initAudio("Reset")
        self.log("fullReset", "End RESETING AUDIO...")
    }
    
    private func initAudio(_ ctx:String) {
        AudioManager.instanceCount += 1
        if self.audioEngine == nil {
            self.audioEngine = AVAudioEngine()
        }
        guard let audioEngine = audioEngine else {
            return
        }
        self.midiAudioUnitSampler = AVAudioUnitSampler()
        //self.midiAudioUnitSampler.
        guard let midiAudioUnitSampler = self.midiAudioUnitSampler else {
            return
        }
        
        setAudioSessionPlayback("initAudio")
        
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: nil) { notification in
            if let audioEngine = self.audioEngine {
                if audioEngine.isRunning {
                    self.log(ctx, "AVAudioEngineConfigurationChange notification, audio engine is RUNNING")
                } else {
                    self.log(ctx, "AVAudioEngineConfigurationChange notification, audio engine is STOPPED")
                    ///Its not an error. e.g happens if student records acoustic piano in SR
                }
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        
        ///Load sound font to play note pitches in a score
        loadSoundFont(audioUnitSampler: midiAudioUnitSampler)
        audioEngine.attach(midiAudioUnitSampler)
        audioEngine.connect(midiAudioUnitSampler, to: audioEngine.mainMixerNode, format: nil)

        ///Cant start audioEngine until nodes are connected
        do {
            try audioEngine.start()
            log(ctx, "InitAudio. Created audio engine and sampler")
            setAudioSessionPlayback("initAudio")

        } catch {
            Logger.logger.reportError(self, "[\(ctx)] Could not start the audio engine: \(error)")
        }
    }
    
    private func loadSoundFont(audioUnitSampler:AVAudioUnitSampler) {
        //https://www.rockhoppertech.com/blog/the-great-avaudiounitsampler-workout/#soundfont
        //https://sites.google.com/site/soundfonts4u/
        //let soundFontNames = [("Piano", "Nice-Steinway-v3.8")] //, ("Guitar", "GuitarAcoustic")]
        /// From https://www.producersbuzz.com/downloads/download-free-soundfonts-sf2/top-18-free-piano-soundfonts-sf2/
        //let soundFontNames = [("Piano", "Piano")]
        //let soundFontNames = [("Piano", "Yamaha-Grand-Lite-v2.0")]
        //let soundFontNames = [("akai_steinway", "akai_steinway")]
        //let soundFontNames = [("GD_Clean_Concert_Grand", "GD_Clean_Concert_Grand")]
        //let soundFontNames = [("Chateau Grand-SF-Lite-v1.0", "Chateau Grand-SF-Lite-v1.0")]
        //let soundFontNames = [("Yamaha-Grand-Lite-v2.0", "Yamaha-Grand-Lite-v2.0")]
        let soundFontNames = [("akai_steinway", "akai_steinway")]

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
        log("loadSoundFont", "Sampler loaded sound font \(samplerFileName)")
    }
    
    public func playPitch(midiPitch: Int, timeDurationSecs:Double? = nil) {
        if let sampler = midiAudioUnitSampler {
            sampler.startNote(UInt8(midiPitch), withVelocity: 127, onChannel: 0)
            if let timeDurationSecs = timeDurationSecs {
                DispatchQueue.global(qos: .background).async {
                    print("=================play", midiPitch, timeDurationSecs)
                    usleep(useconds_t(timeDurationSecs * 1000000.0))
                    self.stopPitch(note: midiPitch)
                }
            }
        }
    }

    func stopPitch(note: Int) {
        if let sampler = midiAudioUnitSampler {
            sampler.stopNote(UInt8(note), onChannel: 0)
        }
    }
    
    public func getAudioEngine() -> AVAudioEngine? {
        return self.audioEngine
    }
            
    public func setAudioSessionPlayback(_ ctx:String) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            ///Play and record causes iPhone volume very soft so only use .record when needed
            //try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: .default)
            try audioSession.setActive(true)
            log(ctx, "SetAudioSessionPlayback. Set .playback")
        } catch {
            Logger.logger.reportErrorString("[\(ctx)] SetAudioSessionPlayback. Set audio session playback failed", error)
        }
    }
    
    public func setAudioSessionRecord(_ ctx:String) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record, mode: .default)
            try audioSession.setActive(true)
            log(ctx, "Set audio session for first call. Set .record")
        } catch {
            Logger.logger.reportErrorString("[\(ctx)] Set audio session record failed", error)
        }
    }
    
    public func scheduleTapPlayers(ctx:String) {
        guard let audioEngine = self.audioEngine else {
            return
        }
        for node in tappingAudioPlayerNodes {
            node.stop()
            audioEngine.detach(node)
        }
        self.log(ctx, "ScheduleTapPlayers, detached \(tappingAudioPlayersCount) audio players")
        tappingAudioPlayerNodes = []
        for _ in 0..<tappingAudioPlayersCount {
            let playerNode = AVAudioPlayerNode()
            tappingAudioPlayerNodes.append(playerNode)
            audioEngine.attach(playerNode)
        }
        //Load a sound with minimum latency for tapping a rhythm
        if let fileURL = Bundle.module.url(forResource: audioResourceName, withExtension: "mp3"),
           let file = try? AVAudioFile(forReading: fileURL) {
            for i in 0..<tappingAudioPlayersCount {
                let node = tappingAudioPlayerNodes[i]
                audioEngine.connect(node, to: audioEngine.mainMixerNode, format: file.processingFormat)
                node.scheduleFile(file, at: nil, completionHandler: nil)
                node.volume = 1.0
            }
        }
        else {
            Logger.logger.reportError(self, "[\(ctx)] ScheduleTapPlayers, failed load AVAudioPlayer sound")
        }
        self.log(ctx, "ScheduleTapPlayers, scheduled \(tappingAudioPlayersCount) audio players")
    }
    
    public func playSound() {
        if playerNodeIndex >= tappingAudioPlayerNodes.count {
            playerNodeIndex = 0
        }
        do {
            self.tappingAudioPlayerNodes[playerNodeIndex].play()
        }
        playerNodeIndex += 1
    }

}

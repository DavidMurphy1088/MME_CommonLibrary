import Foundation
import AVFoundation

public class AudioManager {
    public static let shared = AudioManager()
    public static var callNumber = 0

    ///Best Practice:For the majority of apps, the best practice is to initialize AVAudioEngine once and use its methods to control its state throughout the app's lifecycle.
    private let audioEngine:AVAudioEngine
    
    init() {
        audioEngine = AVAudioEngine()        
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: nil) { notification in
            if self.audioEngine.isRunning {
                Logger.logger.log(self,"AVAudioEngineConfigurationChange, audio engine is RUNNING")
            } else {
                Logger.logger.log(self,"AVAudioEngineConfigurationChange, audio engine is STOPPED")
            }
        }
    }
    
    func getAudioEngine(_ ctx:String) -> AVAudioEngine {
        Logger.logger.log(self, "[\(ctx)] getAudioEngine")
        return self.audioEngine
    }
    
    func connectSampler(_ ctx:String, sampler:AVAudioUnitSampler) {
        Logger.logger.log(self, "[\(ctx)] Attach connectSampler then start audioEngine")
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        ///Cant start it until nodes are connected via this function
        do {
            try audioEngine.start()
        } catch {
            Logger.logger.reportError(self, "[\(ctx)] Could not start the audio engine: \(error)")
        }
    }
    
    public func setAudioSessionRecord(_ ctx:String) {
        ///An object that communicates to the system how you intend to use audio in your app.
        ///5Jan24 - Symptom was that after setting AVAudioSession back from recording to playback the AVSampler (e.g. notes) would sound silent
        ///So just setting it to playAndRecord just once and dont touch it again seems to correct the problem. playAndRecord  should handle everything required so no need to change session state.
        let attachedNodes = audioEngine.attachedNodes
        let audioSession = AVAudioSession.sharedInstance()
        if AudioManager.callNumber == 0 {
            do {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
                try audioSession.setActive(true)
                Logger.logger.log(self, "[\(ctx)] Set audio session record for first call and set session .playAndRecord, nodes:\(attachedNodes)")
            } catch {
                Logger.logger.reportErrorString("[\(ctx)] Setup AVAudioSession failed, nodes:\(attachedNodes)", error)
            }
        }
        else {
            Logger.logger.log(self, "[\(ctx)] Ignored set audio session record, nodes:\(attachedNodes), sessionCategory:\(audioSession.category)")
        }
        AudioManager.callNumber += 1
        if !audioEngine.isRunning {
            Logger.logger.reportErrorString("[\(ctx)] setAudioSessionRecord, audio engine not running")
        }
    }
    
    public func setAudioSessionPlayback(_ ctx:String) {
        let attachedNodes = audioEngine.attachedNodes
        let audioSession = AVAudioSession.sharedInstance()
        if AudioManager.callNumber == 0 {
            do {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
                try audioSession.setActive(true)
                Logger.logger.log(self, "[\(ctx)] Set audio session play for first call. Set .playAndRecord, nodes:\(attachedNodes)")
            } catch {
                Logger.logger.reportErrorString("[\(ctx)] Reset AVAudioSession failed, nodes:\(attachedNodes)", error)
            }
        }
        else {
            Logger.logger.log(self, "[\(ctx)] Ignored set audio session play, nodes:\(attachedNodes), sessionCategory:\(audioSession.category)")
        }
        AudioManager.callNumber += 1
        if !audioEngine.isRunning {
            Logger.logger.reportErrorString("[\(ctx)] setAudioSessionPlayback, audio engine not running")
        }
    }
}

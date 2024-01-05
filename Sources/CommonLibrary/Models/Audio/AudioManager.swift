import Foundation
import AVFoundation

public class AudioManager {
    public static let shared = AudioManager()
    ///5Jan24 - Symptom was that after setting AVAudioSession back from recording to playback the AVSampler (e.g. notes) would sound silent
    ///So just setting it to playAndRecord just once and dont touch it again seems to correct the problem. playAndRecord  should handle everything required so no need to change session state.
    public static var callNumber = 0

    ///Best Practice:For the majority of apps, the best practice is to initialize AVAudioEngine once and use its methods to control its state throughout the app's lifecycle.
    private let audioEngine:AVAudioEngine
    
    init() {
        audioEngine = AVAudioEngine()
    }
    
    func getAudioEngine() -> AVAudioEngine {
        return self.audioEngine
    }
    
    public func setAudioSessionRecord(_ ctx:String) {
        ///An object that communicates to the system how you intend to use audio in your app.
        if AudioManager.callNumber == 0 {
            let audioSession = AVAudioSession.sharedInstance()
            //print("=========== AudioEngineManager setAudioSessionRecord RECORD [\(ctx)]")
            do {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
                try audioSession.setActive(true)
            } catch {
                Logger.logger.reportErrorString("App init, setup AVAudioSession failed", error)
            }
        }
        AudioManager.callNumber += 1
    }
    
    public func setAudioSessionPlayback(_ ctx:String) {
        if AudioManager.callNumber == 0 {
            let audioSession = AVAudioSession.sharedInstance()
            //print("=========== AudioEngineManager RESETAudioSession to PLAYBACK [\(ctx)]")
            do {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
                try audioSession.setActive(true)
            } catch {
                Logger.logger.reportErrorString("App init, reset AVAudioSession failed", error)
            }
            
            //        let attachedNodes = audioEngine.attachedNodes
            //        for node in attachedNodes {
            //            node.reset()
            //        }
            //        //AudioSamplerPlayer.getShared().setup()
            //        if attachedNodes.count > 0 {
            //            audioEngine.stop()
            //            do {
            //                try audioEngine.start()
            //            } catch {
            //                print("Could not restart the audio engine: \(error)")
            //            }
            //        }
        }
        AudioManager.callNumber += 1
    }
}

import Foundation
import AVFoundation

public class AudioManager {
    public static let shared = AudioManager()
    
    ///Best Practice:For the majority of apps, the best practice is to initialize AVAudioEngine once and use its methods to control its state throughout the app's lifecycle.
    let audioEngine:AVAudioEngine
    
    init() {
        print("======== AudioManager init - new AVAudioEngine")
        audioEngine = AVAudioEngine()
    }
    
    public func setSession(_ cat:AVAudioSession.Category) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(cat, mode: .default)
            try audioSession.setActive(true)
        } catch {
            Logger.logger.reportErrorString("App init, setup AVAudioSession failed", error)
        }
    }
}

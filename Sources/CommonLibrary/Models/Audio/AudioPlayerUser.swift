import SwiftUI
import CoreData
import AVFoundation

///Subclass of any class using an audio player
public class AudioPlayerUser  {
    var parent:String
    var audioPlayer: AVAudioPlayer!
    let logger = Logger.logger
    
    init(parent:String) {
        self.parent = parent
    }
    
    public func stop() {
        if let audioPlayer = audioPlayer {
            audioPlayer.stop()
            let log = "Audio player stopped for user type \(parent)"
            self.audioPlayer = nil
            logger.log(self, log)
        }
    }
    
    public func play(data:Data) {
        do {
            let log:String
            if self.audioPlayer == nil {
                self.audioPlayer = try AVAudioPlayer(data: data)
                log = "Audio created in preparation for user type \(parent)"
            }
            else {
                self.audioPlayer!.stop()
                log = "Audio stopped in preparation for play for user type \(parent)"
            }
            logger.log(self, log)
            self.audioPlayer?.play()
            logger.log(self, "Audio playing for user type \(parent)")
        } catch {
            logger.reportError(self, "Audio player can't play data for user type \(parent)")
        }
    }
    
}

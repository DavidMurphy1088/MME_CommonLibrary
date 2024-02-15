//import Foundation
//import AVKit
//import AVFoundation
//
//public class AudioSamplerPlayer {
//    static private var shared = AudioSamplerPlayer()
//    //private var sampler:AVAudioUnitSampler
//    private var stopPlayingNotes = false
//        
//    static public func getShared() -> AudioSamplerPlayer {
//        return AudioSamplerPlayer.shared
//    }
//    
//    private init() {
//        //sampler = AudioManager.shared.getAVAudioUnitSampler("AudioSamplerPlayer.init()") //AVAudioUnitSampler()
//        //AudioManager.shared.connectSampler("AudioSamplerPlayer.init()", sampler: sampler)
//        //loadSoundFont()
//    }
//    
//
////    func playNotes(notes: [Note]) {
////        stopPlayingNotes = false
////        DispatchQueue.global(qos: .userInitiated).async { [self] in
////            let playTempo = 16.0
////            let pitchAdjust = 0
////            var n = 0
////            for note in notes {
////                if stopPlayingNotes {
////                    break
////                }
////                let dynamic:Double = 48
////                n += 1
////                if let sampler = AudioManager.shared.getMidiAudioUnitSampler() {
////                    sampler.startNote(UInt8(note.midiNumber + pitchAdjust), withVelocity:UInt8(dynamic), onChannel:0)
////                    //sampler.startNote(UInt8(note.midiNumber + pitchAdjust))
////                }
////                if stopPlayingNotes {
////                    break
////                }
////                let wait = playTempo * 50000.0 * Double(note.getValue())
////                usleep(useconds_t(wait))
////            }
////        }
////    }
//
//}
//

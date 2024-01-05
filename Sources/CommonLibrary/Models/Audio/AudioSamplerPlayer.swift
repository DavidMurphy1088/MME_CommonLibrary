import Foundation
import AVKit
import AVFoundation

public class AudioSamplerPlayer {
    static private var shared = AudioSamplerPlayer()
    private var sampler = AVAudioUnitSampler()
    private var stopPlayingNotes = false
        
    static public func getShared() -> AudioSamplerPlayer {
        return AudioSamplerPlayer.shared
    }
    
    private init() {
        sampler = AVAudioUnitSampler()
        setup()
    }
    
    func setup() {
        let audioEngine = AudioManager.shared.getAudioEngine()
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        print("AudioSamplerPlayer connected to AVAudioEngine")
        do {
            try audioEngine.start()
        } catch {
            Logger.logger.reportError(self, "Could not start the audio engine: \(error)")
        }
        loadSoundFont()
    }

//    static public func reset() {
//        let audioEngine = AudioManager.shared.audioEngine
//        audioEngine.disconnectNodeInput(getShared().sampler )
//        audioEngine.disconnectNodeOutput(getShared().sampler )
//        AudioSamplerPlayer.shared = AudioSamplerPlayer()
//    }
    
    public func getSampler() -> AVAudioUnitSampler {
        return sampler
    }
    
    private func loadSoundFont() {
        //https://www.rockhoppertech.com/blog/the-great-avaudiounitsampler-workout/#soundfont
        //https://sites.google.com/site/soundfonts4u/
        //let soundFontNames = [("Piano", "Nice-Steinway-v3.8")] //, ("Guitar", "GuitarAcoustic")]
        /// From https://www.producersbuzz.com/downloads/download-free-soundfonts-sf2/top-18-free-piano-soundfonts-sf2/
        let soundFontNames = [("Piano", "Piano")] //, ("Guitar", "GuitarAcoustic")]
        let samplerFileName = soundFontNames[0].1
        
        ///18May23 -For some unknown reason and after hours of investiagtion this loadSoundbank must oocur before every play, not just at init time
        
        if let url = Bundle.module.url(forResource: samplerFileName, withExtension: "sf2") {
            let ins = 0
            for instrumentProgramNumber in ins..<256 {
                do {
                    try sampler.loadSoundBankInstrument(at: url, program: UInt8(instrumentProgramNumber), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(kAUSampler_DefaultBankLSB))
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
        if sampler == nil {
            Logger.logger.reportError(self, "No soundfont loaded")
        }
    }
    
//    public func stopPlaying()  {
//        AudioSamplerPlayer.reset()
//        stopPlayingNotes = true
//    }
    
    public func play(note: UInt8) {
        sampler.startNote(note, withVelocity: 127, onChannel: 0)
    }

    func stop(note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
    }
    
    func playNotes(notes: [Note]) {
        stopPlayingNotes = false
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let playTempo = 16.0
            let pitchAdjust = 0
            var n = 0
            for note in notes {
                if stopPlayingNotes {
                    break
                }
                let dynamic:Double = 48
                n += 1
                sampler.startNote(UInt8(note.midiNumber + pitchAdjust), withVelocity:UInt8(dynamic), onChannel:0)
                if stopPlayingNotes {
                    break
                }
                let wait = playTempo * 50000.0 * Double(note.getValue())
                usleep(useconds_t(wait))
            }
        }
    }

}


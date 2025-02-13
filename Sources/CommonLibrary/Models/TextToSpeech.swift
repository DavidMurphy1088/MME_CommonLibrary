import Foundation
import AVFoundation
import SwiftSoup

public class TextToSpeech { //}: AudioPlayerUser {
    public static let shared = TextToSpeech()
    let googleAPI = GoogleAPI.shared
    var isSpeaking = false
    let dataCache = DataCache()
    var audioPlayer: AVAudioPlayer!
    let logger = AppLogger.logger
    
    public func stop() {
        if let audioPlayer = audioPlayer {
            audioPlayer.stop()
            //let log = "Audio player stopped for user type \(parent)"
            self.audioPlayer = nil
            //logger.log(self, log)
        }
        isSpeaking = false
    }
    
    func filterForSSML(_ input: String) -> String {
        return input.filter { char in
            //let validLowercase = Character("a") ... Character("z")
            //let validUppercase = Character("A") ... Character("Z")
            //return validLowercase.contains(char) || validUppercase.contains(char) || char == "."
            return char != "&"
        }
    }

    public func speakText(contentSection:ContentSection, context:String, htmlContent:String) {
        if isSpeaking {
            isSpeaking = false
            stop()
            return
        }
        isSpeaking = true
        let cacheKey = contentSection.getPath() + "/" + context
        ///5Nov2023 disable cache for the moment. TTS cache is not cleared (yet) by a change in the document text that it is reading
        ///e.g. a change in the cached Instructions.doc also requires that the the cache key for the TTS narration be cleared
        let data:Data? = nil //dataCache.getData(key: cacheKey)
        var playAudio = true
        if let data = data {
            playAudioData(data: data)
            if dataCache.hasCacheKey(cacheKey) {
                return
            }
            playAudio = false
        }

        let apiKey:String? = googleAPI.getAPIBundleData(key: "APIKey")
        //let apiKey:String? = nil
        let apiUrl = "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(apiKey ?? "")"
        //voices https://cloud.google.com/text-to-speech/docs/voices
        
        var ssmlContent = "<speak>"
        do {
            let doc: Document = try SwiftSoup.parse(htmlContent)
            let tags: Elements = try doc.select("p, h1")
            //var cnt = 0
            for tag in tags {
                try ssmlContent += filterForSSML(tag.text()) + "<break time=\"1000ms\"/>"
            }
        } catch Exception.Error(let type, let message) {
            AppLogger.logger.reportError(self, "Type: \(type), Message: \(message)")
        } catch {
            AppLogger.logger.reportError(self,"Error")
        }
        ssmlContent += "</speak>"

        let requestBody: [String: Any] = [
            "input": ["ssml": ssmlContent],
            "voice": ["languageCode": "en-US",
                      "name": "en-AU-Wavenet-A"],
            "audioConfig": ["audioEncoding": "MP3"]
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: requestBody, options: [])
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { [self] data, response, error in
            guard let data = data, error == nil else {
                logger.reportError(self, error?.localizedDescription ?? "Unknown")
                return
            }
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                    let audioContent = jsonResponse["audioContent"] as? String,
                    let audioData = Data(base64Encoded: audioContent) {
                    self.dataCache.setFromExternalData(key: cacheKey, data: audioData)
                    if playAudio {
                        self.playAudioData(data: audioData)
                    }
                }
                else {
                    logger.reportError(self, error?.localizedDescription ?? "Unknown")
                }
            } catch {
                logger.reportError(self, error.localizedDescription)
            }
        }
        task.resume()
    }
    
    public func playAudioData(data:Data) {
        do {
            //let log:String
            if self.audioPlayer == nil {
                self.audioPlayer = try AVAudioPlayer(data: data)
            }
            else {
                self.audioPlayer!.stop()
            }
            self.audioPlayer?.play()
        } catch {
            logger.reportError(self, "Audio player can't play data")
        }
    }

}

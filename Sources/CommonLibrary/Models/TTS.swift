import Foundation
import AVFoundation
import SwiftSoup

public class TTS : AudioPlayerUser {
    public static let shared = TTS(parent: "TTS")
    let googleAPI = GoogleAPI.shared
    var isSpeaking = false
    let dataCache = DataCache()
    
    public override func stop() {
        super.stop()
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
            play(data: data)
            if dataCache.hasCacheKey(cacheKey) {
                return
            }
            playAudio = false
        }
        guard let api = googleAPI else {
            Logger.logger.reportError(self,"No API")
            return
        }
        let apiKey:String? = api.getAPIBundleData(key: "APIKey")
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
            Logger.logger.reportError(self, "Type: \(type), Message: \(message)")
        } catch {
            Logger.logger.reportError(self,"Error")
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
                        self.play(data: audioData)
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
}

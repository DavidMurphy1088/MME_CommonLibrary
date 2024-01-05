import Foundation
import SwiftJWT
import Alamofire

public enum OAuthCallType {
    case file
    case filesInFolder
    case googleDoc
}

public enum RequestStatus {
    case success
    case waiting
    case failed
}

public class DataRequest {
    var callType:OAuthCallType
    var id:String
    var targetExampleKey: String?
    var url:String?
    var context:String
    
    init(callType:OAuthCallType, id:String, context:String, targetExampleKey:String?) {
        self.callType = callType
        self.id = id
        self.targetExampleKey = targetExampleKey
        self.context = context
    }
}

class DataCacheEntry {
    ///Loaded from UserDefaults or by an external data load
    var wasLoadedFromExternal:Bool
    var data:Data?
    
    init(wasLoadedFromExternal:Bool, data:Data?) {
        self.wasLoadedFromExternal = wasLoadedFromExternal
        self.data = data
    }
}

class DataCache {
    private var dataCache:[String:DataCacheEntry] = [:]
    private let enabled = true
    
    func showCaches() {
        print("\n----CACHES")
        for (key, value) in self.dataCache {
            print("  Cache - Key: \(key), Value: \(value)")
        }
//        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
//            print("  User def - Key: \(key), Value: \(value)")
//        }
    }
    
    func getCacheEntry(_ key:String) -> DataCacheEntry? {
        return self.dataCache[key]
    }

    func hasCacheKey(_ key:String) -> Bool {
        return self.dataCache.keys.contains(key)
    }

    func getData(key: String) -> Data? {
        if !enabled {
            return nil
        }
        else {
            if self.dataCache.keys.contains(key) {
                if let cacheEntry = self.dataCache[key] {
                    return cacheEntry.data
                }
                else {
                    return nil
                }
            }
            let data = UserDefaults.standard.data(forKey: key)
            self.dataCache[key] = DataCacheEntry(wasLoadedFromExternal: false, data: data)
            return data
        }
    }

    func setFromExternalData(key:String, data:Data?) {
        self.dataCache[key] = DataCacheEntry(wasLoadedFromExternal: true, data: data)
        UserDefaults.standard.set(data, forKey: key)
    }
    
}

public class GoogleAPI {
    public static let shared = GoogleAPI()
    let dataCache = DataCache()
    var accessToken:String?
    let logger = Logger.logger
    
    public struct GoogleFile : Codable {
        let name: String
        let id: String
        let kind:String
        let parents: [String]?
    }

    public init() {
    }
    
    public func getAPIBundleData(key:String) -> String? {
        guard let url = Bundle.module.url(forResource: "GoogleAPI", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else {
            logger.reportError(self, "Cannot find Google .plist")
            return nil
        }

        do {
            if let plistContent = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                if let value = plistContent[key] as? String {
                    return value
                }
                else {
                    logger.reportError(self, "no Google .plist value for \(key)")
                }
            }
        } catch {
            logger.reportError(self, "Cannot read Google .plist")
        }
        return nil
    }
    
    public func getContentSheet(sheetName:String, onDone: @escaping (_ status:RequestStatus, _ data:Data?) -> Void) {
        let sheetKey:String? = getAPIBundleData(key: sheetName)

        if let sheetKey = sheetKey {
            let request = DataRequest(callType: .file, id: sheetKey, context: "getExampleSheet", targetExampleKey: nil)
            var url:String
            url = "https://sheets.googleapis.com/v4/spreadsheets/"
            url +=  request.id
            url += "/values/Sheet1"
            request.url = url
            getByAPI(request: request) {status,data in
                onDone(.success, data)
            }
        }
        else {
            logger.reportError(self, "Cannot find example sheet id")
            onDone(.failed, nil)
        }
    }

    ///Call a Google Drive API (sheets etc) using an API key. Note that this does not require an OAuth2 token request.
    ///Data accessed via an API key only is regarded as less senstive by Google than data in a Google doc that requires an OAuth token
    private func getByAPI(request:DataRequest, onDone: @escaping (_ status:RequestStatus, _ data:Data?) -> Void) {
        
        if let key = request.targetExampleKey {
            let data = dataCache.getData(key: key)
            if let data = data {
                onDone(.success, data)
                if let entry = dataCache.getCacheEntry(key) {
                    if entry.wasLoadedFromExternal {
                        return
                    }
                }
            }
        }
        
        let apiKey:String? = getAPIBundleData(key: "APIKey")
        guard let apiKey = apiKey, let url = request.url else {
            logger.reportError(self, "Cannot find API key")
            onDone(.failed, nil)
            return
        }
        let urlWithKey = url + "?key=\(apiKey)"
        guard let url = URL(string: urlWithKey) else {
            logger.reportError(self, "Sheets, Invalid url \(url)")
            onDone(.failed, nil)
            return
        }
        let session = URLSession.shared
        let task = session.dataTask(with: url) { (data, response, error) in
            if let error = error {
                self.logger.reportError(self, "DataTask Error \(error.localizedDescription)")
                onDone(.failed, nil)
            } else if let httpResponse = response as? HTTPURLResponse {
                if let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    if httpResponse.statusCode == 200 {
                        guard let responseData = (responseString!).data(using: .utf8) else {
                            self.logger.reportError(self, "Invalid JSON data")
                            onDone(.failed, nil)
                            return
                        }
                        if let key = request.targetExampleKey {
                            self.dataCache.setFromExternalData(key: key, data: responseData)
                        }
                        onDone(.success, data)
                    }
                    else {
                        self.logger.reportError(self, "HTTP response code \(httpResponse.statusCode) \(responseString ?? "")")
                        onDone(.failed, nil)
                    }
                }
                else {
                    self.logger.reportError(self, "HTTP response, no data")
                    onDone(.failed, nil)
                }
            }
        }
        
        task.resume()
    }
    
    // ------------- OAuth Calls --------------
    
    ///A request for an OAuth2.0 access token is first required. The access token is sent along with all subsequent API calls
    ///The access token has an expiry - what is it??
    
    ///OAuth calls require that first an access key is granted. OAuth calls do not use the API key.
    ///OAuth authorization is managed by creating a Service Account in the Google Workspace and then generating a key for it
    ///The generated key is used to make the signed (by JWT) access token request

    func getAccessToken(onDone: @escaping (_ accessToken:String?) -> Void) {
        if self.accessToken != nil {
            onDone(accessToken)
            return
        }
        struct GoogleClaims: Claims {
            let iss: String
            let scope: String
            let aud: String
            let exp: Date
            let iat: Date
        }
        
        guard let projectEmail = self.getAPIBundleData(key: "projectEmail") else {
            self.logger.reportError(self, "No project email")
            return
        }

        let myHeader = Header(typ: "JWT")
        let myClaims = GoogleClaims(iss: projectEmail,
                                    scope: "https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/documents",
                                    aud: "https://oauth2.googleapis.com/token",
                                    exp: Date(timeIntervalSinceNow: 3600),
                                    iat: Date())
        var jwt = JWT(header: myHeader, claims: myClaims)
        struct PrivateKey: Codable {
            let private_key: String
        }

        var privateKey:String?
        let bundleName = "GoogleAPI_OAuth2_Keys"
        if let url = Bundle.module.url(forResource: bundleName, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let decode = try decoder.decode(PrivateKey.self, from: data)
                privateKey = decode.private_key
            } catch {
                self.logger.reportError(self, "Cannot find OAuth key")
                return
            }
        }
        guard let privateKey = privateKey  else {
            self.logger.reportError(self, "No private key")
            return
        }
        guard let privateKeyData = privateKey.data(using: .utf8) else {
            self.logger.reportError(self, "No private key data")
            return
        }
        var signedJWT = ""
        do {
            signedJWT = try jwt.sign(using: .rs256(privateKey: privateKeyData))
        } catch  {
            self.logger.reportError(self, "Cannot sign JWT \(error)")
            return
        }
        
        ///Request an OAUth2 token using the JWT signature
        ///Exchange the JWT token for a Google OAuth2 access token:
        ///The OAuth2 token is equired to access the API in the next step
            
        let headers: HTTPHeaders = ["Content-Type": "application/x-www-form-urlencoded"]
        
        let params: Parameters = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": signedJWT,
        ]
        
        let auth_url = "https://oauth2.googleapis.com/token"
     
        AF.request(auth_url,
                   method: .post,
                   parameters: params,
                   encoding: URLEncoding.httpBody,
                   headers: headers).responseJSON
        {response in
            
            switch response.result {
            case .success(let value):
                let json = value as? [String: Any]
                if let json = json {
                    let accessToken = json["access_token"] as? String
                    if let accessToken = accessToken {
                        onDone(accessToken)
                    }
                    else {
                        self.logger.reportError(self, "Cannot find access token: \(json)")
                    }
                }
                else {
                    self.logger.reportError(self, "Cannot load JSON")
                }
            case .failure(let error):
                self.logger.reportError(self, "Error getting access token: \(error)")
            }
        }
    }
    
    ///Drill down through all folders in the content section path to find the named file
    ///When its found return its data
    public func getDocumentByName(pathSegments:[String],
                           name:String,
                           reportError:Bool,
                           bypassCache:Bool?=false,
                           onDone: @escaping (_ status:RequestStatus, _ document:String?) -> Void)  {
        var cacheKey = ""
        for path in pathSegments {
            if path.count > 0 {
                cacheKey += path + "."
            }
        }
        cacheKey += name
        let bypass = bypassCache == true
        var log = false

        if name == "Parents" {
            log = true
        }
        if !bypass {
            ///If we get data from either cache or defaults return it, otherwise try once to load it externally
            let data = dataCache.getData(key: cacheKey)
            var loadedFromExternal = false
            if let entry = dataCache.getCacheEntry(cacheKey) {
                if entry.wasLoadedFromExternal {
                    loadedFromExternal = true
                }
            }

            if let data = data {
                if let document = String(data: data, encoding: .utf8) {
                    onDone(.success, document)
                }
                else {
                    onDone(.failed, nil)
                }
            }
            else {
                if loadedFromExternal {
                    //self.logger.reportError(self, "Document data - the cache for file:[\(name)] in path:[\(cacheKey)] was empty")
                    onDone(.failed, nil)
                }
            }
            ///If we have not tried an external load of the data load it now
            ///(Or if we have non nil data from UserDefaults but have not refreshed that data one time to check it has not changed)
            if loadedFromExternal {
                return
            }
        }
//        if log {
//            logger.log(self, "start load \(cacheKey)")
//        }
        let rootFolderId = getAPIBundleData(key: "GoogleDriveDataFolderID") //NZMEB
        guard let rootFolderId = rootFolderId else {
            self.logger.reportError(self, "No folder Id")
            return
        }
        
        var pathIndex = 0

        var folderId = rootFolderId
        DispatchQueue.global(qos: .background).async {
            while pathIndex < pathSegments.count + 1 {
                let semaphore = DispatchSemaphore(value: 0)
                if pathIndex == pathSegments.count {
                    self.getFileTextContentsByNameInFolder(folderId: folderId, name: name, reportError: reportError, onDone: {status, document in
                        semaphore.signal()
                        if log {
                            log = log
                        }
                        if let document = document {
                            self.dataCache.setFromExternalData(key: cacheKey, data: document.data(using: .utf8)!)
                            onDone(.success, document)
                        }
                        else {
                            if reportError {
                                self.logger.reportError(self, "No data for file:[\(name)] in path:[\(cacheKey)]")
                            }
                            self.dataCache.setFromExternalData(key: cacheKey, data: nil)
                            onDone(.failed, nil)
                        }
                    })
                    //getFileDataContentsByNameInFolder()
                }
                else {
                    self.getFileInFolder(folderId: folderId, name: pathSegments[pathIndex], onDone: {status, folder in
                        if let folder = folder {
                            folderId = folder.id
                        }
                        else {
                            if reportError {
                                self.logger.reportError(self, "Cannot find folder for path \(pathSegments[pathIndex]) for filename:\(name), key:\(cacheKey)")
                            }
                        }
                        semaphore.signal()
                    })
                }
                semaphore.wait()
                pathIndex += 1
            }
        }
    }
    
    func getAudioDataByFileName(pathSegments:[String],
                       fileName:String,
                       reportError:Bool,                                
                           onDone: @escaping (_ status:RequestStatus, _ fromCache:Bool, _ document:Data?) -> Void)  {
        var cacheKey = ""
        for path in pathSegments {
            if path.count > 0 {
                cacheKey += path + "."
            }
        }

        cacheKey += fileName
        let data:Data? = dataCache.getData(key: cacheKey)
        var loadedFromExternal = false
        if let entry = dataCache.getCacheEntry(cacheKey) {
            if entry.wasLoadedFromExternal {
                ///Data was loaded from internal cache
                loadedFromExternal = true
            }
        }

        if let data = data {
            onDone(.success, dataCache.hasCacheKey(cacheKey), data)
        }
        else {
            if loadedFromExternal {
                self.logger.reportError(self, "Audio data - the cache for file:[\(fileName)] in path:[\(cacheKey)] was empty")
                onDone(.failed, dataCache.hasCacheKey(cacheKey), nil)
            }
        }
        if loadedFromExternal {
            return
        }
        
        let rootFolderId = getAPIBundleData(key: "GoogleDriveDataFolderID") //NZMEB
        guard let rootFolderId = rootFolderId else {
            onDone(.failed, false, nil)
            self.logger.reportError(self, "No folder Id")
            return
        }
        
        var pathIndex = 0

        var folderId = rootFolderId
        DispatchQueue.global(qos: .background).async {
            while pathIndex < pathSegments.count + 1 {
                let semaphore = DispatchSemaphore(value: 0)
                if pathIndex == pathSegments.count {
                    let request = DataRequest(callType: .filesInFolder, id: folderId, context: "getDocumentByName.filesInFolder:\(fileName)", targetExampleKey: nil)
                    
                    self.getDataByID(request: request) { status, data in
                        let fileId = self.getFileIDFromName(name:fileName, reportError: reportError, data: data) //{status, data  in
                        if let fileId = fileId {
                            let request = DataRequest(callType: .file, id: fileId, context: "getFileDataByName:\(fileName)", targetExampleKey: nil)
                            self.getDataByID(request: request) { status, data in
                                if let data = data {
                                    self.dataCache.setFromExternalData(key: cacheKey, data: data)
                                    onDone(status, false, data)
                                }
                            }
                        }
                        else {
                            onDone(.failed, false, nil)
                            self.dataCache.setFromExternalData(key: cacheKey, data :nil)
                            self.logger.reportError(self, "filename:\(fileName) at key:\(cacheKey) does not exist")
                        }
                    }
                }
                else {
                    self.getFileInFolder(folderId: folderId, name: pathSegments[pathIndex], onDone: {status, folder in
                        if let folder = folder {
                            folderId = folder.id
                        }
                        else {
                            if reportError {
                                onDone(.failed, false, nil)
                                self.logger.reportError(self, "Cannot find folder for path \(pathSegments[pathIndex]) for filename:\(fileName), key:\(cacheKey)")
                            }
                        }
                        semaphore.signal()
                    })
                }
                semaphore.wait()
                pathIndex += 1
            }
        }
    }
    
    
    func getFileInFolder(folderId:String, name: String, onDone: @escaping (_ status:RequestStatus, _ file:GoogleFile?) -> Void) {

        let request = DataRequest(callType: .filesInFolder, id: folderId, context: "getAllFilesInFolder", targetExampleKey: nil)
        
        getDataByID(request: request) { status, data in
            if let data = data {
                struct FileSearch : Codable {
                      let kind:String
                      let files:[GoogleFile]
                }
                do {
                    let decoder = JSONDecoder()
                    let document = try decoder.decode(FileSearch.self, from: data)
                    for file in document.files {
                        if file.name.trimmingCharacters(in: .whitespacesAndNewlines) == name.trimmingCharacters(in: .whitespacesAndNewlines) {
                            onDone(.success, file)
                            return
                        }
                    }
                    onDone(.failed, nil)
                }
                catch  {
                    //let str = String(data: data, encoding: .utf8)
                    self.logger.reportError(self, "Cannot parse file names in the folder for file \(name)")
                    onDone(.failed, nil)
                }
            }
            else {
                self.logger.reportError(self, "Missing data for file name \(name)")
                onDone(.failed, nil)
            }
        }
    }
    
    func getFileTextContentsByNameInFolder(folderId:String, name:String, reportError: Bool,
                               onDone: @escaping (_ status:RequestStatus, _ document:String?) -> Void) {
        
        let request = DataRequest(callType: .filesInFolder, id: folderId, context: "getDocumentByName.filesInFolder:\(name)", targetExampleKey: nil)
        
        getDataByID(request: request) { status, data in
            let fileId = self.getFileIDFromName(name:name, reportError: reportError, data: data) //{status, data  in
            guard let fileId = fileId else {
                if reportError {
                    self.logger.reportError(self, "File name not found, name:[\(name)] in folderID:[\(folderId)]")
                }
                onDone(.failed, nil)
                return
            }
            //https://docs.google.com/document/d/1WMW0twPTy0GpKXhlpiFjo-LO2YkDNnmPyp2UYrvXItU/edit?usp=sharing
            let request = DataRequest(callType: .googleDoc, id: fileId, context: "getDocumentByName.readDocument:\(name)", targetExampleKey: nil)
            self.getDataByID(request: request) { status, data in
                if let data = data {
                    struct Document: Codable {
                        let body: Body
                    }

                    struct Body: Codable {
                        let content: [Content]
                    }

                    struct Content: Codable {
                        let paragraph: Paragraph?
                    }
                    
                    struct Paragraph: Codable {
                        let elements: [Element]
                    }
                                            
                    struct Element: Codable {
                        let textRun: TextRun
                    }
                    
                    struct TextRun: Codable {
                        let content: String
                    }

                    do {
                        let decoder = JSONDecoder()
                        let document = try decoder.decode(Document.self, from: data)
                        var textContent = ""
                        for content in document.body.content {
                            if let paragraph = content.paragraph {
                                for element in paragraph.elements {
                                    textContent += element.textRun.content
                                }
                            }
                        }
                        let data = textContent.data(using: .utf8)
                        if let data = data {
                            self.dataCache.setFromExternalData(key: name, data: data)
                            //self.dataCache[name] = data
                        }
                        onDone(.success, textContent)
                    }
                    catch  {
                        self.logger.reportError(self, "Cannot parse data in file:[\(name)]")
                        onDone(.failed, nil)
                    }
                }
            }
        }
    }
            
    func getFileIDFromName(name:String, reportError:Bool, data:Data?) -> String? {
        guard let data = data else {
            self.logger.reportError(self, "No data for file list for file:\(name)")
            return nil
        }
        struct GoogleFile : Codable {
            let name: String
            let id: String
            let parents: [String]?
        }
        struct FileSearch : Codable {
            let kind:String
            let files:[GoogleFile]
        }
        do {
            let filesData = try JSONDecoder().decode(FileSearch.self, from: data)
            for f in filesData.files {
                if f.name == name {
                    return f.id
                }
            }
            if reportError {
                self.logger.reportError(self, "File name \(name) not found in folder")
            }
        }
        catch {
            self.logger.reportError(self, "failed load")
        }
        return nil
    }

    ///Get data from Google API using the access token already received
    func getDataByID(request:DataRequest, onDone: @escaping (_ status:RequestStatus, _ data:Data?) -> Void) {
        getAccessToken() { accessToken in
            guard let accessToken = accessToken else {
                self.logger.reportError(self, "No access token")
                return
            }
            let headers: HTTPHeaders = ["Authorization": "Bearer \(accessToken)",
                                        "Accept": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
            
            let url:String?

            switch request.callType {
            case .file:
                url = "https://www.googleapis.com/drive/v3/files/\(request.id)?alt=media"
            case .filesInFolder:
                url = "https://www.googleapis.com/drive/v3/files?q='\(request.id)'+in+parents"
                //https://www.googleapis.com/drive/v3/files?q='<FOLDER_ID>'+in+parents

            case .googleDoc:
                url = "https://docs.googleapis.com/v1/documents/\(request.id)"
            }
            guard let url = url else {
                self.logger.reportError(self, "No URL for request")
                return
            }
            AF.request(url, headers: headers).response { response in
                switch response.result {
                case .success(let data):
                    if let data = data {
                        onDone(.success, data)
                    }
                    else {
                        self.logger.reportError(self, "File by ID has no data")
                    }
                case .failure(let error):
                    self.logger.reportError(self, "Error getting drive file by ID \(error.localizedDescription)")
                }
            }
        }
    }
    
}

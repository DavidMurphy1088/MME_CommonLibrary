

import Foundation

///Store data that is used many times but expensive to get (e.g. via the Google API)
///
class Cache {
    static let shared = Cache()
    var cache:[String:Data] = [:]
    
    func saveData(key:String, data:Data) {
        //UserDefaults.standard.set(data, forKey: key)
        cache[key] = data
    }
    
    func getData(key:String) -> Data? {
        //return UserDefaults.standard.data(forKey: key)
        return cache[key]
    }
    
    func clearCache() {
        cache = [:]
    }
}

import Foundation
import SwiftUI
import StoreKit

///https://developer.apple.com/documentation/storekit/in-app_purchase
///https://developer.apple.com/documentation/storekit/in-app_purchase/testing_at_all_stages_of_development_with_xcode_and_the_sandbox
/// subscriptions https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/subscriptions_and_offers/handling_subscriptions_billing

/// --- SUBSCRIPTIONS ---
/// - configured in App Store Connect
/// - app at start time sends the list of configured subscription product ids (requestProducts) to StoreKit
/// - ProductRequest didReceive recevies the list of subscription product ids that are purchasable

/// - the app lists those products for user to purchase
/// - on purchase app puts the product into the StoreKit payment queue
/// - StoreKit takes over and shows the product info and confirmation to buy it and a popup when all done
/// - Transaction arrives in the paymentQueue app observer paymentQueue(_ queue: SKPaymentQueue) as state purchasing, then state purchased
/// - On purchased app calls Apple API to verify that the transaction receipt is valid. That verification then returns a subscription expiry date
/// - App stores the receipt in its local storage since the tranaction will dispaper from the payment quueue soon

/// - On next startup the app retreives the receipt it last stored locally and again passes it to the Apple verification API to ensure the subscriptioin is still valid. e..g mayube the user cancelled the subscription after puchase
/// - When the subscription auto-renews it arrives in the payment Queue as .purchased and the app stores the receipt and new subscription expiry date.

///Notes
///- using a Sandbox test user a subscrioption is renewed just before the current one expires. (same as default live behaviour)
///- But can clear purchase history on Sandbox user - then when the app starts and verifies its locally stored transaction receipt that verification finds no expiry date. i.e. the content is then blocked as unlicenced.
///- Use Settings->App Store->SanboxAccount on iPad to set testing sandbox user

public class FreeLicenseUser:Hashable {
    public var email:String
    public var allowTest:Bool
    
    init(email:String, allowTest:Bool) {
        self.email = email
        self.allowTest = allowTest
    }
    
    public static func == (lhs: FreeLicenseUser, rhs: FreeLicenseUser) -> Bool {
        return lhs.email == rhs.email
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(email)
    }
}

///The subscription transaction receipt
///All dates are GMT
private class SubscriptionTransactionReceipt: Encodable, Decodable { //, Encodable,
    var expiryDate:Date
    let name:String
    let data:Data
    
    private static let storageKey = "subscription"
    
    init(name:String, data: Data, expiryDate:Date) {
        self.name = name
        self.data = data
        self.expiryDate = expiryDate
    }
    
    public func subscriptionDescription() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let gmtDateString = dateFormatter.string(from: expiryDate)
        dateFormatter.timeZone = TimeZone.current // Use the device's current time zone
        let localDateString = dateFormatter.string(from: expiryDate)
        return "\(name) Expiry - GMT:[\(gmtDateString)] LocalTimeZone:[\(localDateString)]"
    }
    
    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // Since your dates are in GMT, ISO8601 is a good choice
        do {
            let encodedData = try encoder.encode(self)
            UserDefaults.standard.set(encodedData, forKey: "subscription")
        } catch {
            Logger.logger.reportError(self, "Failed to encode SubscriptionReceipt: \(error)")
        }
    }
    
    static public func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static public func load() -> SubscriptionTransactionReceipt? {
        guard let encodedData = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let receipt = try decoder.decode(SubscriptionTransactionReceipt.self, from: encodedData)
            return receipt
        } catch {
            Logger.logger.reportError(self, "Failed to decode SubscriptionReceipt: \(error)")
            return nil
        }
    }
}

///Subscriptions
/// - configured in App Store Connect
/// - app sends list of configured subscription product ids to StoreKit and waits for
public class LicenceManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published public var purchaseableProducts:[String: SKProduct] = [:] ///Product id's that are returned from a product request to StoreKit
    @Published public var emailLicenses = Set<FreeLicenseUser>()
    @Published public var isInPurchasingState = false
    public static let shared = LicenceManager()
    //private let configuredProductIDs: Set<String> = ["NZMEB_Grade_1_2024", "NZMEB_Grade_2_2024", "NZMEB_Grade_3_2024", "NZMEB_Grade_4_2024", "MT_NZMEB_Grade_00"]
    private let configuredProductIDs: Set<String> = ["MT_NZMEB_Subscription_Month_6, MT_NZMEB_Subscription_Month_3, MT_NZMEB_Subscription_Month_12"] ///Product ID's that are known to the app
    //private let configuredProductIDs: Set<String> = ["MT_NZMEB_Subscription_Month_3"] ///Product ID's that are known to the app
    private let localSubscriptionStorageKey = "subscription"
    
    private override init() {
        super.init()
    }
    
    ///Load email licenses (e.g. teachers)
    public func loadEmailLicenses(sheetRows:[[String]]) {
        for rowCells in sheetRows {
            if rowCells.count < 5 {
                continue
            }
            if rowCells[0].hasPrefix("//")  {
                continue
            }
            let email = rowCells[1]
            let allowTest = rowCells[2] == "Y"
            DispatchQueue.main.async {
                self.emailLicenses.insert(FreeLicenseUser(email:email, allowTest: allowTest))
            }
        }
    }
    
    public func getNameOfStoredSubscription(email:String) -> String? {
        let iap = LicenceManager.shared
        if iap.emailIsLicensed(email: email) {
            return email
        }
        if let receipt = SubscriptionTransactionReceipt.load() {
            return receipt.subscriptionDescription()
        }
        return nil
    }
    
    public func emailIsLicensed(email:String) -> Bool {
        for user in self.emailLicenses {
            if user.email == email {
                return true
            }
        }
        return false
    }
    
    public func getLicenseUser(email:String) -> FreeLicenseUser? {
        for user in self.emailLicenses {
            if user.email == email {
                return user
            }
        }
        return nil
    }
    
//    ///Does the grade have a license to purchase?
//    public func isLicenseAvailable(grade:String) -> Bool {
//        if self.availableProducts.keys.contains("MT_NZMEB_Grade_00") {
//            return true
//        }
//        let now = Date()
//        let calendar = Calendar.current
//        let currentYear = calendar.component(.year, from: now)
//        let gradeToCheck = grade.replacingOccurrences(of: " ", with: "_")
//        for productId in self.availableProducts.keys {
//            if productId.contains(gradeToCheck) {
//                if productId.contains(String(currentYear)) {
//                    if availableProducts[productId] != nil {
//                        return true
//                    }
//                }
//            }
//        }
//        return false
//    }
    
    public func isLicenseAvailable(grade:String) -> Bool {
        return self.purchaseableProducts.keys.count > 0
    }
    
    ///Called at app startup to ask for the purchasable products defined for this app
    public func requestProducts() {
        Logger.logger.log(self, "Request purchaseable products from list of configured product IDs:\(configuredProductIDs)")
        let request = SKProductsRequest(productIdentifiers: configuredProductIDs)
        request.delegate = self
        request.start()
    }
    
    ///Load the licenses that are paid for
    ///Called at app startup
    public func restoreTransactions() {
        Logger.logger.log(self, "Restoring transactions")
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    

//    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
//        DispatchQueue.main.async {
//            Logger.logger.log(self, "Products request reply, availabe products count:\(response.products.count)")
//            for product in response.products {
//                self.availableProducts[product.productIdentifier] = product
//                Logger.logger.log(self, "  Available product ID:\(product.productIdentifier)")
//            }
//        }
//    }
    
    /// Response to requestProducts() - available products
    /// Sent immediately before -requestDidFinish
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            Logger.logger.log(self, "Products request reply, availabe products count:\(response.products.count)")
            if response.products.count > 0 {
                for product in response.products {
                    self.purchaseableProducts[product.productIdentifier] = product
                    Logger.logger.log(self, "  Available product ID:\(product.productIdentifier)")

                }
            } else {
                Logger.logger.reportError(self, "No products from product request")
            }
            
            if !response.invalidProductIdentifiers.isEmpty {
                for invalidIdentifier in response.invalidProductIdentifiers {
                    Logger.logger.reportError(self, "Invalid product \(invalidIdentifier)")
                }
            }
        }
    }

    ///Buy an In-App-Purchase for this grade for this calendar year
    public func buyProduct(grade: String) {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let gradeToBuy = grade.replacingOccurrences(of: " ", with: "_")
        
        let productId = "NZMEB_\(gradeToBuy)_\(String(currentYear))"
        Logger.logger.log(self, "BuyProduct, product id \(productId)")
        if let product = self.purchaseableProducts[productId] {
            Logger.logger.log(self, "BuyProduct is available, add queue, product id \(productId)")
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        }
    }    
    
    ///Buy a subscription
    public func buyProductSubscription(product: SKProduct) {
        Logger.logger.log(self, "BuyProductSubscription, product id \(product.productIdentifier)")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        Logger.logger.reportError(self, "didFailWithError", error)
    }
    
    ///Call Apple to verify the receipt and return the subscription expiry date
    func validateSubscriptionReceipt(ctx:String, receiptData: Data, onDone:@escaping (_:Date?)->Void) {
        let base64encodedReceipt = receiptData.base64EncodedString()
        let appSharedSecret = "1e1adf0415b046edbf2a1aa7e0d09d64" ///generated in App Store Connect under App Information
        let requestBody = ["receipt-data": base64encodedReceipt, "password": appSharedSecret, "exclude-old-transactions": true] as [String: Any]

        #if DEBUG
        guard let url = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt") else {
            return
        } //TODO
        #else        
        guard let url = URL(string: "https://buy.itunes.apple.com/verifyReceipt") else {
        return
        } //TODO
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
            request.httpBody = jsonData
        } catch {
            Logger.logger.reportError(self, "Error creating verification JSON request body: \(error). Context:\(ctx)")
            onDone(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.logger.reportError(self, "Receipt validation failed with error: \(error). Context:\(ctx)")
                onDone(nil)
                return
            }
            guard let data = data else {
                Logger.logger.reportError(self, "No receipt validation data received to verify. Context:\(ctx)")
                onDone(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let latestReceipts = json["latest_receipt_info"] as? [Any] {
                        //let log = "Validating subscription receipt for \(ctx)"
                        //Logger.logger.log(self, log)
                        for i in 0..<latestReceipts.count {
                            if let latestReceipt = latestReceipts[i] as? [String: Any] {
                               // print(latestReceipt.keys)
                                if let expiresDate = latestReceipt["expires_date"] as? String {
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'Etc/GMT'"
                                    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
                                    if let gmtDate = dateFormatter.date(from: expiresDate) {
                                        onDone(gmtDate)
                                    } else {
                                        Logger.logger.reportError(self, "Failed to parse licence date \(expiresDate). Context:\(ctx)")
                                        onDone(nil)
                                    }
                                }
                                else {
                                    Logger.logger.reportError(self, "Missing licence expiry date \(latestReceipt.keys). Context:\(ctx)")
                                    onDone(nil)
                                }
                            }
                        }
                    }
                    else {
                        Logger.logger.reportError(self, "Transaction verification returned no receipts. Context:\(ctx)")
                        onDone(nil)
                    }
                }
            } catch {
                Logger.logger.reportError(self, error.localizedDescription)
                onDone(nil)
            }
        }
        task.resume()
    }
    
    ///Get the receipt info from the subscription transaction when its purchased or renewed
    private func extractTransactionReceipt() -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: receiptURL.path) else {
            Logger.logger.reportError(self, "Receipt URL not found")
            return nil
        }
        do {
            let receiptData = try Data(contentsOf: receiptURL)
            return receiptData
        } catch {
            Logger.logger.reportError(self, "Error fetching receipt data in URL \(receiptURL) from transaction: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Store the receipt data locally for subscription expiry checking until the next subscription renewal
    func storeReceiptData(name:String, receiptData: Data) {
        self.validateSubscriptionReceipt(ctx: "Storing new receipt", receiptData: receiptData, onDone: {expiryDate in
            if let expiryDate = expiryDate {
                let subscription = SubscriptionTransactionReceipt(name:name, data: receiptData, expiryDate: expiryDate)
                subscription.save()
                Logger.logger.log(self, "Stored new receipt locally:\(subscription.subscriptionDescription())")
            }
            else {
                Logger.logger.reportError(self, "Receipt \(name) has no expiry date so clearing local storage")
                SubscriptionTransactionReceipt.clear()
            }
        })
    }
    
    ///Verify a subscription and save it if it has an expiry date. Otherwise clear any locally stored subscription.
    public func verifyStoredSubscription(ctx: String) {
        if let receipt = SubscriptionTransactionReceipt.load() {
            Logger.logger.log(self, "A stored subscription transaction exists so verifying it. Context:\(ctx)")
            self.validateSubscriptionReceipt(ctx: "Verifying stored subscription. Context:\(ctx)", receiptData: receipt.data, onDone: {expiryDate in
                if let expiryDate = expiryDate {
                    
                }
                else {
                    Logger.logger.log(self, "Stored subscription has no expiry date. Context:\(ctx)")
                    SubscriptionTransactionReceipt.clear()
                }
            })
        }
        else {
            Logger.logger.log(self, "No local subscription to verify. Context:\(ctx)")
            SubscriptionTransactionReceipt.clear()
        }
    }
    
    // SKPaymentTransactionObserver for purchased licenses and subscriptions. Called after product is purchased.
    ///For subscriptions the subscription only appears in the queue when the subscription is purchased or renewed.
    ///So the app must store the subscription receipt to be able to check that the subscription is still current.
    ///When a subscription is renewed the app must locally store the renewed subscription to ensure the subscription dates that the app checks are updated
    ///To determine the subscription expiry date the app must call Apple web API to verify the transaction receipt and that verification process then returns the subscription expiry date
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        //Logger.logger.log(self, "updatedTransactions")
        DispatchQueue.main.async {
            self.isInPurchasingState = false
            for transaction in transactions {
                switch transaction.transactionState {
                case .purchasing:
                    /// Transaction is being added to the server queue. Client should not complete the transaction.
                    Logger.logger.log(self, "Purchasing: \(transaction.payment.productIdentifier)")
                    self.isInPurchasingState = true
                case .purchased:
                    Logger.logger.log(self, "Purchased: \(transaction.payment.productIdentifier)")
                    //self.purchasedProductIds.insert(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                    if let receiptData = self.extractTransactionReceipt() {
                        self.storeReceiptData(name: transaction.payment.productIdentifier, receiptData: receiptData)
                    }
                case .restored:
                    /// Transaction was restored from user's purchase history.  Client should complete the transaction.
                    Logger.logger.log(self, "Purchased licenses restored from history: \(transaction.payment.productIdentifier)")
                    //self.purchasedProductIds.insert(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                    if let receiptData = self.extractTransactionReceipt() {
                        self.storeReceiptData(name: transaction.payment.productIdentifier, receiptData: receiptData)
                    }
                case .failed:
                    let err:String = transaction.error?.localizedDescription ?? ""
                    Logger.logger.reportError(self, "paymentQueue didFailWithError \(err)")
                    SKPaymentQueue.default().finishTransaction(transaction)
                default:
                    break
                }
            }
        }
    }

    func getStateName(_ st:SKPaymentTransactionState) -> (String, String) {
        var name = ""
        var desc = ""
        switch st {
        case .purchasing:
            name = "Purchasing..."
            desc = "Transaction is being added to the server queue."
        case .purchased:
            name = "Purchased"
            desc = "Transaction is in queue, user has been charged. Client should complete the transaction."
        case .failed:
            name = "Failed"
            desc = "Transaction was cancelled or failed before being added to the server queue."
        case .restored:
            name = "Restored"
            desc = "Transaction was restored from user's purchase history. Client should complete the transaction."
        case .deferred:
            name = "Deferred"
            desc = "The transaction is in the queue, but its final status is pending external action."
        default:
            break
        }
        return (name, desc)
    }
}

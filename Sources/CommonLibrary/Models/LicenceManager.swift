import Foundation
import SwiftUI
import StoreKit
import os
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
/// - App stores the receipt in its local storage since the transaction will dispaper from the payment queue soon

/// - On next startup the app retreives the receipt it last stored locally and again passes it to the Apple verification API to ensure the subscriptioin is still valid. e.g. maybe the user cancelled the subscription after puchase
/// - When the subscription auto-renews it arrives in the payment Queue as .purchased and the app stores the receipt and new subscription expiry date.
/// - note that we cannot store the subscription receipt along with its expiry. The expiry for any receit must be determined by a current time remote verification via Apple. e.g. the saved subscription was then leter cancelled.
///Notes
///- using a Sandbox test user a subscription is renewed just before the current one expires. (same as default live behaviour). Auto renewed subscriptions appear to the payment queue observer as a new purchase. (at which point the app will store the new subscription receipt
///- But can clear purchase history on Sandbox user - then when the app starts and verifies its locally stored transaction receipt that verification finds no expiry date. i.e. the content is then blocked as unlicenced.
///- Use Settings->App Store->SanboxAccount on iPad to set testing sandbox user
///- Subscriptions in the sandbox will auto-renew a maximum number of times (usually 6 for monthly subscriptions) before they automatically stop renewing, simulating the end of the subscription. 
///In sandbox testing (by design) -
///2-month subscriptions expire in about 5 minutes.
///3-month subscriptions expire in about 8 minutes.
///6-month subscriptions expire in about 15 minutes.
///1-year subscriptions expire in about 5 hours.
///23Feb2025 NB🟢 - since the list of subscriptions is hard coded adding a new one in App Store Connect wont automatically be picked up by the app.

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
public class SubscriptionTransactionReceipt: Encodable, Decodable { //, Encodable,
    public var expiryDate:Date
    let name:String
    let data:Data
    
    private static let storageKey = "subscription"
    
    init(name:String, data: Data, expiryDate:Date) {
        self.name = name
        self.data = data
        self.expiryDate = expiryDate
    }
    
    public func getDescription() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy h:mm a"
        dateFormatter.timeZone = TimeZone.current // Use the device's current time zone
        let localDateString = dateFormatter.string(from: expiryDate)
        return self.name + "\nexpiring " + localDateString
    }
    
    public func allDatesDescription() -> String {
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
            AppLogger.logger.reportError(self, "Failed to encode SubscriptionReceipt: \(error)")
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
            AppLogger.logger.reportError(self, "Failed to decode SubscriptionReceipt: \(error)")
            return nil
        }
    }
}

///Subscriptions
/// - configured in App Store Connect
/// - app sends list of configured subscription product ids to StoreKit and waits for
public class LicenceManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published public var purchaseableProducts:[String: SKProduct] = [:] ///Product id's that are returned from a product request to StoreKit
    var emailLicenses = Set<FreeLicenseUser>()
    @Published public var isInPurchasingState = false
    
    private let localSubscriptionStorageKey = "subscription"
    public static let shared = LicenceManager()
    public static var subscriptionURLLogged = false

    private let configuredProductIDs:[String] = ["MT_NZMEB_Subscription_Month_1", "MT_NZMEB_Subscription_Month_12"] ///Product ID's that are known to the app
    
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
            //DispatchQueue.main.async {
                self.emailLicenses.insert(FreeLicenseUser(email:email, allowTest: allowTest))
            //}
        }
    }
    
    public func emailIsLicensed(email:String) -> Bool {
        let toCheck:String = email.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for emailInList in self.emailLicenses {
            if emailInList.email.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) == toCheck {
                return true
            }
        }
        return false
    }
    
    public func getFreeLicenceUser(email:String) -> FreeLicenseUser? {
        for user in self.emailLicenses {
            if user.email == email {
                return user
            }
        }
        return nil
    }
    
    public func isLicenseAvailableToPurchase(grade:String) -> Bool {
        return self.purchaseableProducts.keys.count > 0
    }
    
    ///Called at app startup to ask for the purchasable products defined for this app
    public func requestProducts() {
        for product in self.configuredProductIDs {
            let requested:Set<String> = [product]
            //Logger.logger.log(self, "Request purchaseable products from list of configured product IDs:\(configuredProductIDs)")
            AppLogger.logger.log(self, "Request purchaseable products for configured product ID:\(requested)")
            //let request = SKProductsRequest(productIdentifiers: configuredProductIDs)
            let request = SKProductsRequest(productIdentifiers: requested)
            request.delegate = self
            request.start()
        }
    }
    
    ///Load the licenses that are paid for
    ///Called at app startup
    public func restoreTransactions() {
        AppLogger.logger.log(self, "Restoring transactions")
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    /// Response to requestProducts() - available products
    /// Sent immediately before -requestDidFinish
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            let logger = Logger(subsystem: "Musicianship Trainer", category: "debug")
            AppLogger.logger.log(self, "Products request reply, availabe products count:\(response.products.count)")
            logger.debug("MusTrainer, product identifier get list")
            if response.products.count > 0 {
                for product in response.products {
                    self.purchaseableProducts[product.productIdentifier] = product
                    logger.debug("MusTrainer, product identifier: \(product.productIdentifier)")
                }
            } else {
                AppLogger.logger.reportError(self, "No products from product request")
            }
            
            if !response.invalidProductIdentifiers.isEmpty {
                for invalidIdentifier in response.invalidProductIdentifiers {
                    AppLogger.logger.reportError(self, "Invalid product \(invalidIdentifier)")
                }
            }
        }
    }

    ///Buy a subscription
    public func buyProductSubscription(product: SKProduct) {
        AppLogger.logger.log(self, "BuyProductSubscription, product id \(product.productIdentifier)")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        AppLogger.logger.reportError(self, "didFailWithError", error)
    }
    
    ///Call Apple to verify the receipt and return the subscription expiry date
    func validateSubscriptionReceipt(ctx:String, receiptData: Data, onDone:@escaping (_:Date?)->Void) {
        func isTestFlight() -> Bool {
            guard let receiptURL = Bundle.main.appStoreReceiptURL else {
                return false
            }
            
            return receiptURL.lastPathComponent == "sandboxReceipt"
        }

        let base64encodedReceipt = receiptData.base64EncodedString()
        let appSharedSecret = "1e1adf0415b046edbf2a1aa7e0d09d64" ///generated in App Store Connect under App Information
        let requestBody = ["receipt-data": base64encodedReceipt, "password": appSharedSecret, "exclude-old-transactions": true] as [String: Any]
        
        ///To verify subscription receipts for an app running on TestFlight, you should use the following URL for the receipt validation
        ///if #debug is only true for an xcode run, not TestFlight
        ///https://sandbox.itunes.apple.com/verifyReceipt
        var url:URL? = nil
        #if DEBUG
        url = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")
        #else      
        if isTestFlight() {
            url = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")
        }
        else {
            url = URL(string: "https://buy.itunes.apple.com/verifyReceipt")
        }
        #endif

        // Use the function to adjust the validation URL at runtime

        guard let url = url else {
            AppLogger.logger.reportError(self, "No subscription validation URL was available")
            return
        }
        if !LicenceManager.subscriptionURLLogged {
            AppLogger.logger.log(self, "Subscription validation URL is \(url)")
            LicenceManager.subscriptionURLLogged = true
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
            request.httpBody = jsonData
        } catch {
            AppLogger.logger.reportError(self, "Error creating verification JSON request body: \(error). Context:\(ctx)")
            onDone(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.logger.reportError(self, "Receipt validation failed with error: \(error). Context:\(ctx)")
                onDone(nil)
                return
            }
            guard let data = data else {
                AppLogger.logger.reportError(self, "No receipt validation data received to verify. Context:\(ctx)")
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
                                        AppLogger.logger.reportError(self, "Failed to parse licence date \(expiresDate). Context:\(ctx)")
                                        onDone(nil)
                                    }
                                }
                                else {
                                    AppLogger.logger.reportError(self, "Missing licence expiry date \(latestReceipt.keys). Context:\(ctx)")
                                    onDone(nil)
                                }
                            }
                        }
                    }
                    else {
                        AppLogger.logger.log(self, "Transaction verification returned no receipts. Context:\(ctx)")
                        onDone(nil)
                    }
                }
            } catch {
                AppLogger.logger.reportError(self, error.localizedDescription)
                onDone(nil)
            }
        }
        task.resume()
    }
    
    ///Get the receipt info from the subscription transaction when its purchased or renewed
    private func extractTransactionReceipt() -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: receiptURL.path) else {
            AppLogger.logger.reportError(self, "Receipt URL not found")
            return nil
        }
        do {
            let receiptData = try Data(contentsOf: receiptURL)
            return receiptData
        } catch {
            AppLogger.logger.reportError(self, "Error fetching receipt data in URL \(receiptURL) from transaction: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Store the receipt data locally for subscription expiry checking until the next subscription renewal
    func storeSubscriptionReceipt(ctx:String, name:String, receiptData: Data) {
        self.validateSubscriptionReceipt(ctx: "Storing new receipt", receiptData: receiptData, onDone: {expiryDate in
            if let expiryDate = expiryDate {
                let subscriptionReceipt = SubscriptionTransactionReceipt(name:name, data: receiptData, expiryDate: expiryDate)
                subscriptionReceipt.save()
                AppLogger.logger.log(self, "Stored new receipt locally:\(subscriptionReceipt.allDatesDescription()), context:\(ctx)")
                subscriptionReceipt.expiryDate = expiryDate
                //LicenceManager.shared.setLicensedBySubscription(expiryDate: expiryDate)
            }
            else {
                AppLogger.logger.reportError(self, "Receipt \(name) has no expiry date so clearing local storage")
                SubscriptionTransactionReceipt.clear()
            }
        })
    }
    
    ///Verify a subscription and save it if it has an expiry date. Otherwise clear any locally stored subscription.
    public func verifyStoredSubscriptionReceipt(ctx: String) {
        if let receipt = SubscriptionTransactionReceipt.load() {
            AppLogger.logger.log(self, "A stored subscription transaction exists so verifying it. Context:\(ctx)")
            self.validateSubscriptionReceipt(ctx: "Verifying stored subscription. Context:\(ctx)", receiptData: receipt.data, onDone: {expiryDate in
                if let expiryDate = expiryDate {
                    AppLogger.logger.log(self, "Stored subscription transaction verified and so set app's licence expiry to:[\(receipt.allDatesDescription())], Context:\(ctx)")
                    receipt.expiryDate = expiryDate
                    //LicenceManager.shared.setLicensedBySubscription(expiryDate: expiryDate)
                }
                else {
                    AppLogger.logger.log(self, "Stored subscription has no expiry date. Context:\(ctx)")
                    SubscriptionTransactionReceipt.clear()
                }
            })
        }
        else {
            AppLogger.logger.log(self, "No local subscription to verify. Context:\(ctx)")
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
                    AppLogger.logger.log(self, "Purchasing: \(transaction.payment.productIdentifier)")
                    self.isInPurchasingState = true
                case .purchased:
                    AppLogger.logger.log(self, "Purchased: \(transaction.payment.productIdentifier) ")
                    //self.purchasedProductIds.insert(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                    if let receiptData = self.extractTransactionReceipt() {
                        self.storeSubscriptionReceipt(ctx: "paymentQueue.purchased", name: transaction.payment.productIdentifier, receiptData: receiptData)
                    }
                case .restored:
                    /// Transaction was restored from user's purchase history.  Client should complete the transaction.
                    let restored:SKPayment = transaction.payment
                    //print("==============>>>", restored.applicationUsername, restored)
                    AppLogger.logger.log(self, "Purchased licences restored from history: \(transaction.payment.productIdentifier)")
                    //self.purchasedProductIds.insert(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                    if let receiptData = self.extractTransactionReceipt() {
                        self.storeSubscriptionReceipt(ctx: "paymentQueue.restored",  name:transaction.payment.productIdentifier, receiptData: receiptData)
                    }
                case .failed:
                    let err:String = transaction.error?.localizedDescription ?? ""
                    AppLogger.logger.reportError(self, "paymentQueue.failed didFailWithError \(err) or the user cancelled the purchase")
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

import Foundation
import SwiftUI
import StoreKit

///https://developer.apple.com/documentation/storekit/in-app_purchase
///https://developer.apple.com/documentation/storekit/in-app_purchase/testing_at_all_stages_of_development_with_xcode_and_the_sandbox

public class IAPManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published public var availableProducts:[String: SKProduct] = [:] //[SKProduct]()
    @Published public var purchasedProductIds = Set<String>()
    @Published public var emailLicenses = Set<String>()
    @Published public var isInPurchasingState = false

    public static let shared = IAPManager()
    //private let productIDs: Set<String> = ["NZMEB_Grade_2_2024", "MT_NZMEB_Grade_1_2024", "MT_NZMEB_Grade2_2024", "MT_NZMEB_Grade_3_2024"]
    private let productIDs: Set<String> = ["NZMEB_Grade_1_2024", "NZMEB_Grade_2_2024", "NZMEB_Grade_3_2024"]

    private override init() {
        super.init()
        //SKPaymentQueue.default().add(self)
        //requestProducts()
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
            DispatchQueue.main.async {
                self.emailLicenses.insert(email)
            }
        }
    }
    
    ///Does the grade have a license to purchase?
    public func isLicenseAvailable(grade:String) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let gradeToCheck = grade.replacingOccurrences(of: " ", with: "_")
        for productId in self.availableProducts.keys {
            if productId.contains(gradeToCheck) {
                if productId.contains(String(currentYear)) {
                    if let product = availableProducts[productId] {
                        return true
                    }
                }
            }
        }
        return false
    }

    public func requestProducts() {
        print("=========IAPManager requestProducts", productIDs)
        let request = SKProductsRequest(productIdentifiers: productIDs)
        request.delegate = self
        request.start()
    }
    
    ///Load the licenses that are paid for
    public func restoreTransactions() {
        print("=========IAPManager restoreTransactions")
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    public func buyProduct(grade: String) {
        //_ product: SKProduct) {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let gradeToBuy = grade.replacingOccurrences(of: " ", with: "_")

        let productId = "NZMEB_\(gradeToBuy)_\(String(currentYear))"
        //print("============== buyProduct, product id", productId)
        if let product = self.availableProducts[productId] {
            //print("=========IAPManager buyProduct", productId, product)
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        }
    }

    /// Response to requestProducts() - avalable products
    /// Sent immediately before -requestDidFinish
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            //print("=========IAPManager  productsRequest response", request, response)
            for product in response.products {
                self.availableProducts[product.productIdentifier] = product
                Logger.logger.log(self, "Available licenseType \(product.productIdentifier)")
            }
        }
    }

    public func request(_ request: SKRequest, didFailWithError error: Error) {
        Logger.logger.reportError(self, "didFailWithError", error)
    }

    // SKPaymentTransactionObserver
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        //print("\n=========IAPManager  paymentQueue, updatedTransactions")
        DispatchQueue.main.async {
            self.isInPurchasingState = false
            for transaction in transactions {
//                print("  transaction", transaction.transactionState,
//                      "\tstate:", self.getStateName(transaction.transactionState).0,
//                      "\tdesc", transaction.description)
                
                switch transaction.transactionState {
                case .purchasing:
                    /// Transaction is being added to the server queue. Client should not complete the transaction.
                    //print("  -----> purchasing...", transaction.payment.productIdentifier)
                    self.isInPurchasingState = true
                    
                case .purchased:
                    Logger.logger.log(self, "Purchased: \(transaction.payment.productIdentifier)")
                    self.purchasedProductIds.insert(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                case .restored:
                    Logger.logger.log(self, "Restored from history: \(transaction.payment.productIdentifier)")
                    self.purchasedProductIds.insert(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
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

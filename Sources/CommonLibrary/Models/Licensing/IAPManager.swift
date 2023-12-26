
import Foundation
import SwiftUI
import StoreKit

public class IAPManager: NSObject, SKPaymentTransactionObserver {
    public static var shared:IAPManager? = nil
    
    public override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        print("=========paymentQueue")
        for transaction in transactions {
            switch transaction.transactionState {
                case .purchased:
                    // Handle the successful purchase
                    unlockPurchase(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                case .restored:
                    // Handle restored purchases
                    unlockPurchase(transaction.payment.productIdentifier)
                    SKPaymentQueue.default().finishTransaction(transaction)
                case .failed:
                    // Handle failed transaction
                    if let error = transaction.error as? SKError {
                        print("Transaction Failed: \(error.localizedDescription)")
                    }
                    SKPaymentQueue.default().finishTransaction(transaction)
                default:
                    break
            }
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        // Handle the error here
        print("=========paymentQueue Restore failed: \(error.localizedDescription)")
    }

    private func unlockPurchase(_ productIdentifier: String) {
        // Unlock content based on productIdentifier
    }

    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    private func unlockContent(_ productIdentifier: String) {
        // Unlock the content for the user
    }
}

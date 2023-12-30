import Foundation
import SwiftUI
import StoreKit

///https://developer.apple.com/documentation/storekit/in-app_purchase
///https://developer.apple.com/documentation/storekit/in-app_purchase/testing_at_all_stages_of_development_with_xcode_and_the_sandbox

public class IAPManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published var products: [SKProduct] = []
    public static let shared = IAPManager()
    //public var transactionState: SKPaymentTransactionState? = nil
    
    public override init() {
        print("=========IAPManager paymentQueue INIT()")
        super.init()
        //SKPaymentQueue.default().add(self)
    }
    
    ///Called to list the available products for UI display
    public func fetchProducts() {
        let productIDs: Set<String> = ["MT_NZMEB_Grade_1_2024", "MT_NZMEB_Grade_2_2024"]
        let request = SKProductsRequest(productIdentifiers: productIDs)
        request.delegate = self
        print("=========IAPManager fetchProducts()", "State:")
        request.start()
    }
    
    func fetchPurchases() {
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.add(self) // Ensure your app delegate conforms to SKPaymentTransactionObserver
        paymentQueue.restoreCompletedTransactions()
    }
    
    ///1)  paymentQueue is called with transaction
    ///2)  prompt appears from StoreKit to purchase the product
    ///3) in Sandbox purchase prompts for password for the Apple ID
    ///4) Get 'You are all set'
    public func buyProduct(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        print("=========IAPManager BuyProduct", "product:", product.localizedTitle)
        SKPaymentQueue.default().add(payment)
    }

    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
            print("=========IAPManager productsRequest", "products:", self.products.count)
            for p in self.products {
                print("  ", p.productIdentifier, p.localizedTitle, p.price)
            }
        }
    }
    
    func getStateName(_ st:SKPaymentTransactionState) -> (String, String) {
        var name = ""
        var desc = ""
        switch st {
        case .purchasing:
            name = "Purchasing"
            desc = "Transaction is being added to the server queue."
        case .purchased:
            name = "Purchased"
            desc = "Transaction is in queue, user has been charged.  Client should complete the transaction."
        case .failed:
            name = "Failed"
            desc = "Transaction was cancelled or failed before being added to the server queue."
        case .restored:
            name = "Restored"
            desc = "Transaction was restored from user's purchase history.  Client should complete the transaction."
        case .deferred:
            name = "Deferred"
            desc = "The transaction is in the queue, but its final status is pending external action."
        default:
            break
        }
        return (name, desc)
    }
    /// SKPaymentTransactionObserver. Called when user buys a product, after 'buyProduct'
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        print("=========IAPManager paymentQueue transactions:")
        for transaction in transactions {
            let st:SKPaymentTransactionState = transaction.transactionState
            print("  ==", st, st.rawValue)
            print("  transaction:", transaction.payment.productIdentifier,
                  "\tstate:", getStateName(transaction.transactionState).0,
                  "\tstate:", getStateName(transaction.transactionState).1,
                  transaction.payment.applicationUsername)
//            case purchasing = 0 // Transaction is being added to the server queue.
//
//            case purchased = 1 // Transaction is in queue, user has been charged.  Client should complete the transaction.
//
//            case failed = 2 // Transaction was cancelled or failed before being added to the server queue.
//
//            case restored = 3 // Transaction was restored from user's purchase history.  Client should complete the transaction.
//
//            @available(iOS 8.0, *)
//            case deferred = 4 // The transaction is in the queue, but its final status is pending external action.

            switch transaction.transactionState {
            case .purchased, .restored:
                // Handle successful transaction
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                // Handle failed transaction
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}


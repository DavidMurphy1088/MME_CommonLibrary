import Foundation
import SwiftUI
import StoreKit

public struct PurchaseLicenseView: View {
    @Environment(\.presentationMode) var presentationMode
    let contentSection:ContentSection
    @StateObject private var iapManager = IAPManager.shared
    
    public init(contentSection:ContentSection) {
        self.contentSection = contentSection
    }
    
    public var body: some View {
        VStack {
//            Text("NZMEB Musicianship Syllabus").foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/).font(.title).padding()
//            Text(contentSection.getPathTitle()).foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/).font(.title).padding()
//            Image("nzmeb_logo_transparent")
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(height: 300.0)

            Text("License Purchase").font(.title).padding()
            Text("Purchasing this license provides you with unlimited access to all practise examples and practise exams for \(contentSection.getPathTitle()) NZMEB Musicianship for calendar year 2024.").padding()
            
            NavigationView {
                List {
                    ForEach(iapManager.products, id: \.productIdentifier) { product in
                        VStack(alignment: .leading) {
                            Text(product.localizedTitle)
                                .font(.headline)
                            Text(product.localizedDescription)
                            Button("Buy for \(product.priceLocale.currencySymbol ?? "$")\(product.price)") {
                                iapManager.buyProduct(product)
                            }
                            .disabled(true)
                        }
                    }
                }
                .navigationTitle("In-App Purchases")
                .onAppear {
                    iapManager.fetchProducts()
                }
            }

            HStack {
//                Button(action: {
//                    presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("Purchase").padding()
//                }
//                Button(action: {
//                    presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("Restore Purchases").padding()
//                }
                Button(action: {
                    iapManager.fetchPurchases()
                }) {
                    Text("Fetch Completed Licenses").padding()
                }

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel").padding()
                }
            }
        }
    }
}

//
//struct ContentView: View {
//    @StateObject private var iapManager = IAPManager.shared
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(iapManager.products, id: \.productIdentifier) { product in
//                    VStack(alignment: .leading) {
//                        Text(product.localizedTitle)
//                            .font(.headline)
//                        Text(product.localizedDescription)
//                        Button("Buy for \(product.priceLocale.currencySymbol ?? "$")\(product.price)") {
//                            iapManager.buyProduct(product)
//                        }
//                    }
//                }
//            }
//            .navigationTitle("In-App Purchases")
//            .onAppear {
//                iapManager.fetchProducts()
//            }
//        }
//    }
//}
//

import Foundation
import SwiftUI
import StoreKit

public struct LicenseManagerView: View {
    @Environment(\.presentationMode) var presentationMode
    let contentSection:ContentSection
    let email:String
    @ObservedObject var iapManager = IAPManager.shared

    public init(contentSection:ContentSection, email:String) {
        self.contentSection = contentSection
        self.email = email
    }
    
    public var body: some View {
        VStack {
            Text("\(contentSection.getPathTitle()) License").font(.title).padding()
            if let license = iapManager.getLicense(grade: contentSection.name, email: email) {
                VStack {
                    Text("Your current license is ").padding()
                    Text("\(license)").font(.title).bold().foregroundColor(.green)
                }
                .padding()
                Text("This license provides you with unlimited access to all the practise examples and practise exams for \(contentSection.getPathTitle()) NZMEB Musicianship.").padding().padding().padding()
            }
            else {
                if iapManager.isLicenseAvailable(grade: contentSection.name) {
                    HStack {
                        Text("                  ").padding()
                        VStack {
                            Text("Access to some content is restricted without this license.").padding()
                            Text("Purchasing this license provides you with unlimited access to all the practise examples and practise exams for \(contentSection.getPathTitle()) NZMEB Musicianship.").padding()
                            Text("Product licenses are also available for registered music teachers. Please contact productsupport@musicmastereducation.co.nz for more details.").padding()                            
                        }
                        Text("                  ").padding()
                    }
                    if iapManager.isInPurchasingState {
                        Text("Purchase in process. Please standby...").foregroundColor(.green).padding()
                    }
                    else {
                        Button(action: {
                            iapManager.buyProduct(grade: contentSection.name)
                        }) {
                            Text("Purchase")
                                .font(.title)
                                .padding()
                        }
                    }
                }
                else {
                    Text("Sorry, no license is available yet")
                }
            }
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Dismiss")
                        .font(.title)
                        .padding()
                }
            }
        }
    }
}


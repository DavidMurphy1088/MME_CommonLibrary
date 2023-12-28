
import Foundation
import SwiftUI
import StoreKit

public struct PurchaseLicenseView: View {
    @Environment(\.presentationMode) var presentationMode
    let contentSection:ContentSection
    
    public init(contentSection:ContentSection) {
        self.contentSection = contentSection
    }
    
    public var body: some View {
        VStack {
            Text("NZMEB Musicianship Syllabus").foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/).font(.title).padding()
            Text(contentSection.getPathTitle()).foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/).font(.title).padding()
            Image("nzmeb_logo_transparent")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 300.0)
            //Spacer()

            Text("License Purchase").font(.title).padding()
            Text("Purchasing this license provides you with unlimited access to all practise examples and practise exams for Grade \(contentSection.getPathTitle()) Musicianship for calendar year 2024. The cost of the license is NZD $49.99.").padding()
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Purchase").font(.title).padding()
                }
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Restore Purchases").font(.title).padding()
                }
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel").font(.title).padding()
                }
            }
        }
    }
}



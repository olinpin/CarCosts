//
//  CarCostsApp.swift
//  CarCosts
//
//  Created by Oliver Hnát on 31.03.2026.
//

import SwiftUI
import CoreData

@main
struct CarCostsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

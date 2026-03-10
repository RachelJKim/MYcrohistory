//
//  MYcrohistoryApp.swift
//  MYcrohistory
//
//  Created by Rachel J.Kim on 3/9/26.
//

import SwiftUI
import SwiftData

@main
struct MYcrohistoryApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Memo.self, PinAnnotation.self])
    }
}

//
//  ContentView.swift
//  Shared
//
//  Created by Eliott Morgensztern on 24/07/2021.
//

import SwiftUI

struct ContentView: View {
    let metalViewController = MetalViewController()
    
    var body: some View {
        VStack {
            metalViewController
            #if os(iOS)
                .edgesIgnoringSafeArea(.all)
            #endif
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

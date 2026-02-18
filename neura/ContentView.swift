//
//  ContentView.swift
//  neura
//
//  Created by Iftekhar Anwar on 17/02/26.
//

import SwiftUI

struct ContentView: View {

    @State private var navigateTo: SignDestination? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Metal animated meadow — fullscreen, behind everything
                MeadowView()
                    .ignoresSafeArea()

                // Transparent sign labels + tap hit areas on top
                SignOverlay(navigateTo: $navigateTo)
            }
            .ignoresSafeArea()
            .navigationBarHidden(true)
            .navigationDestination(item: $navigateTo) { dest in
                switch dest {
                case .learnWords: LearnWordsView()
                case .letsDraw:   LetsDrawView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

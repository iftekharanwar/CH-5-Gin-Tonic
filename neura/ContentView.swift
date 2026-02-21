import SwiftUI

struct ContentView: View {

    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            } else {
                HomeView()
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
    }
}

#Preview {
    ContentView()
}

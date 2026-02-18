import SwiftUI

struct LetsDrawView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.38, green: 0.72, blue: 0.98)
                .ignoresSafeArea()

            Text("Hi")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BackButton { dismiss() }
                .padding(24)
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    LetsDrawView()
}

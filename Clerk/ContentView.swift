//
//  ContentView.swift
//  Clerk
//
//  Created by Yonatan Pepper on 01.06.25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("CLERK!")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        }
        .background(Image("AppBackground"))
        .padding()
    }
}

#Preview {
    ContentView()
}

//
//  AvatarView.swift
//  BillSplitter
//
//  Reusable avatar circle: colored background + first-letter initial.
//  Replaces 6+ duplicated avatar patterns across the app.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    let color: String
    var size: CGFloat = 44

    init(user: User, size: CGFloat = 44) {
        self.name  = user.name
        self.color = user.profileColor
        self.size  = size
    }

    init(name: String, color: String, size: CGFloat = 44) {
        self.name  = name
        self.color = color
        self.size  = size
    }

    private var fontSize: CGFloat {
        size * 0.4
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: color).opacity(0.2))
                .frame(width: size, height: size)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: color))
        }
    }
}

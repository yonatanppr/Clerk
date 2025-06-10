import SwiftUI

struct BreadcrumbView: View {
    let path: [FolderItem]
    // Called when a folder in the breadcrumb path (excluding the last item) is tapped.
    let onNavigate: (FolderItem) -> Void
    // Called when the dedicated "Root" or "Home" button is tapped.
    let onNavigateToRoot: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Dedicated "Home" button
                Button(action: onNavigateToRoot) {
                    Image(systemName: "house.fill")
                        .padding(.horizontal, 4) // Give it some space
                }
                .contentShape(Rectangle())

                ForEach(path.indices, id: \.self) { index in
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)

                    let folder = path[index]

                    // Don't make the last item in the path a button,
                    // as it represents the current folder.
                    if index == path.count - 1 {
                        Text(folder.name)
                            .fontWeight(.semibold) // Highlight the current folder
                            .padding(.horizontal, 4)
                    } else {
                        Button(action: {
                            onNavigate(folder)
                        }) {
                            Text(folder.name)
                                .padding(.horizontal, 4)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.vertical, 4) // Padding inside the scrollable content
            .padding(.horizontal) // Padding for the ends of the scrollable content
        }
        .frame(height: 30) // Give the breadcrumb bar a fixed height
        .background(Color(.systemGray6).opacity(0.7)) // Optional: background color
        .cornerRadius(8) // Optional: rounded corners
        // Outer padding will be handled by the parent view (FileSystemView)
    }
}

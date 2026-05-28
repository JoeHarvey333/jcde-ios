import SwiftUI

struct ProjectTerminalView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            NativeTerminalView(project: project)
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Projects")
                            }
                            .foregroundColor(Color(hex: "7B7BFF"))
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 10, height: 10)
                            Text(project.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }

                    if let urlString = project.url, let url = URL(string: urlString) {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Link("Open ↗", destination: url)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "7B7BFF"))
                        }
                    }
                }
                .background(Color(hex: "0E0E12"))
        }
        .preferredColorScheme(.dark)
    }
}


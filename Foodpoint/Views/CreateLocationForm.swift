import SwiftUI

struct CreateLocationForm: View {
    var onSave: (String, String) -> Void
    @State private var viewModel = CreateLocationFormViewModel()
    @Environment(\.dismiss) private var dismiss

    private let iconGridColumns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $viewModel.name, prompt: Text("Required"))
                    .onSubmit {
                        trySave()
                    }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Section("Icon") {
                    LazyVGrid(columns: iconGridColumns, spacing: 12) {
                        ForEach(CreateLocationFormViewModel.availableIcons, id: \.self) { icon in
                            Button {
                                viewModel.icon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(icon == viewModel.icon ? Color.white : Color.primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(icon == viewModel.icon ? Color.accentColor : Color.secondary.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        trySave()
                    }
                }
            }
        }
    }

    private func trySave() {
        if viewModel.save(onSave: onSave) {
            dismiss()
        }
    }
}

#Preview {
    CreateLocationForm { _, _ in }
}

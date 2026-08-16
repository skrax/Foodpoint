import SwiftUI

struct CreateLocationForm: View {
    var onSave: (String) -> Void
    @State private var viewModel = CreateLocationFormViewModel()
    @Environment(\.dismiss) private var dismiss

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
    CreateLocationForm { _ in }
}

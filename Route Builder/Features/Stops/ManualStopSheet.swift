import SwiftUI

struct ManualStopSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    let onSave: (String, String, String) -> Void

    private var canSave: Bool {
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                } footer: {
                    Text("Address is required. This stop stays on the device and is not in the address book.")
                }
            }
            .navigationTitle("Enter address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name, address, phone)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

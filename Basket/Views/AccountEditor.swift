import BasketCore
import SwiftUI

/// Sheet for adding a new account or editing an existing one.
struct AccountEditor: View {
    enum Mode {
        case add
        case edit(Account)
    }

    let mode: Mode
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var service: Service
    @State private var name: String
    @State private var address: String
    @State private var notificationsEnabled: Bool
    @State private var userAgent: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _service = State(initialValue: .slack)
            _name = State(initialValue: "")
            _address = State(initialValue: Service.slack.defaultURL?.absoluteString ?? "")
            _notificationsEnabled = State(initialValue: true)
            _userAgent = State(initialValue: "")
        case .edit(let account):
            _service = State(initialValue: account.service)
            _name = State(initialValue: account.name)
            _address = State(initialValue: account.url.absoluteString)
            _notificationsEnabled = State(initialValue: account.notificationsEnabled)
            _userAgent = State(initialValue: account.customUserAgent ?? "")
        }
    }

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    private var url: URL? { Account.normalizedURL(from: address) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                if isAdding {
                    Picker("Service", selection: $service) {
                        ForEach(Service.allCases) { service in
                            Label(service.displayName, systemImage: service.symbolName).tag(service)
                        }
                    }
                    .onChange(of: service) { _, newService in
                        address = newService.defaultURL?.absoluteString ?? ""
                    }
                } else {
                    LabeledContent("Service") {
                        Label(service.displayName, systemImage: service.symbolName)
                    }
                }

                TextField("Name", text: $name, prompt: Text(service == .custom ? "e.g. WhatsApp" : "e.g. Work, Personal, Client"))

                TextField("Address", text: $address, prompt: Text("https://…"))
                if !address.isEmpty && url == nil {
                    Text("Enter a web address, like chat.example.com")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Show notifications", isOn: $notificationsEnabled)

                Section {
                    TextField("User agent", text: $userAgent, prompt: Text("Default (Safari)"))
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Only change this if the site says your browser isn't supported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isAdding ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url == nil)
            }
            .padding()
        }
        .frame(width: 460)
    }

    private func save() {
        guard let url else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAgent = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        let agent = trimmedAgent.isEmpty ? nil : trimmedAgent

        switch mode {
        case .add:
            model.addAccount(Account(
                service: service,
                name: trimmedName,
                url: url,
                notificationsEnabled: notificationsEnabled,
                customUserAgent: agent
            ))
        case .edit(var account):
            account.name = trimmedName
            account.url = url
            account.notificationsEnabled = notificationsEnabled
            account.customUserAgent = agent
            model.updateAccount(account)
        }
        dismiss()
    }
}

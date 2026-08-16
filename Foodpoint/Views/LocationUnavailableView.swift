import SwiftUI

struct LocationUnavailableView : View {
    @State private var showForm = false
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ContentUnavailableView {
            Label("No Locations", systemImage: "tray.fill")
        } description: {
            Text("Locations you create appear here.")
        } actions: {
            Button("Create Location") {
                showForm = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showForm) {
            CreateLocationForm {
                newLocation in appState.addLocation(name: newLocation)
            }
        }
    }
}


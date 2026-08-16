import SwiftUI

struct LocationView: View {
    @State private var showForm = false
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.locations) { location in
                    NavigationLink {
                        LocationDetailView(locationID: location.id)
                    } label: {
                        Label(location.name, systemImage: location.icon)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showForm = true
                    }
                    label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                CreateLocationForm { name, icon in
                    appState.addLocation(name: name, icon: icon)
                }
            }
        }
    }
}

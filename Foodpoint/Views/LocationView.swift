import SwiftUI

struct LocationView: View {
    @State private var showForm = false
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if appState.locations.isEmpty {
            LocationUnavailableView()
        }
        else {
            NavigationStack {
                List {
                    ForEach(appState.locations, id: \.self) { loc in
                        Text(loc)
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
                    CreateLocationForm {
                        newLocation in appState.locations.append(newLocation)
                    }
                }
            }
        }
    }
}

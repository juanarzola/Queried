import SwiftUI
import SwiftData
import Queried

@MainActor @Observable
class ContentViewModel {
    @Queried
    var items: [Item] = []

    func updates(in container: ModelContainer) async {
        do {
            for try await currItems in items(
                FetchDescriptor(predicate: .true),
                in: container.mainContext
            ) {
                print("\(#function): Got \(currItems.count) items.")
            }
        } catch let error {
            print("\(#function): Error: \(error.localizedDescription)")
        }
    }
}

let task = Task { @MainActor in
    let viewModel = ContentViewModel()
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    await viewModel.updates(in: modelContainer)
}

// top level concurrency? no idea how.

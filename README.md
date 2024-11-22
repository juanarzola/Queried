# Queried (Experimental)

`@Queried` is a SwiftData macro applied to an array property of a `class` or `actor` that generates a function that auto-updates it with the latest values of a `FetchDescriptor`. This is intended to be used to populate arrays in non-view objects.

I intend to use this as a proof of concept of how non-View queries could be implemented. 

It uses an internal `SwiftData` notification that the `@Query` macro uses to update views. These may break in future `SwiftData` updates, so use this at your own risk!

Example (from [QueriedSample](https://github.com/juanarzola/QueriedSample)):

## Observing from background ModelContext

Because Queried relies on a container's mainContext updating, it won't automatically update
when another ModelContext updates the container. To work around this, manuall call 
`ModelContainer.postForcedMainContextUpdate` to update all @Queried queries 
after other ModelContexts finish their writes.

```swift
import SwiftUI
import SwiftData
import Queried

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

@MainActor @Observable
class ContentController {
    @Queried
    var items: [Item] = []

    // call this in a `.task()` in the view to keep ContentController up-to-date
    func updates(in container: ModelContainer) async {
        do {
            for try await currItems in itemsAsyncStream(
                FetchDescriptor(predicate: .true),
                in: container.mainContext
            ) {
               print("\(#function): Got \(currItems.count) items")
            }
        } catch let error {
            print("\(#function): Error: \(error.localizedDescription)")
        }
    }
}

@MainActor
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var controller = ContentController()

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(controller.items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .task {
            await controller.updates(in: modelContext.container)
        }

    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
            try! modelContext.save()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(controller.items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
```

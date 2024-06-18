# Queried (Experimental)

`@Queried` is a SwiftData macro applied to an array property of an object that generates a function that auto-updates it with the latest values of a FetchDescriptor. This is intended to be used to populate arrays in non-view objects.

I intend to use this as a proof of concept of how non-View queries could be implemented. 

It uses internal SwiftData notifications also used by SwiftData's @Query macro. These may break in future SwiftData updates, so use this at your own risk!

Example:

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
class ContentViewModel {
    @Queried
    var items: [Item] = []

    // call this in the view to keep ContentViewModel up-to-date
    func updates(in container: ModelContainer) async {
        do {
            for try await currItems in items(
                FetchDescriptor(predicate: .true),
                in: container.mainContext
            ) {
            }
        } catch let error {
            print("Things broke: \(error.localizedDescription)")
        }
    }
}

@MainActor
struct ContentView: View {
    // @Query private var items: [Item]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ContentViewModel = ContentViewModel()

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(viewModel.items) { item in
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
            await viewModel.updates(in: modelContext.container)
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
                modelContext.delete(viewModel.items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
```

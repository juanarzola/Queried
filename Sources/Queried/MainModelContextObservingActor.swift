//
//  File.swift
//  
//
//  Created by Juan Arzola on 7/27/24.
//

import Foundation
import SwiftData

/** 
 An actor that can observe updates in the mainContext - on each update the actor should use its own new
 `ModelContext` to re-fetch the descriptor if necessary.

 # Example Usage
```swift
actor NotificationManager: MainModelContextUpdateObserver {
    // Invoke this in a SwiftUI .task {} to start observing updates
    public func updates(in modelContainer: ModelContainer) async {
        let descriptor = FetchDescriptor<Item>(predicate: .true)
        await forEachMainContextUpdate(of: modelContainer, relevantTo: descriptor) {
            let modelContext = ModelContext(modelContainer)
            do {
                let items = try modelContext.fetch(descriptor)
                // do something with items in the actor
            } catch {
                // handle the error
            }
        }
    }
}
```
 */
public protocol MainModelContextObservingActor: Actor {

    /// Awaits all of the container's mainContext updates relevant to a fetch descriptor, performing action when they occur.
    func forEachMainContextUpdate<T: PersistentModel>(
        of modelContainer: ModelContainer,
        relevantTo descriptor: FetchDescriptor<T>,
        perform action: () async -> Void
    ) async;
}

public extension MainModelContextObservingActor {
    func forEachMainContextUpdate<T: PersistentModel>(
        of modelContainer: ModelContainer,
        relevantTo descriptor: FetchDescriptor<T>,
        perform action: () async -> Void
    ) async {
        for await _ in await modelContainer.mainContextUpdates(relevantTo: type(of: descriptor)) {
            await action()
        }
    }
}

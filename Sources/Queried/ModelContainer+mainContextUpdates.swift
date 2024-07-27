//
//  ModelContextAdditions.swift
//
//
//  Created by Juan Arzola on 7/27/24.
//

import Foundation
import SwiftData

extension ModelContainer {
    /**
     * An AsyncStream that observes updates in the mainContext. This is meant to be used in actors
     * @return An `AsyncStream` that emits an element each time there's an update in the main context for any `PersistentModel`s relevant to the  fetch descriptor that fetches `PersistentModel`s of type `T`.
     */
    @MainActor
    public func mainContextUpdates<T: PersistentModel>(
        relevantTo fetchDescriptorType: FetchDescriptor<T>.Type
    ) -> AsyncStream<Void> {
        return AsyncStream<Void> { continuation in
            let mainContext = mainContext
            Task {
                let center = NotificationCenter.default
                let notifications = center.notifications(
                    named: Notification.Name("NSObjectsChangedInManagingContextNotification"),
                    object: mainContext
                ).filter { notification in
                    guard let modelContext = notification.object as? ModelContext else {
                        return false
                    }
                    let deleted = modelContext.deletedModelsArray
                    let updated = modelContext.changedModelsArray
                    let inserted = modelContext.insertedModelsArray
                    let allUpdates = deleted + updated + inserted
                    let names = ["\(T.self)"]
                    let isRelevantUpdate = allUpdates.contains(where: { object in
                        names.contains { object.persistentModelID.entityName == $0 }
                    })
                    return isRelevantUpdate
                } .map { _ in }
                Task {
                    for await _ in notifications {
                        continuation.yield()
                    }
                    continuation.finish()
                }
            }
        }
    }
}


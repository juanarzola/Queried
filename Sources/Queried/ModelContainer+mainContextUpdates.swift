//
//  ModelContainer+mainContextUpdates.swift
//
//
//  Created by Juan Arzola on 7/27/24.
//

import SwiftData
import Foundation
@preconcurrency import Combine

extension ModelContainer {
    /**
     * An AsyncStream that observes updates in the mainContext.
     * @return An `AsyncStream` that emits an element each time there's an update in the main context for any `PersistentModel`s relevant to the  fetch descriptor that fetches `PersistentModel`s of type `T`.
     */
    @MainActor
    public func mainContextUpdates<T: PersistentModel>(
        relevantTo fetchDescriptorType: FetchDescriptor<T>.Type
    ) -> AsyncStream<Void> {
        mainContext.updates(relevantTo: fetchDescriptorType)
    }

    public func postForcedMainContextUpdate() {
        NotificationCenter.default.post(
            name: ModelContainer.mainContextForcedUpdate,
            object: self
        )
    }

    public static let mainContextForcedUpdate = Notification.Name("__MainContextForcedUpdate")
}

extension ModelContext {
    public func updates<T: PersistentModel>(
        relevantTo fetchDescriptorType: FetchDescriptor<T>.Type
    ) -> AsyncStream<Void> {
        return AsyncStream<Void> { continuation in
            let forcedUpdatePublisher = NotificationCenter.default.publisher(
                for: ModelContainer.mainContextForcedUpdate,
                object: self.container
            ).receive(on: DispatchQueue.main)
            let updatesPublisher = {
                // willSave only started working in iOS 18
                if #available(iOS 18, *) {
                    NotificationCenter.default.publisher(for: ModelContext.willSave, object: self)
                } else {
                    NotificationCenter.default.publisher(for: Notification.Name("NSObjectsChangedInManagingContextNotification"), object: self)
                }
            }()
            let cancellable = updatesPublisher.merge(with: forcedUpdatePublisher).sink { _ in
                continuation.finish()
            } receiveValue: { (notification) in
                if notification.name == ModelContainer.mainContextForcedUpdate {
                    continuation.yield()
                }
                guard let modelContext = notification.object as? ModelContext else {
                    return
                }
                let deleted = modelContext.deletedModelsArray
                let updated = modelContext.changedModelsArray
                let inserted = modelContext.insertedModelsArray
                let allUpdates = deleted + updated + inserted
                let names = ["\(T.self)"]
                let isRelevantUpdate = allUpdates.contains(where: { object in
                    names.contains { object.persistentModelID.entityName == $0 }
                })
                if isRelevantUpdate {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}

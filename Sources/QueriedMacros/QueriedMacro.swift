import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum QueriedMacroError: Error, CustomStringConvertible {
    case invalidLocation
    case invalidParentLocation
    case invalidVarType

    var description: String {
        switch self {
        case .invalidLocation:
            "Invalid macro location. Macro must must be used before an instance var."
        // currently not used because we need MacroExpansionContext's `lexicalContext` in Swift 6.0 to implement this.
        case .invalidParentLocation:
            "Invalid macro location. Macro must must be used in a `class` or an `actor`."
        case .invalidVarType:
            "Invalid var type. Macro should only be used on array vars."
        }
    }
}

public struct QueriedMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let decl = declaration.as(VariableDeclSyntax.self),
              let varDeclBinding = decl.bindings.first,
              decl.bindingSpecifier.text == "var"
        else {
            throw QueriedMacroError.invalidLocation
        }

        guard let arrayTypeSyntax = varDeclBinding.typeAnnotation?.type.as(ArrayTypeSyntax.self) else {
            throw QueriedMacroError.invalidVarType
        }
        let name = varDeclBinding.pattern
        let elementType = arrayTypeSyntax.element

        return [
            """
            func \(name)AsyncStream<T: \(elementType)>(_ descriptor: FetchDescriptor<T>, in modelContext: ModelContext) -> AsyncThrowingStream<[T], Error> {
                AsyncThrowingStream<[T], Error> { continuation in
                    let center = NotificationCenter.default
                    let notificationName: Notification.Name
                    if #available(iOS 18, *) {
                        notificationName = ModelContext.willSave
                    } else {
                        notificationName = Notification.Name("NSObjectsChangedInManagingContextNotification")
                    }
                    let notifications = center.notifications(named: notificationName, object: modelContext).filter { notification in
                        guard let modelContext = notification.object as? ModelContext else { return false }
                        let deleted = modelContext.deletedModelsArray
                        let updated = modelContext.changedModelsArray
                        let inserted = modelContext.insertedModelsArray
                        let allUpdates = deleted + updated + inserted
                        let names = ["\\(T.self)"]
                        let isRelevantUpdate = allUpdates.contains(where: { object in
                            names.contains { object.persistentModelID.entityName == $0 }
                        })
                        return isRelevantUpdate
                    }.map { _ in }

                    func refetch() throws -> [T] {
                        try modelContext.fetch(descriptor)
                    }
                    do {
                        let firstItems = try refetch()
                        self.\(name) = firstItems
                        continuation.yield(firstItems)
                    } catch let error {
                        self.\(name) = []
                        continuation.finish(throwing: error)
                        return
                    }
                    Task {
                        do {
                            for await _ in notifications {
                                let items = try refetch()
                                self.\(name) = items
                                continuation.yield(items)
                            }
                            continuation.finish()
                        } catch let error {
                            self.\(name) = []
                            continuation.finish(throwing: error)
                        }
                    }
                }
            }

            """
        ]
    }
}

@main
struct QueryUpdatesPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        QueriedMacro.self,
    ]
}

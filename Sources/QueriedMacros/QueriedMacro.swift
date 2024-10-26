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
            func \(name)AsyncStream<T: \(elementType)>(_ descriptor: FetchDescriptor<T>, in modelContext: ModelContext) -> AsyncThrowingStream<Void, Error> {
                AsyncThrowingStream<Void, Error> { continuation in
                    func refetch() throws -> [T] {
                        try modelContext.fetch(descriptor)
                    }
                    do {
                        let firstItems = try refetch()
                        self.\(name) = firstItems
                        continuation.yield()
                    } catch let error {
                        self.\(name) = []
                        continuation.finish(throwing: error)
                        return
                    }
                    let task = Task {
                        do {
                            for await _ in modelContext.updates(relevantTo: type(of: descriptor)) {
                                let items = try refetch()
                                self.\(name) = items
                                continuation.yield()
                            }
                            continuation.finish()
                        } catch let error {
                            self.\(name) = []
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
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

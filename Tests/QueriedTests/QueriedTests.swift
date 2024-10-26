#if canImport(QueriedMacros)

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MacroTesting

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.

import QueriedMacros

final class QueriedTests: XCTestCase {
    func testValidClassParent() throws {
        assertMacro(["Queried": QueriedMacro.self], record: false) {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                var items: [Item]
            }
            """
        } expansion: {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                var items: [Item]

                func itemsAsyncStream<T: Item>(_ descriptor: FetchDescriptor<T>, in modelContext: ModelContext) -> AsyncThrowingStream<Void, Error> {
                    AsyncThrowingStream<Void, Error> { continuation in
                        func refetch() throws -> [T] {
                            try modelContext.fetch(descriptor)
                        }
                        do {
                            let firstItems = try refetch()
                            self.items = firstItems
                            continuation.yield()
                        } catch let error {
                            self.items = []
                            continuation.finish(throwing: error)
                            return
                        }
                        let task = Task {
                            do {
                                for await _ in modelContext.updates(relevantTo: type(of: descriptor)) {
                                    let items = try refetch()
                                    self.items = items
                                    continuation.yield()
                                }
                                continuation.finish()
                            } catch let error {
                                self.items = []
                                continuation.finish(throwing: error)
                            }
                        }
                        continuation.onTermination = { _ in
                            task.cancel()
                        }
                    }
                }
            }
            """
        }
    }

    func testValidActorParent() throws {
        assertMacro(["Queried": QueriedMacro.self], record: false) {
            """
            @Model
            class Item {
            }
            actor MyActor {
                @Queried
                var items: [Item]
            }
            """
        } expansion: {
            """
            @Model
            class Item {
            }
            actor MyActor {
                var items: [Item]

                func itemsAsyncStream<T: Item>(_ descriptor: FetchDescriptor<T>, in modelContext: ModelContext) -> AsyncThrowingStream<Void, Error> {
                    AsyncThrowingStream<Void, Error> { continuation in
                        func refetch() throws -> [T] {
                            try modelContext.fetch(descriptor)
                        }
                        do {
                            let firstItems = try refetch()
                            self.items = firstItems
                            continuation.yield()
                        } catch let error {
                            self.items = []
                            continuation.finish(throwing: error)
                            return
                        }
                        let task = Task {
                            do {
                                for await _ in modelContext.updates(relevantTo: type(of: descriptor)) {
                                    let items = try refetch()
                                    self.items = items
                                    continuation.yield()
                                }
                                continuation.finish()
                            } catch let error {
                                self.items = []
                                continuation.finish(throwing: error)
                            }
                        }
                        continuation.onTermination = { _ in
                            task.cancel()
                        }
                    }
                }
            }
            """
        }
    }


    func testInvalidStructParent() throws {
    #if swift(>=6.0.0)
        assertMacro(["Queried": QueriedMacro.self]) {
            """
            @Model
            class Item {
            }
            struct MyViewModel {
                @Queried
                var items: [Item]
            }
            """
        } diagnostics: {
            """
            @Model
            class Item {
            }
            struct MyViewModel {
                @Queried
                ┬───────
                ╰─ 🛑 Invalid macro location. Macro must must be used in a `class` or an `actor`.
                var items: [Item]
            }
            """
        }
    #else
        throw XCTSkip("Cannot verify parent of macro expansion in Swift 5.0")
    #endif
    }

    func testInvalidType() throws {
        assertMacro(["Queried": QueriedMacro.self]) {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                var items: Item
            }
            """
        } diagnostics: {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                ┬───────
                ╰─ 🛑 Invalid var type. Macro should only be used on array vars.
                var items: Item
            }
            """
        }
    }

    func testInvalidPeer() throws {
        assertMacro(["Queried": QueriedMacro.self]) {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                func hello() {}
            }
            """
        } diagnostics: {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                ┬───────
                ╰─ 🛑 Invalid macro location. Macro must must be used before an instance var.
                func hello() {}
            }
            """
        }
    }

    func testInvalidLet() throws {
        assertMacro(["Queried": QueriedMacro.self]) {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                let items: [Item]
            }
            """
        } diagnostics: {
            """
            @Model
            class Item {
            }
            class MyViewModel {
                @Queried
                ┬───────
                ╰─ 🛑 Invalid macro location. Macro must must be used before an instance var.
                let items: [Item]
            }
            """
        }
    }

}

#endif

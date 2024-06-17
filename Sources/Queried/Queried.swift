// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(peer, names: arbitrary)
public macro Queried() = #externalMacro(module: "QueriedMacros", type: "QueriedMacro")

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(CodabilityMacros)
import CodabilityMacros

let testMacros: [String: Macro.Type] = [
    "Codability": CodabilityMacro.self
]
#endif

final class CodabilityTests: XCTestCase {
    func testMacro() throws {
#if canImport(CodabilityMacros)
        assertMacroExpansion(
            """
            @Codability
            struct Example {
                var foo: String
                var _bar: Int
                var _bar2: Int
                var bar: Int {
                    @storageRestrictions(initializes: _bar, _bar2)
                    init(value) { _bar = value; _bar2 = value }
                    get { _bar }
                    set { _bar = newValue }
                }
                var baz = "hello"
            }
            """,
            expandedSource: """
            struct Example {
                var foo: String
                var _bar: Int
                var _bar2: Int
                var bar: Int {
                    @storageRestrictions(initializes: _bar, _bar2)
                    init(value) { _bar = value; _bar2 = value }
                    get { _bar }
                    set { _bar = newValue }
                }
                var baz = "hello"

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    func decode<T: Decodable>(key: CodingKeys) throws -> T {
                        try container.decode(T.self, forKey: key)
                    }
                    self.foo = try decode(key: .foo)
                    self.bar = try decode(key: .bar)
                    self.baz = try decode(key: .baz)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(self.foo, forKey: .foo)
                    try container.encode(self.bar, forKey: .bar)
                    try container.encode(self.baz, forKey: .baz)
                }

                enum CodingKeys: String, CodingKey {
                    case foo
                    case bar
                    case baz
                }
            }

            extension Example: Codable {
            }
            """,
            macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }
}

import Codability
import Foundation
import Observation

@available(iOS 17, macOS 14, *)
@Codability
@Observable
final class Example {
	var foo: String
	var bar: Int
	var baz = "hello"
	
	init(foo: String, bar: Int, baz: String = "hello") {
		self.foo = foo
		self.bar = bar
		self.baz = baz
	}
}

if #available(iOS 17, macOS 14, *) {
	let example = Example(foo: "yes", bar: 42)
	example.bar = 69
	print(example)
	let raw = try JSONEncoder().encode(example)
	print(String(bytes: raw, encoding: .utf8)!)
	let decoded = try JSONDecoder().decode(Example.self, from: raw)
	print(decoded)
}

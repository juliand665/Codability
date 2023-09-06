@attached(extension, conformances: Codable)
// can't declare designated inits in an extension
@attached(member, names: named(init(from:)), named(encode(to:)), named(CodingKeys))
public macro Codability() = #externalMacro(module: "CodabilityMacros", type: "CodabilityMacro")

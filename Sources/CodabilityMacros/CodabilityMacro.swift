import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// TODO: opt-in/opt-out for individual properties
// TODO: rename individual properties
// TODO: init in extension for structs

public struct CodabilityMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = declaration.canonicalProperties()
        print("canonical properties:", properties)
        
        return [
            DeclSyntax(try InitializerDeclSyntax("init(from decoder: Decoder) throws") {
                "let container = try decoder.container(keyedBy: CodingKeys.self)"
                "func decode<T: Decodable>(key: CodingKeys) throws -> T { try container.decode(T.self, forKey: key) }"
                for property in properties {
                    "self.\(raw: property) = try decode(key: .\(raw: property))"
                }
            }),
            DeclSyntax(try FunctionDeclSyntax("func encode(to encoder: Encoder) throws") {
                "var container = encoder.container(keyedBy: CodingKeys.self)"
                for property in properties {
                    "try container.encode(self.\(raw: property), forKey: .\(raw: property))"
                }
            }),
            DeclSyntax(try EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
                for property in properties {
                    "case \(raw: property)"
                }
            }),
        ]
    }
    
	public static func expansion(
		of node: AttributeSyntax, 
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type): Codable") {}]
    }
}

extension DeclGroupSyntax {
    func canonicalProperties() -> [String] {
        let variableProperties = memberBlock.members
            .lazy
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .flatMap(\.bindings)
        
        var canonicalProperties: Set<String> = []
        var handledProperties: Set<String> = []
        for property in variableProperties {
            guard let identifier = property.identifier?.text else { continue }
            
            if let accessorBlock = property.accessorBlock {
                let initAccessor = accessorBlock.accessors
                    .as(AccessorDeclListSyntax.self)?
                    .first { $0.accessorSpecifier.text == "init" }
                guard let initAccessor else { continue }
                
                let attribute = initAccessor.attributes
                    .lazy
                    .compactMap { $0.as(AttributeSyntax.self) }
                    .first { $0.attributeName.trimmedDescription == "storageRestrictions" }
                guard let arguments = attribute?.arguments?.as(LabeledExprListSyntax.self) else { continue }
                
                let fieldNames = arguments
                    .items(labeled: "initializes")
                    .map { $0.expression.as(DeclReferenceExprSyntax.self)!.baseName.text }
                
                handledProperties.formUnion(fieldNames)
                canonicalProperties.subtract(fieldNames)
                canonicalProperties.insert(identifier)
            } else {
                guard handledProperties.insert(identifier).inserted else { continue }
                canonicalProperties.insert(identifier)
            }
        }
        return variableProperties.lazy.compactMap(\.identifier?.text).filter(canonicalProperties.contains)
    }
}

extension LabeledExprListSyntax {
    func items(labeled label: String) -> some Collection<Element> {
        var wasRightLabel = false // could do this statelessly with swift-algorithms thanks to reductions() but ehh
        return self.lazy.filter { arg in
            if let argLabel = arg.label {
                wasRightLabel = argLabel.trimmedDescription == label
            }
            return wasRightLabel
        }
    }
}

extension PatternBindingSyntax {
    var identifier: TokenSyntax? {
        pattern.as(IdentifierPatternSyntax.self)?.identifier
    }
}

@main
struct CodabilityPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
		CodabilityMacro.self,
    ]
}

import SwiftSyntax

extension ProtocolDeclSyntax {
    var myName: String {
        return self.name.text
    }
}

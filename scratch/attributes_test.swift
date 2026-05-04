import Foundation

let attributesDescription = "@_spi(Testing)\n  @_alwaysEmitIntoClient"
let spi = "@_spi"

print("Description: '\(attributesDescription)'")
print("Contains SPI: \(attributesDescription.contains(spi))")

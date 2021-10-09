//
// 


import Foundation
import WireCryptobox

/// sample client ID
let hardcodedClientId = EncryptionSessionIdentifier(userId: "1e9b4e18", clientId: "7a9eb715")

/// sample prekey
let hardcodedPrekey = "pQABAQUCoQBYIEIir0myj5MJTvs19t585RfVi1dtmL2nJsImTaNXszRwA6EAoQBYIGpa1sQFpCugwFJRfD18d9+TNJN2ZL3H0Mfj/0qZw0ruBPY="

/// Creates a temporary folder and returns its URL
func createTempFolder() -> URL {
    let url = URL(fileURLWithPath: [NSTemporaryDirectory(), UUID().uuidString].joined(separator: "/"))
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
    return url
}

func createEncryptionContext() -> EncryptionContext {
    let folder = createTempFolder()
    return EncryptionContext(path: folder)
}

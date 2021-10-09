// 
// 

import Foundation
import WireSystem

extension CBoxResult : Error {
    
    /// Throw if self represents an error
    func throwIfError() throws {
        guard self == CBOX_SUCCESS else {
            self.failIfCritical()
            throw self
        }
    }
    
    func failIfCritical() {
        if self == CBOX_PANIC || self == CBOX_INIT_ERROR {
            fatalError("Cryptobox panic")
        }
    }
}

extension CBoxResult: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        return String(describing: self)
    }
}

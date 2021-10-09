//
//

import WireUtilities

extension Data: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        return "<\(self.readableHash)>"
    }
}

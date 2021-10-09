// 
// 


import Foundation
import WireSystem

class _CBox : PointerWrapper {}



/**
 A cryptobox context that manages access to sessions, allowing the
 same sessions to be accessed by multuple processes in a safe way.
 Inside a process, only a single session context should be used.
 
 - note:
 In order to be used by multiple processes (see iOS extensions), cryptobox needs to lock the 
 directory with the key material as it works on it, so that no other process will touch it.
 
 This class introduces the concept of *encryption context*, similar to the concept of context in Core Data.
 A context must be used only from a single thread. Multiple contexts can refer to the same 
 directory on disk, locking the directory when needed so that they don't interfere with 
 each other.
 
 Conflicts and race conditions are avoided by loading from disk and saving to disk 
 every time a context it used, and locking around these operations. 
 This is slow, but extensions are not supposed to need to access 
 cryptobox very frequently.
 
 The intended use of this class is:
 
 1. Create context once, reuse the same context to avoid having to create/load identity 
    (which never changes once created, so no race condition other than during creation)
 2. use `perform:` with a block to create sessions, prekeys, encrypt and decrypt. 
    During the execution of the block, the directory is locked. 
    When decrypting, the decrypted data should be saved synchronously inside this block
    (e.g. in case of Core Data, should be inserted and immediately saved) to enforce it
    being saved before the session state is persisted later.
    If the decrypted data is not persisted, and there is a crash before the data is
    persisted, the data is lost forever as it can not be decrypted again once the session 
    is saved.
 3. When the block passed to `perform:` is completed, the sessions are persisted to disk.
    The lock is relased.
 */
public final class EncryptionContext : NSObject {
    
    /// What to do with modified sessions
    public enum ModifiedSessionsBehaviour {
        case save
        case discard
    }
    
    /// Underlying C-style implementation
    let implementation = _CBox()
    
    /// File directory with the implementation files
    let path : URL
    
    /// The latest created and still open session directory
    /// will be set to `nil` after calling `doneUsingSessions`
    fileprivate(set) var currentSessionsDirectory: EncryptionSessionsDirectory?
    
    /// Folder file descriptor
    fileprivate var fileDescriptor : CInt!
    
    /// Keeps track of how many times we enter a `perform` block,
    /// to allow re-entry
    fileprivate var performCount : UInt = 0
    
    // The maximum size of the end-to-end encrypted payload is defined by ZMClientMessageByteSizeExternalThreshold
    // It's currently 128KB of data. NOTE that this cache is shared between all sessions in an encryption context.
    fileprivate let cache = Cache<GenericHash, Data>(maxCost: 10_000_000, maxElementsCount: 100000)

    /// Opens cryptobox from a given folder
    /// - throws: CryptoBox error in case of lower-level error
    public init(path: URL) {
        let result = cbox_file_open((path.path as NSString).utf8String, &self.implementation.ptr)
        self.path = path
        super.init()
        if result != CBOX_SUCCESS {
            fatal("Failed to open cryptobox: ERROR \(result.rawValue)")
        }
        self.fileDescriptor = open(self.path.path, 0)
        if self.fileDescriptor <= 0 {
            fatal("Can't obtain FD for folder \(self.path)")
        }
        zmLog.debug("Opened cryptobox at path: \(path)")
    }
    
    deinit {
        // unlock
        self.releaseDirectoryLock()
        // close
        close(self.fileDescriptor)
        // close cbox
        cbox_close(implementation.ptr)
        zmLog.debug("Closed cryptobox at path: \(path)")

    }
    
}

// MARK: - Start and stop using sessions
extension EncryptionContext {
    
    
    /// Access sessions and other data in this context. While the block is executed,
    /// no other process can use sessions from this context. If another process or thread is already
    /// using sessions from a context with the same path, this call will block until the other process
    /// stops using sessions. Nested calls to this method on the same objects on the same
    /// thread are allowed.
    /// - warning: this method is not thread safe
    public func perform(_ block: (_ sessionsDirectory: EncryptionSessionsDirectory) -> () ) {
        self.acquireDirectoryLock()
        if self.currentSessionsDirectory == nil {
            self.currentSessionsDirectory = EncryptionSessionsDirectory(generatingContext: self,
                                                                        encryptionPayloadCache: cache)
        }
        performCount += 1
        block(self.currentSessionsDirectory!)
        performCount -= 1
        if 0 == performCount {
            self.currentSessionsDirectory = nil
        }
        self.releaseDirectoryLock()
    }
    
    fileprivate func acquireDirectoryLock() {
        if flock(self.fileDescriptor, LOCK_EX) != 0 {
            fatal("Failed to lock \(self.path)")
        }
        zmLog.debug("Acquired lock for cryptobox at path: \(self.path)")
    }
    
    fileprivate func releaseDirectoryLock() {
        if flock(self.fileDescriptor, LOCK_UN) != 0 {
            fatal("Failed to unlock \(self.path)")
        }
        zmLog.debug("Released lock for cryptobox at path: \(self.path)")
    }
}


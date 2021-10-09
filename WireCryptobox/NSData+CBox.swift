// 
// 


import Foundation

extension Data {
    
    /// Moves from a CBoxVector to this data
    /// During this call, the CBoxVector is freed
    static func moveFromCBoxVector(_ vector: OpaquePointer?) -> Data? {
        guard let vector = vector else { return nil }
        
        let data = cbox_vec_data(vector)
        let length = cbox_vec_len(vector)
        let finalData = Data(bytes: UnsafePointer<UInt8>(data!), count: length) // this ctor copies
        cbox_vec_free(vector)
        return finalData
    }
}

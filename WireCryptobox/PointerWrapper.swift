// 
// 


import Foundation

/** 
 This class is used to add type safety to C opaque pointers.
 Just subclass this class and add the subclass to all signatures

 E.g.
 ```
 class CStruct : PointerWrapper {}
 
 func foo(struct: CStruct) -> Int {
    return some_c_function(struct.ptr)
 }
 
 ```
 */
class PointerWrapper {
    var ptr : OpaquePointer? = nil
}

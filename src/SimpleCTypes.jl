"""
    SimpleCTypes.jl

This zero-dependency package provides some simple definitions of C types, especially:

- `CfuncPtr` for C function pointers
- `Carray` for fixed-size C arrays
- `Cunion` for C-style unions
"""
module SimpleCTypes

include("./function.jl")
include("./array.jl")
# include("./union.jl")

end # module CTypes

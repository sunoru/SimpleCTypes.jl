using Test
using SimpleCTypes

@testset "SimpleCTypes.jl" begin
    include("./function.jl")
    include("./array.jl")
end
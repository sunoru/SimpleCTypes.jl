using Test
using SimpleCTypes

@testset "C Union" begin
    FooUnion = @Cunion begin
        a::Int64
        b::Float64
        c::@Carray{Int16, 5}
    end 13

    @test sizeof(FooUnion) == 13

    fu = FooUnion(a=99999)
    @test fu.a == 99999
    @test fu.b == 4.9406e-319
    @test fu.c == Int16[-31073, 1, 0, 0, 0]
end

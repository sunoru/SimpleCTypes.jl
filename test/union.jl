using Test
using SimpleCTypes

@testset "C Union" begin
    FooUnion = @Cunion begin
        a::Int64
        b::Float64
        c::@Carray{Int16, 5}
    end 13
    @test sizeof(FooUnion) == 13
    @test fieldnames(FooUnion) ≡ (:a, :b, :c)
    @test fieldname(FooUnion, 1) ≡ :a
    @test Base.fieldindex(FooUnion, :b) == 2
    @test [fieldoffset(FooUnion, i) for i in 1:3] == zeros(Int, 3)
    @test fieldtypes(FooUnion) ≡ (Int64, Float64, @Carray{Int16, 5})
    @test fieldcount(FooUnion) == 3
    fu = FooUnion(a=99999)
    @test fu.a == 99999
    @test fu.b == 4.9406e-319
    @test fu.c == Int16[-31073, 1, 0, 0, 0]

    BarUnion = @Cunion begin
        a::@Cunion begin
            x::UInt64
            y::@Carray{UInt8, 8}
        end
        b::@Carray{UInt32, 2}
    end
    @test sizeof(BarUnion) == 8
    x = 0x0123456789abcdef
    bu = BarUnion(a=(;x=x))
    @test bu.a.x == x
    @test bu.a.y == UInt8[0xef, 0xcd, 0xab, 0x89, 0x67, 0x45, 0x23, 0x01]
    @test bu.b == UInt32[0x89abcdef, 0x01234567]
end

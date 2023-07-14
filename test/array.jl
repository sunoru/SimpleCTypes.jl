using Test
using SimpleCTypes

@testset "C Array" begin
    @test isbitstype(@Carray{Int, 8})

    a = ones(3, 2)
    aa = @Carray{Float64, 2, 3}(a)
    @test aa == ones(2, 3)
    @test sizeof(aa) == 3 * 2 * sizeof(Float64)

    struct Foo
        arr::@Carray{Float64, 4}
        matrix::@Carray{Int64, 2, 3, 4}
    end

    arr = rand(4)
    matrix = reshape(1:24, (4, 3, 2))
    # The conversion from `Array` to `CArray` should happen automatically.
    foo = Foo(arr, matrix)
    @test foo.matrix[1, 2, 2:4] == [6, 7, 8]
    @test isbitstype(Foo)
    @test sizeof(foo) == 4 * sizeof(Float64) + 2 * 3 * 4 * sizeof(Int64)
end

using Test
using SimpleCTypes

@testset "C Function" begin
    f(x) = 2x
    f_ptr, cf = @cfunc($f, Int, (Int,))
    @test f_ptr ≡ CfuncPtr{Int,Tuple{Int}}(cf)
    GC.@preserve cf begin
        @test f_ptr(3) == 6
        @test_throws ErrorException f_ptr()
        @test_throws ErrorException f_ptr(1, 2)
    end

    struct SomeStruct
        x::Int
        y::Int
        add::CfuncPtr{Int,Tuple{Int,Int}}
    end
    ff(ss::SomeStruct) = ss.add(ss.x, ss.y)

    add_ptr, _ = @cfunc(+, Int, (Int, Int))
    ss = SomeStruct(1, 2, add_ptr)
    @test ff(ss) == 3
    @test_throws MethodError SomeStruct(2, 3, f_ptr)

    function cmp(a, b)::Cint
        (a < b) ? -1 : ((a > b) ? +1 : 0)
    end

    # CFunction
    cmp_ptr, cmp_cf = @cfunc($cmp, Cint, (Ref{Cdouble}, Ref{Cdouble}))
    A = [1.3, -2.7, 4.4, 3.1]
    GC.@preserve begin
        @ccall qsort(
            A::Ptr{Cdouble},
            length(A)::Csize_t,
            sizeof(eltype(A))::Csize_t,
            cmp_ptr::CfuncPtr{Cint,Tuple{Ref{Cdouble},Ref{Cdouble}}}
        )::Cvoid
    end
    @test issorted(A)
end

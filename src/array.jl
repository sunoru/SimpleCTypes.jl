export Carray, @Carray

"""
    Carray{TElement,TDims,TNDims,TSize}

See `@Carray`.
"""
struct Carray{TElement,TDims<:Tuple,TNDims,TSize} <: AbstractArray{TElement,TNDims}
    data::NTuple{TSize,TElement}
    Carray{TElement,TDims,TNDims,TSize}(data::NTuple{TSize,TElement}) where {TElement,TDims,TNDims,TSize} =
        new{TElement,TDims,TNDims,TSize}(data)
    Carray{TElement,TDims,TNDims,TSize}(data) where {TElement,TDims,TNDims,TSize} =
        new{TElement,TDims,TNDims,TSize}(Tuple(data))
end

@generated function Carray{T,TDims}(data::AbstractArray{T}) where {T,TDims}
    TNDims = length(TDims.parameters)
    TSize = prod(TDims.parameters)
    quote
        t = Tuple(data)
        Carray{T,TDims,$TNDims,$TSize}(t)
    end
end
Carray{T}(data::AbstractArray{T}) where {T} = Carray{T,Tuple{reverse(size(data))...}}(data)
Carray(data::AbstractArray{T}) where {T} = Carray{T}(data)

"""
    @Carray{T,N1,N2,...}

A statically sized immutable C array type of type `T` and dimensions `N1`, `N2`, ...
It is a macro that expands to `Carray{T, Tuple{...,N2,N1}, N1*N2*...}`.

Note that:

- Since it is immutable, you need to use `@Carray(data)` to create a new array.
- To be consistent with C, the array is in column-major order.
- The index of the array still starts from 1.

# Examples

```julia
struct Foo
    arr::@Carray{Int64,4}
    matrix::@Carray{Int64,2,3,4}
end

arr = zeros(4)
matrix = ones(4,3,2)
# The conversion from `Array` to `CArray` happens automatically.
foo = Foo(arr, matrix)
```
"""
macro Carray(expr)
    expr isa Expr && expr.head ≡ :braces || return :(Carray($(esc(expr))))
    args = expr.args
    TElement = esc(args[1])
    TNDims = length(args) - 1
    TNDims == 0 && return :(Carray{$TElement})
    TDims = esc.(args[2:end])
    TSize = Expr(:call, :*, TDims...)
    :(Carray{$TElement,Tuple{$(TDims...)},$TNDims,$TSize})
end

Base.length(::Carray{<:Any,<:Tuple,<:Any,TSize}) where {TSize} = TSize
@generated function Base.size(::Carray{<:Any,TDims}) where {TDims}
    s = Tuple(TDims.parameters)
    :($s)
end
Base.eltype(::Carray{T}) where {T} = T
Base.convert(::Type{T}, t::Tuple) where {T<:Carray} = T(t)
Base.convert(::Type{T}, a::AbstractArray) where {T<:Carray} = T(a)
@generated Base.ndims(::Type{<:Carray{<:Any,TDims}}) where {TDims} = :($(length(TDims.parameters)))
Base.ndims(::T) where {T<:Carray} = ndims(T)

Base.IndexStyle(::Type{<:Carray}) = IndexCartesian()
Base.eachindex(ca::Carray) = CartesianIndices(size(ca))
Base.@propagate_inbounds @generated function Base.getindex(ca::Carray{T,TDims}, ind::CartesianIndex) where {T,TDims}
    s = Tuple(TDims.parameters)
    n = length(s)
    index_expr = Expr(
        :call, :+, 1,
        (
            :((ind.I[$i] - 1) * $(
                i < n ? s[i+1] : 1
            ))
            for i in 1:n
        )...
    )
    :(ca.data[$index_expr])
end
Base.@propagate_inbounds Base.getindex(ca::Carray, i1::Integer, I::Integer...) =
    ca[CartesianIndex(i1, I...)]

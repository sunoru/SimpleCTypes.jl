export Cunion, @Cunion

"""
    Cunion{TMemberNames,TMemberTypes,TSize}

See `@Cunion`.
"""
struct Cunion{TMemberNames,TMemberTypes<:Tuple,TSize}
    data::NTuple{TSize,UInt8}
    Cunion{TMemberNames,TMemberTypes,TSize}(
        data::NTuple{TSize,UInt8}
    ) where {TMemberNames,TMemberTypes,TSize} =
        new{TMemberNames,TMemberTypes,TSize}(data)
end
@generated function Cunion{TMemberNames,TMemberTypes,TSize}(; kwargs...) where {TMemberNames,TMemberTypes,TSize}
    TCunion = Cunion{TMemberNames,TMemberTypes,TSize}
    k = only(kwargs.parameters[4].parameters[1])
    T = membertype(TCunion, k)
    init = Expr(:tuple, (:(zero(UInt8)) for _ in 1:TSize)...)
    quote
        v = @inbounds kwargs[1]
        bytes = Ref($init)
        p = pointer_from_objref(bytes)
        GC.@preserve bytes begin
            unsafe_store!(Ptr{$T}(p), v)
        end
        $TCunion(bytes[])
    end
end
Cunion{TMemberNames,TMemberTypes,TSize}(x::NamedTuple) where {TMemberNames,TMemberTypes,TSize} =
    Cunion{TMemberNames,TMemberTypes,TSize}(; x...)
Base.convert(::Type{T}, x::NamedTuple) where {T<:Cunion} = T(x)

Base.fieldnames(::Type{<:Cunion{TMemberNames}}) where {TMemberNames} = TMemberNames
Base.fieldname(::Type{<:Cunion{TMemberNames}}, i::Integer) where {TMemberNames} = TMemberNames[i]
Base.fieldcount(::Type{<:Cunion{TMemberNames}}) where {TMemberNames} = length(TMemberNames)
function Base.fieldindex(::Type{<:Cunion{TMemberNames}}, name::Symbol) where {TMemberNames}
    for (i, n) in enumerate(TMemberNames)
        n == name && return i
    end
    error("Member $name not found in union")
end
function Base.fieldoffset(::Type{T}, i::Integer) where {T<:Cunion}
    i ≤ fieldcount(T) || throw(BoundsError(T, i))
    zero(UInt)
end
@generated function Base.fieldtypes(::Type{<:Cunion{<:Any,TMemberTypes}}) where {TMemberTypes}
    t = Tuple(TMemberTypes.parameters)
    :($t)
end
@inline @generated function membertype(
    ::Type{<:Cunion{TMemberNames,TMemberTypes}}, name::Symbol
) where {TMemberNames,TMemberTypes}
    types = TMemberTypes.parameters
    conds = Expr(:block)
    for (name, type) in zip(TMemberNames, types)
        name_symbol = QuoteNode(name)
        push!(conds.args, :($name_symbol ≡ name && return $type))
    end
    quote
        $conds
        error("Member $name not found in union")
    end
end

function Base.getproperty(u::T, name::Symbol) where {T<:Cunion}
    data = getfield(u, :data)
    TX = membertype(T, name)
    bytes = Ref(data)
    p = pointer_from_objref(bytes)
    GC.@preserve bytes begin
        unsafe_load(Ptr{TX}(p))
    end::TX
end

"""
    const MyUnion = @Cunion begin
        i::Int64
        f::Float64
        A::@Carray{Int32, 2}
        ...
    end [nbytes]

Declare a C union type with the specified members.
It can then be used to create instances like `MyUnion(i=1)` or `MyUnion(A=[1, 2])`.

Note that:

- The union instance is immutable, so you need to create a new instance to change its members.
- `nbytes` is the size of the union in bytes.
If not specified, it is computed automatically with the default alignment.
- Though "members" are different from "fields", generic functions like `fieldnames` and `fieldcount` are defined for unions.
"""
macro Cunion(body, nbytes=nothing)
    members = [
        let (name, type) = x.args
            (name, esc(type))
        end for x in body.args
        if x isa Expr && x.head == :(::)
    ]
    TMemberNames = tuple((name for (name, _) in members)...)
    TMemberTypes = :(Tuple{$((type for (_, type) in members)...)})
    max_size = :(let max_size = 0
        for T in Ts.parameters
            isbitstype(T) || throw(ArgumentError("Union member type must be a bitstype"))
            max_size = max(max_size, sizeof(T))
        end
        max_size
    end)
    TSize = if isnothing(nbytes)
        align = Sys.WORD_SIZE ÷ 8
        :(
            let align = $align
                nbytes = (max_size + align - 1) ÷ align * align
            end
        )
    else
        esc(nbytes)
    end
    :(
        let Ts = $TMemberTypes
            max_size = $max_size
            tsize = $TSize
            tsize ≥ max_size || throw(ArgumentError("Union size is too small"))
            Cunion{$TMemberNames,Ts,tsize}
        end
    )
end
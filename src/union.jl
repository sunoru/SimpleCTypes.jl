export Cunion, @Cunion
export membernames, membercount, membertype

struct Cunion{TMemberNames<:Tuple,TMemberTypes<:Tuple,TSize}
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

@generated function membernames(::Type{<:Cunion{TMemberNames}}) where {TMemberNames}
    t = Tuple(TMemberNames.parameters)
    :($t)
end
@generated function membercount(::Type{<:Cunion{TMemberNames}}) where {TMemberNames}
    len = length(TMemberNames.parameters)
    :($len)
end
@inline @generated function membertype(
    ::Type{<:Cunion{TMemberNames,TMemberTypes}}, name::Symbol
) where {TMemberNames,TMemberTypes}
    names = TMemberNames.parameters
    types = TMemberTypes.parameters
    conds = Expr(:block)
    for (name, type) in zip(names, types)
        name_symbol = QuoteNode(name)
        push!(conds.args, :($name_symbol ≡ name && return $type))
    end
    quote
        $conds
        error("Field $name not found in union")
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
    @Cunion begin
        i::Int64
        f::Float64
        A::@Carray{Int32, 2}
        ...
    end [nbytes]

Declare a C union type with the specified fields.
It can then be used to create instances like `MyUnion(i=1)` or `MyUnion(A=[1, 2])`.

Note that:

- The union instance is immutable, so you need to create a new instance to change its fields.
- `nbytes` is the size of the union in bytes.
If not specified, it is computed automatically with the default alignment.
"""
macro Cunion(body, nbytes=nothing)
    members = [
        let (key, typ) = x.args
            (key, esc(typ))
        end for x in body.args
        if x isa Expr && x.head == :(::)
    ]
    TMemberNames = Tuple{(member[1] for member in members)...}
    TMemberTypes = :(Tuple{$((member[2] for member in members)...)})
    max_size = :(
        max(
        $((:(sizeof($(member[2]))) for member in members)...)
    )
    )
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
        let ts = $TMemberTypes
            max_size = $max_size
            tsize = $TSize
            tsize ≥ max_size || throw(ArgumentError("Union size is too small"))
            Cunion{$TMemberNames,ts,tsize}
        end
    )
end
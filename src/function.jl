export CfuncPtr, @cfunc

"""
    CfuncPtr{TReturn, TArgs}

A strictly typed C function pointer.

To wrap a function, use `@cfunc`.
"""
struct CfuncPtr{TReturn,TArgs}
    ptr::Ptr{Cvoid}
    CfuncPtr{TReturn,TArgs}(ptr::Ptr) where {TReturn,TArgs} = new{TReturn,TArgs}(Ptr{Cvoid}(ptr))
    CfuncPtr{TReturn,TArgs}(cp::CfuncPtr) where {TReturn,TArgs} = new{TReturn,TArgs}(cp.ptr)
end
Base.pointer(cp::CfuncPtr) = cp.ptr
Base.convert(::Type{T}, cp::CfuncPtr) where {T<:Ptr} = T(pointer(cp))
Base.convert(::Type{T}, ptr::Ptr) where {T<:CfuncPtr} = T(ptr)

Base.cconvert(::Type{T}, cp::CfuncPtr) where {T<:Ptr} = T(pointer(cp))
Base.cconvert(::Type{CfuncPtr}, x) = error("Argument must be a pointer")
Base.unsafe_convert(::Type{<:CfuncPtr}, ptr::Ptr) = ptr

CfuncPtr{TReturn,TArgs}(cf::Base.CFunction) where {TReturn,TArgs} = CfuncPtr{TReturn,TArgs}(
    Base.unsafe_convert(Ptr{Cvoid}, cf)
)
@generated function (cp::CfuncPtr{TReturn,TArgs})(args...) where {TReturn,TArgs}
    len = length(args)
    len_targs = length(TArgs.parameters)
    if !(
        len == len_targs ||
        TArgs.parameters[end] isa Core.TypeofVararg &&
        len ≥ len_args - 1
    )
        error("The number of arguments does not match the number of parameters")
    end
    :(
        ccall(cp.ptr, $TReturn, ($(TArgs.parameters...),), $((:(args[$i]) for i in 1:len)...))
    )
end

"""
    cf_ptr, _ = @cfunc(f, ret, args)
    cf_ptr, cf = @cfunc(\$f, ret, args)

Same as `@cfunction`, but returns both the pointer and the `CFunction`.
You need to keep the `CFunction` alive.
"""
macro cfunc(name, ret, args)
    cf_expr = :(@cfunction($name, $ret, $args)) |> esc
    TReturn = ret |> esc
    TArgs = :(Tuple{$(args.args...)}) |> esc
    quote
        cf = $cf_expr
        $CfuncPtr{$TReturn,$TArgs}(
            cf
        ), cf
    end
end


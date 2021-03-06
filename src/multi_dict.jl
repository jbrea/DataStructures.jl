#  multi-value dictionary (multidict)

import Base: haskey, get, get!, getkey, delete!, pop!, empty!,
             insert!, getindex, length, isempty, iterate,
             keys, values, copy, similar,  push!,
             count, size, eltype, empty

struct MultiDict{K,V}
    d::Dict{K,Vector{V}}

    MultiDict{K,V}() where {K,V} = new{K,V}(Dict{K,Vector{V}}())
    MultiDict{K,V}(kvs) where {K,V} = new{K,V}(Dict{K,Vector{V}}(kvs))
    MultiDict{K,V}(ps::Pair{K,Vector{V}}...) where {K,V} = new{K,V}(Dict{K,Vector{V}}(ps...))
end

MultiDict() = MultiDict{Any,Any}()
MultiDict(kv::Tuple{}) = MultiDict()
MultiDict(kvs) = multi_dict_with_eltype(kvs, eltype(kvs))

multi_dict_with_eltype(kvs, ::Type{Tuple{K,Vector{V}}}) where {K,V} = MultiDict{K,V}(kvs)
function multi_dict_with_eltype(kvs, ::Type{Tuple{K,V}}) where {K,V}
    md = MultiDict{K,V}()
    for (k,v) in kvs
        insert!(md, k, v)
    end
    return md
end
multi_dict_with_eltype(kvs, t) = MultiDict{Any,Any}(kvs)

MultiDict(ps::Pair{K,V}...) where {K,V<:AbstractArray} = MultiDict{K, eltype(V)}(ps)
MultiDict(kv::AbstractArray{Pair{K,V}}) where {K,V}  = MultiDict(kv...)
function MultiDict(ps::Pair{K,V}...) where {K,V}
    md = MultiDict{K,V}()
    for (k,v) in ps
        insert!(md, k, v)
    end
    return md
end

## Functions

## Most functions are simply delegated to the wrapped Dict

@delegate MultiDict.d [ haskey, get, get!, getkey,
                        getindex, length, isempty, eltype,
                        iterate, keys, values]

sizehint!(d::MultiDict, sz::Integer) = (sizehint!(d.d, sz); d)
copy(d::MultiDict) = MultiDict(d)
empty(d::MultiDict{K,V}) where {K,V} = MultiDict{K,V}()
==(d1::MultiDict, d2::MultiDict) = d1.d == d2.d
delete!(d::MultiDict, key) = (delete!(d.d, key); d)
empty!(d::MultiDict) = (empty!(d.d); d)

@deprecate similar(d::MultiDict) empty(d)

function insert!(d::MultiDict{K,V}, k, v) where {K,V}
    if !haskey(d.d, k)
        d.d[k] = isa(v, AbstractArray) ? eltype(v)[] : V[]
    end
    if isa(v, AbstractArray)
        append!(d.d[k], v)
    else
        push!(d.d[k], v)
    end
    return d
end

function in(pr::(Tuple{Any,Any}), d::MultiDict{K,V}) where {K,V}
    k = convert(K, pr[1])
    v = get(d,k,Base.secret_table_token)
    (v !== Base.secret_table_token) && (isa(pr[2], AbstractArray) ? v == pr[2] : pr[2] in v)
end

function pop!(d::MultiDict, key, default)
    vs = get(d, key, Base.secret_table_token)
    if vs === Base.secret_table_token
        if default !== Base.secret_table_token
            return default
        else
            throw(KeyError(key))
        end
    end
    v = pop!(vs)
    (length(vs) == 0) && delete!(d, key)
    return v
end
pop!(d::MultiDict, key) = pop!(d, key, Base.secret_table_token)

push!(d::MultiDict, kv::Pair) = insert!(d, kv[1], kv[2])
#push!(d::MultiDict, kv::Pair, kv2::Pair) = (push!(d.d, kv, kv2); d)
#push!(d::MultiDict, kv::Pair, kv2::Pair, kv3::Pair...) = (push!(d.d, kv, kv2, kv3...); d)

push!(d::MultiDict, kv) = insert!(d, kv[1], kv[2])
#push!(d::MultiDict, kv, kv2...) = (push!(d.d, kv, kv2...); d)

count(d::MultiDict) = length(keys(d)) == 0 ? 0 : mapreduce(k -> length(d[k]), +, keys(d))
size(d::MultiDict) = (length(keys(d)), count(d::MultiDict))

# enumerate

struct EnumerateAll
    d::MultiDict
end
enumerateall(d::MultiDict) = EnumerateAll(d)

length(e::EnumerateAll) = count(e.d)

function iterate(e::EnumerateAll)
    V = eltype(eltype(values(e.d)))
    vs = V[]
    dstate = iterate(e.d.d)
    vstate = iterate(vs)
    dstate === nothing || vstate === nothing && return nothing
    k = nothing
    while vstate === nothing
        ((k, vs), dst) = dstate
        dstate = iterate(e.d.d, dst)
        vstate = iterate(vs)
    end
    v, vst = vstate
    return ((k, v), (dstate, k, vs, vstate))
end

function iterate(e::EnumerateAll, s)
    dstate, k, vs, vstate = s
    dstate === nothing || vstate === nothing && return nothing
    while vstate === nothing
        ((k, vs), dst) = dstate
        dstate = iterate(e.d.d, dst)
        vstate = iterate(vs)
    end
    v, vst = vstate
    return ((k, v), (dstate, k, vs, vstate))
end

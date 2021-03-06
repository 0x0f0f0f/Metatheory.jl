using DataStructures
using Base.Meta

import Base.ImmutableDict

const EClassId = Int64

# struct ENode{T, M}
mutable struct ENode{T}
    head::Any
    args::Vector{EClassId}
    # metadata::M
    # the nodes where it came from 
    # proof_src::Vector{Tuple{Rule, ENode, Int}}
    # the enodes that were generated by this enode
    # proof_trg::Vector{Tuple{Rule, ENode, Int}}
    # age of the egraph when this enode was created
    # age::Int
    hash::Ref{UInt} # hash cache
end

# function ENode{T}(head, c_ids::AbstractVector{EClassId}, ps=[], pt=[], age=0) where {T}
function ENode{T}(head, c_ids::AbstractVector{EClassId}) where {T}
        # static_args = MVector{length(c_ids), Int64}(c_ids...)
    # m = metadata(e)
    # ENode{T}(head, c_ids, ps, pt, age, Ref{UInt}(0))
    ENode{T}(head, c_ids, Ref{UInt}(0))
end

ENode(a) = ENode{typeof(a)}(a, EClassId[])


ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")

function Base.:(==)(a::ENode, b::ENode)
    isequal(a.args, b.args) && 
    isequal(a.head, b.head)
end

# ===============================================================
# proof functions 
# ===============================================================

# function setage!(n::ENode, age::Int)
#     n.age = age
# end

# function addproofsrc!(n::ENode{T}, rule::Rule, src::ENode, age::Int) where {T}
#     push!(n.proof_src, (rule, src, age))
# end

# function addprooftrg!(n::ENode{T}, rule::Rule, trg::ENode, age::Int) where {T}
#     push!(n.proof_trg, (rule, trg, age))
# end

# function hasproofdata(n::ENode)
#     !(isempty(n.proof_src) && isempty(n.proof_trg)) 
# end

# function mergeproof!(target::ENode, source::ENode)
#     append!(target.proof_src, source.proof_src)
#     append!(target.proof_trg, source.proof_trg)
# end


# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENode{T}, salt::UInt) where {T}
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    # h′ = hash(t.args,  hash(t.metadata, hash(t.head, hash(T, salt))))
    h′ = hash(t.args,  hash(t.head, hash(T, salt)))
    t.hash[] = h′
    return h′
end

TermInterface.arity(n::ENode) = length(n.args)
# TermInterface.metadata(n::ENode) = n.metadata

termtype(x::ENode{T}) where T = T

function Base.show(io::IO, x::ENode{T}) where {T}
    print(io, "ENode{$T}(", x.head)
    n = arity(x)
    if n == 0
        print(io, ")")
        return
    else
        print(io, " ")
    end
    for i ∈ 1:n
        if i < n
            print(io, x.args[i], " ")
        else
            print(io, x.args[i], ")")
        end
    end
end

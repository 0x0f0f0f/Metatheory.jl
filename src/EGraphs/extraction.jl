"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
astsize(n) = 1
astsize(n::Expr) = 1 + length(n.args) - (Meta.isexpr(n, :call) ? 1 : 0)

const CostData = Dict{Int64, Tuple{Any, Number}}

struct ExtractionAnalysis <: AbstractAnalysis
    egraph::EGraph
    costfun::Function
    data::CostData
end

ExtractionAnalysis(g::EGraph, costfun::Function) =
    ExtractionAnalysis(g, costfun, CostData())

make(a::ExtractionAnalysis, n) = (n, a.costfun(n))

function make(an::ExtractionAnalysis, n::Expr)
    start = Meta.isexpr(n, :call) ? 2 : 1
    ncost = an.costfun(n)

    for child_eclass ∈ n.args[start:end]
        if haskey(an, child_eclass) && an[child_eclass] != nothing
            ncost += last(an[child_eclass])
        end
    end

    return (n, ncost)
end

function join(analysis::ExtractionAnalysis, from, to)
    last(from) <= last(to) ? from : to
end

modify!(analysis::ExtractionAnalysis, id::Int64) = nothing

Base.setindex!(an::ExtractionAnalysis, value, id::Int64) =
    setindex!(an.data, value, id)
Base.getindex(an::ExtractionAnalysis, id::Int64) = an.data[id]
Base.haskey(an::ExtractionAnalysis, id::Int64) = haskey(an.data, id)
Base.delete!(an::ExtractionAnalysis, id::Int64) = delete!(an.data, id)


function rec_extract(G::EGraph, an::ExtractionAnalysis, id::Int64)
    println(an[id])
    (cn, ck) = an[id]
    !(cn isa Expr) && return cn

    expr = copy(cn)
    start = Meta.isexpr(cn, :call) ? 2 : 1
    expr.args[start:end] = map(expr.args[start:end]) do a
        rec_extract(G, an, a.id)
    end
    return expr
end

extract!(G::EGraph, extran::ExtractionAnalysis) = begin
    rec_extract(G, extran, G.root)
end

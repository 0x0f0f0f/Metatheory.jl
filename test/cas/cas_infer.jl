using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.Classic
using Metatheory.Util
using Metatheory.EGraphs.Schedulers

@metatheory_init ()

abstract type TypeAnalysis <: AbstractAnalysis end

# This should be auto-generated by a macro
function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENode{T}) where T
    if !(T == Expr)
        if arity(n) == 0
            t = typeof(n.head)
            # other informed type checks on variables should go here
            if n.head == :im
                t = typeof(im)
            end
        else
            # unknown type for CAS
            t = Any
        end
        # println("analyzed type of $n is $t")
        return t
    end

    if !(n.head == :call)
        # println("$n is not a call")
        t = Any
        # println("analyzed type of $n is $t")
        return t
    end

    # T isa Expr
    sym = extract!(g, astsize; root=n.args[1])
    rest_of_args = (@view n.args[2:end])

    if !(sym isa Symbol)
        # println("head $sym is not a symbol")
        t = Any
        # println("analyzed type of $n is $t")
        return t
    end

    symval = getfield(@__MODULE__, sym)
    child_classes = map(x -> geteclass(g, x), rest_of_args)
    child_types = Tuple(map(x -> getdata(x, an, Any), child_classes))

    # println("symval $symval")
    # println("child types $child_types")

    # t_arr = map(last, code_typed(symval, child_types))

    # if length(t_arr) == 0
    #     error("TYPE ERROR. No method for $(n.head) with types $child_types")
    # elseif length(t_arr) !== 1
    #     error("AMBIGUOUS TYPES! $n $t_arr")
    # end

    # t = t_arr[1]
    t = Core.Compiler.return_type(symval, child_types)

    if t == Union{}
        throw(MethodError(symval, child_types))
    end
    # println("analyzed type of $n is $t")
    return t
end

EGraphs.join(an::Type{TypeAnalysis}, from, to) = typejoin(from, to)

EGraphs.islazy(x::Type{TypeAnalysis}) = true

function infer(e)
    g = EGraph(e)
    analyze!(g, TypeAnalysis)
    getdata(geteclass(g, g.root), TypeAnalysis)
end

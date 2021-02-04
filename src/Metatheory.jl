module Metatheory

include("util.jl")
include("rule.jl")
include("theory.jl")
include("matchcore_compiler.jl")
include("reduce.jl")
include("match.jl")
include("EGraphs/EGraphs.jl")


include("Library/Library.jl")

export EGraphs

export @rule
export @theory

export Theory
export Rule

# theory generation macros
export @commutative_monoid
export @abelian_group
export @distrib

export sym_reduce
export @reduce
export @ret_reduce
export @compile_theory
export @matcher
export @reducer

## E-Graphs

export EClass
export EGraph
export AbstractAnalysis
export merge!
export addexpr!
export addanalysis!
export rebuild!
export saturate!
export countexprs

end # module

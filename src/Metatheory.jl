module Metatheory

include("reduce.jl")
include("macros.jl")

export @rule
export @theory

export Theory
export Rule
export sym_reduce
export makeblock

# theory generation macros
export @monoid
export @commutative_monoid
export @abelian_group
export @distrib

export @reduce
export @ret_reduce

end # module

const MatchesBuf = Vector{Tuple{Rule, Sub, Int64}}

using RuntimeGeneratedFunctions
const RGF = RuntimeGeneratedFunctions

"Type representing a cache of [`RuntimeGeneratedFunctions`](@ref) corresponding
to right hand sides of dynamic rules"
const RhsFunCache = Dict{Rule, Tuple{Vector{Symbol}, Function}}

inst(var, G::EGraph, sub::Sub) = haskey(sub, var) ? first(sub[var]) : add!(G, var)
inst(p::Expr, G::EGraph, sub::Sub) = add!(G, p)

function instantiate(G::EGraph, p, sub::Sub; skip_assert=false)
    # remove type assertions
    if skip_assert
        p = df_walk( x -> (isexpr(x, :ematch_tassert) ? x.args[1] : x), p; skip_call=true )
    end

    df_walk(inst, p, G, sub; skip_call=true)
end

function get_actual_param(var, sub::Sub)
     if haskey(sub, var)
         (eclass, literal) = sub[var]
         literal != nothing ? literal : eclass
     else
         error("internal error in dynamic rule application")
     end
end

"""
Generates a tuple containing the list of formal parameters (`Symbol`s)
and the [`RuntimeGeneratedFunction`](@ref) corresponding to the right hand
side of a `:dynamic` [`Rule`](@ref).
"""
function genrhsfun(rule::Rule, mod::Module)
    (mod != @__MODULE__) && !isdefined(mod, RGF._tagname) && RGF.init(mod)
    # remove type assertions in left hand
    lhs = df_walk( x -> (isexpr(x, :ematch_tassert) ? x.args[1] : x), rule.left; skip_call=true )

    # collect variable symbols in left hand
    lhs_vars = Set{Symbol}()
    df_walk( x -> (if x isa Symbol; push!(lhs_vars, x); end; x), rule.left; skip_call=true )
    params = Expr(:tuple, lhs_vars...)

    ex = :($params -> $(rule.right))
    (collect(lhs_vars), RuntimeGeneratedFunction(mod, mod, ex))
end

function eqsat_step!(G::EGraph, theory::Vector{Rule};
        scheduler=SimpleScheduler(), rhs_funs=RhsFunCache())
    matches=MatchesBuf()
    EMPTY_DICT = Sub()

    readstep(scheduler)

    for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue

        if rule.mode == :rewrite || rule.mode == :dynamic
            for id ∈ keys(G.M)
                # println(rule.right)
                for sub in ematch(G, rule.left, id, EMPTY_DICT)
                    # display(sub); println()
                    !isempty(sub) && push!(matches, (rule, sub, id))
                end
                # for sub in ematch(G, rule.right, id, EMPTY_DICT)
                #     # display(sub); println()
                #     !isempty(sub) && push!(matches, (rule, sub, id))
                # end
            end
        else
            error("unsupported rule mode")
        end
    end

    # @info "write phase"
    for (rule, sub, id) ∈ matches
        writestep(scheduler, rule)

        if rule.mode == :rewrite # symbolic replacement
            l = instantiate(G,rule.left,sub; skip_assert=true)
            r = instantiate(G,rule.right,sub)
            merge!(G,l.id,r.id)
        elseif rule.mode == :dynamic # execute the right hand!
            l = instantiate(G,rule.left,sub; skip_assert=true)

            # TODO FIXME important: use a RGF!
            (params, f) = rhs_funs[rule]
            actual_params = params .|> x -> get_actual_param(x, sub)
            r = addexpr!(G, f(actual_params...))
            merge!(G,l.id,r.id)
        else
            error("unsupported rule mode")
        end
    end

    # display(G.parents); println()
    # display(G.M); println()
    saturated = isempty(G.dirty)
    rebuild!(G)
    return saturated, G
end

# TODO plot how egraph shrinks and grows during saturation
function saturate!(G::EGraph, theory::Vector{Rule};
    mod=@__MODULE__,
    timeout=7, stopwhen=(()->false), sizeout=2^12,
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler)

    curr_iter = 0

    # evaluate types in type assertions and generate the
    # dynamic rule right hand side function cache
    rhs_funs = RhsFunCache()
    theory = map(theory) do rule
        r = deepcopy(rule)
        r.left = df_walk(eval_types_in_assertions, r.left; skip_call=true)
        if r.mode == :dynamic && !haskey(rhs_funs, r)
            rhs_funs[r] = genrhsfun(r, mod)
        end
        r
    end

    # init the scheduler
    sched = scheduler(G, theory)

    while true
        # @info curr_iter
        curr_iter+=1
        saturated, G = eqsat_step!(G, theory; scheduler=sched, rhs_funs=rhs_funs)

        cansaturate(sched) && saturated && (@info "E-GRAPH SATURATED"; break)
        curr_iter >= timeout && (@info "E-GRAPH TIMEOUT"; break)
        sizeout > 0 && length(G.U) > sizeout && (@info "E-GRAPH SIZEOUT"; break)
        stopwhen() && (@info "Halting requirement satisfied"; break)
    end
    return G
end



# TODO is there anything better than eval to use here?
"""
When creating a theory, type assertions in the left hand contain symbols.
We want to replace the type symbols with the real type values, to fully support
the subtyping mechanism during pattern matching.
"""
function eval_types_in_assertions(x)
    if isexpr(x, :(::))
        !(x.args[1] isa Symbol) && error("Type assertion is not on metavariable")
        Expr(:ematch_tassert, x.args[1], eval(x.args[2]))
    else x
    end
end

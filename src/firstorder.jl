##################################################################################
# This file is part of ModelBaseEcon.jl
# BSD 3-Clause License
# Copyright (c) 2020-2022, Bank of Canada
# All rights reserved.
##################################################################################


struct FirstOrderMED <: AbstractModelEvaluationData
    fwd_vars::Vector{Tuple{Symbol,Int}}
    bck_vars::Vector{Tuple{Symbol,Int}}
    ex_vars::Vector{Tuple{Symbol,Int}}
    fwd_inds::LittleDict{Tuple{Symbol,Int},Int}
    bck_inds::LittleDict{Tuple{Symbol,Int},Int}
    ex_inds::LittleDict{Tuple{Symbol,Int},Int}
    FWD::Matrix{Float64}
    BCK::Matrix{Float64}
    EX::Matrix{Float64}
    lmed::LinearizedModelEvaluationData
end

function FirstOrderMED(m::Model)
    #
    # we need a linearized model
    #
    linearize!(m)
    lmed = m.evaldata
    #
    # define variables for lags and leads more than 1 
    # also categorize variables as fwd, bck, and ex
    #
    fwd_vars = Tuple{Symbol,Int}[]
    bck_vars = Tuple{Symbol,Int}[]
    ex_vars = Tuple{Symbol,Int}[]
    for mvar in m.allvars
        var = mvar.name
        lags, leads = extrema(lag for eqn in m.equations
                              for (name, lag) in keys(eqn.tsrefs)
                              if name == var)
        if isexog(mvar) || isshock(mvar)
            push!(ex_vars, ((var, tt) for tt = lags:leads)...)
        elseif lags == 0 && leads == 0
            push!(bck_vars, (var, 0))
        else
            for tt = 1:-lags
                push!(bck_vars, (var, 1 - tt))
            end
            for tt = 1:leads
                push!(fwd_vars, (var, tt - 1))
            end
        end
    end
    #
    # build reverse indexing maps
    #
    nbck = length(bck_vars)
    nfwd = length(fwd_vars)
    nex = length(ex_vars)
    bck_inds = LittleDict{Tuple{Symbol,Int},Int}(
        key => index for (index, key) in enumerate(bck_vars)
    )
    fwd_inds = LittleDict{Tuple{Symbol,Int},Int}(
        key => nbck + index for (index, key) in enumerate(fwd_vars)
    )
    ex_inds = LittleDict{Tuple{Symbol,Int},Int}(
        key => index for (index, key) in enumerate(ex_vars)
    )
    #
    # build the three matrices that define the system: FWD, BCK, EX
    #
    FWD = zeros(nbck + nfwd, nbck + nfwd)
    BCK = zeros(nbck + nfwd, nbck + nfwd)
    EX = zeros(nbck + nfwd, nex)
    for (eqind, col, val) in zip(findnz(lmed.med.J)...)
        # translate Jacobian column index `col` to variable index (in m.allvars) and time offset
        (vno, tt) = divrem(col - 1, 1 + m.maxlag + m.maxlead)
        vno += 1
        tt -= m.maxlag
        # obtain the variable name given its index
        var = m.allvars[vno].name
        var_tt = (var, tt)
        # is it in ex_vars
        ex_i = get(ex_inds, var_tt, nothing)
        if ex_i !== nothing
            EX[eqind, ex_i] = val
            continue
        end
        # not in ex_vars. It's fwd_vars or bck_vars or both.
        if tt < 0
            # definitely bck_var
            bck_i = get(bck_inds, (var, tt + 1), nothing)
            BCK[eqind, bck_i] = val
        elseif tt > 0
            # definitely fwd_var
            fwd_i = get(fwd_inds, (var, tt - 1), nothing)
            FWD[eqind, fwd_i] = val
        else # tt == 0
            # could be either or both; 
            bck_i = get(bck_inds, (var, 0), nothing)
            if bck_i !== nothing
                # prefer to treat it as bck_var, if both
                FWD[eqind, bck_i] = val
            else
                # not bck_fwd, must be fwd_fwd
                fwd_i = get(fwd_inds, (var, 0), nothing)
                BCK[eqind, fwd_i] = val
            end
        end
        nothing
    end
    # add links
    eqn = length(m.alleqns)
    for (var, tt) in fwd_vars
        if tt == 0
            # add a fwd-bck cross link, if it's both fwd and bck variable
            b_i = get(bck_inds, (var, 0), nothing)
            if b_i !== nothing
                eqn += 1
                f_i = fwd_inds[(var, 0)]
                FWD[eqn, b_i] = 1
                BCK[eqn, f_i] = -1
            end
        else
            # add a fwd-fwd link
            eqn += 1
            FWD[eqn, fwd_inds[(var, tt - 1)]] = 1
            BCK[eqn, fwd_inds[(var, tt)]] = -1
        end
        nothing
    end
    for (var, tt) in bck_vars
        if tt == 0
            # cross links already done above
            continue
        else
            # add a fwd-fwd link
            eqn += 1
            FWD[eqn, bck_inds[(var, tt)]] = 1
            BCK[eqn, bck_inds[(var, tt + 1)]] = -1
        end
        nothing
    end
    return FirstOrderMED(
        fwd_vars, bck_vars, ex_vars,
        fwd_inds, bck_inds, ex_inds,
        FWD, BCK, EX,
        lmed,
    )
end

export firstorder!
function firstorder!(m::Model)
    m.evaldata = FirstOrderMED(m)
    return m
end

refresh_med!(m::AbstractModel, ::Type{FirstOrderMED}) = firstorder!(m)
eval_R!(RES::AbstractVector{Float64}, point::AbstractMatrix{Float64}, fomed::FirstOrderMED) = eval_R!(RES, point, fomed.lmed)
eval_RJ(point::AbstractMatrix{Float64}, fomed::FirstOrderMED) = eval_RJ(point, fomed.lmed)

export isfirstorder
isfirstorder(m::Model) = m.evaldata isa FirstOrderMED

##################################################################################
# This file is part of ModelBaseEcon.jl
# BSD 3-Clause License
# Copyright (c) 2020-2025, Bank of Canada
# All rights reserved.
##################################################################################

using ModelBaseEcon
using SparseArrays
using Test

import ModelBaseEcon.update


@testset "Transformations" begin
    @test_throws ErrorException transformation(Transformation)
    @test_throws ErrorException inverse_transformation(Transformation)
    let m = Model()
        @variables m begin
            x
            @log lx
            @neglog lmx
        end
        @test length(m.variables) == 3
        @test m.x.tr_type === :none
        @test m.lx.tr_type === :log
        @test m.lmx.tr_type === :neglog
        data = rand(20)
        @test transform(data, m.x) ≈ data
        @test inverse_transform(data, m.x) ≈ data
        @test transform(data, m.lx) ≈ log.(data)
        @test inverse_transform(log.(data), m.lx) ≈ data
        mdata = -data
        @test transform(mdata, m.lmx) ≈ log.(data)
        @test inverse_transform(log.(data), m.lmx) ≈ mdata
        @test !need_transform(:y)
        y = to_lin(:y)
        @test y.tr_type === :none
        @logvariables m lmy
        @neglogvariables m ly
        @test_throws ErrorException m.ly = 25
        @test_throws ErrorException m.lmy = -25
        @test_throws ErrorException m.ly = ModelVariable(:lmy)
        @test_logs (:warn, r".*do not specify transformation directly.*"i) @test_throws ArgumentError update(m.ly, tr_type=:log, transformation=NoTransform)
        @test_logs (:warn, r".*do not specify transformation directly.*"i) update(m.ly, tr_type=:log, transformation=LogTransform)
        @test_logs (:warn, r".*do not specify transformation directly.*"i) @test update(m.ly, transformation=LogTransform).tr_type == :log
        @test_logs (:warn, r".*do not specify transformation directly.*"i) @test update(m.lmy, tr_type=:neglog, transformation=NegLogTransform).tr_type == :neglog

        @test_throws ErrorException m.dummy = nothing

    end
end

@testset "Options" begin
    o = Options(tol=1e-7, maxiter=25)
    @test propertynames(o) == (:maxiter, :tol)
    @test getoption(o, tol=1e7) == 1e-7
    @test getoption(o, "name", "") == ""
    @test getoption(o, abstol=1e-10, name="") == (1e-10, "")
    @test all(["abstol", "name"] .∉ Ref(o))
    @test getoption!(o, abstol=1e-11) == 1e-11
    @test :abstol ∈ o
    @test setoption!(o, reltol=1e-3, linear=false) isa Options
    @test all(["reltol", :linear] .∈ Ref(o))
    @test getoption!(o, tol=nothing, linear=true, name="Zoro") == (1e-7, false, "Zoro")
    @test "name" ∈ o && o.name == "Zoro"
    z = Options()
    @test merge(z, o) == Options(o...) == Options(o)
    @test merge!(z, o) == Options(Dict(string(k) => v for (k, v) in pairs(o))...)
    @test o == z
    @test Dict(o...) == z
    @test o == Dict(z...)
    z.name = "Oro"
    @test o.name == "Zoro"
    @test setoption!(z, "linear", true) isa Options
    @test getoption!(z, "linear", false) == true
    @test getoption!(z, :name, "") == "Oro"
    @test show(IOBuffer(), o) === nothing
    @test show(IOBuffer(), MIME"text/plain"(), o) === nothing

    @using_example S1
    m = S1.newmodel()
    @test getoption(m, "shift", 1) == getoption(m, shift=1) == 10
    @test getoption!(m, "substitutions", true) == getoption!(m, :substitutions, true) == false
    @test getoption(setoption!(m, "maxiter", 25), maxiter=0) == 25
    @test getoption(setoption!(m, verbose=true), "verbose", false) == true
    @test typeof(setoption!(identity, m)) == Options
end

@testset "Vars" begin
    y1 = :y
    y2 = ModelSymbol(:y)
    y3 = ModelSymbol("y3", :y)
    y4 = ModelSymbol(quote
        "y4"
        y
    end)
    @test hash(y1) == hash(:y)
    @test hash(y2) == hash(:y)
    @test hash(y3) == hash(:y)
    @test hash(y4) == hash(:y)
    @test hash(y4, UInt(0)) == hash(:y, UInt(0))
    @test_throws ArgumentError ModelSymbol(:(x + 5))
    @test y1 == y2
    @test y3 == y1
    @test y1 == y4
    @test y2 == y3
    @test y2 == y4
    @test y3 == y4
    ally = Symbol[y1, y2, y3, y4]
    @test y1 in ally
    @test y2 in ally
    @test y3 in ally
    @test y4 in ally
    @test indexin([y1, y2, y3, y4], ally) == [1, 1, 1, 1]
    ally = ModelSymbol[y1, y2, y3, y4, :y, quote
        "y5"
        y
    end]
    @test indexin([y1, y2, y3, y4], ally) == [1, 1, 1, 1]
    @test length(unique(hash.(ally))) == 1
    ally = Dict{Symbol,Any}()
    get!(ally, y1, "y1")
    get!(ally, y2, "y2")
    @test length(ally) == 1
    @test ally[y3] == "y1"
    ally = Dict{ModelSymbol,Any}()
    get!(ally, y1, "y1")
    get!(ally, y2, "y2")
    @test length(ally) == 1
    @test ally[y3] == "y1"
    @test sprint(print, y2, context=IOContext(stdout, :compact => true)) == "y"
    @test sprint(print, y2, context=IOContext(stdout, :compact => false)) == "y"
    @test sprint(print, y3, context=IOContext(stdout, :compact => true)) == "y"
    @test sprint(print, y3, context=IOContext(stdout, :compact => false)) == "\"y3\" y"

end

@testset "VarTypes" begin
    lvars = ModelSymbol[]
    push!(lvars, :ly)
    push!(lvars, quote
        "ly"
        ly
    end)
    push!(lvars, quote
        @log ly
    end)
    push!(lvars, quote
        "ly"
        @log ly
    end)
    push!(lvars, quote
        @lin ly
    end)
    push!(lvars, quote
        "ly"
        @lin ly
    end)
    push!(lvars, quote
        @steady ly
    end)
    push!(lvars, quote
        "ly"
        @steady ly
    end)
    push!(lvars, ModelSymbol(:ly, :lin))
    for i in eachindex(lvars)
        for j = i+1:length(lvars)
            @test lvars[i] == lvars[j]
        end
        @test lvars[i] == :ly
    end
    @test lvars[1].var_type == :lin
    @test lvars[2].var_type == :lin
    @test lvars[3].var_type == :log
    @test lvars[4].var_type == :log
    @test lvars[5].var_type == :lin
    @test lvars[6].var_type == :lin
    @test lvars[7].var_type == :steady
    @test lvars[8].var_type == :steady
    @test lvars[9].var_type == :lin
    for i in eachindex(lvars)
        @test sprint(print, lvars[i], context=IOContext(stdout, :compact => true)) == "ly"
    end
    @test sprint(print, lvars[1], context=IOContext(stdout, :compact => false)) == "ly"
    @test sprint(print, lvars[2], context=IOContext(stdout, :compact => false)) == "\"ly\" ly"
    @test sprint(print, lvars[3], context=IOContext(stdout, :compact => false)) == "@log ly"
    @test sprint(print, lvars[4], context=IOContext(stdout, :compact => false)) == "\"ly\" @log ly"
    @test sprint(print, lvars[5], context=IOContext(stdout, :compact => false)) == "ly"
    @test sprint(print, lvars[6], context=IOContext(stdout, :compact => false)) == "\"ly\" ly"
    @test sprint(print, lvars[7], context=IOContext(stdout, :compact => false)) == "@steady ly"
    @test sprint(print, lvars[8], context=IOContext(stdout, :compact => false)) == "\"ly\" @steady ly"

    let m = Model()
        @variables m p q r
        @variables m begin
            x
            @log y
            @steady z
        end
        @test [v.var_type for v in m.allvars] == [:lin, :lin, :lin, :lin, :log, :steady]
    end
    let m = Model()
        @shocks m p q r
        @shocks m begin
            x
            @log y
            @steady z
        end
        @test [v.var_type for v in m.allvars] == [:shock, :shock, :shock, :shock, :shock, :shock]
        @test (m.r = to_shock(m.r)) == :r
    end
    let m = Model()
        @logvariables m p q r
        @logvariables m begin
            x
            @log y
            @steady z
        end
        @test [v.var_type for v in m.allvars] == [:log, :log, :log, :log, :log, :log]
    end
    let m = Model()
        @neglogvariables m p q r
        @neglogvariables m begin
            x
            @log y
            @steady z
        end
        @test [v.var_type for v in m.allvars] == [:neglog, :neglog, :neglog, :neglog, :neglog, :neglog]
    end
    let m = Model()
        @steadyvariables m p q r
        @steadyvariables m begin
            x
            @log y
            @steady z
        end
        @warn "Test disabled"
        # @test [v.var_type for v in m.allvars] == [:steady, :steady, :steady, :steady, :steady, :steady]

    end
end

module E
using ModelBaseEcon
end
@testset "Evaluations" begin
    ModelBaseEcon.initfuncs(E)
    @test isdefined(E, :EquationEvaluator)
    @test isdefined(E, :EquationGradient)
    resid, RJ = ModelBaseEcon.makefuncs(Symbol(1), :(x + 3 * y), [:x, :y], [], [], E)
    @test resid isa E.EquationEvaluator
    @test RJ isa E.EquationGradient
    @test RJ.fn1 isa ModelBaseEcon.FunctionWrapper
    @test RJ.fn1.f == resid
    @test parentmodule(resid) === E
    @test parentmodule(RJ) === E
    @test resid([1.1, 2.3]) == 8.0
    @test RJ([1.1, 2.3]) == (8.0, [1.0, 3.0])
    # make sure the EquationEvaluator and EquationGradient are reused for identical expressions and arguments
    nnames = length(names(E, all=true))
    resid1, RJ1 = ModelBaseEcon.makefuncs(Symbol(1), :(x + 3 * y), [:x, :y], [], [], E)
    @test nnames == length(names(E, all=true))
    @test resid === resid1
    @test RJ === RJ1
end

@testset "Misc" begin
    m = Model(Options(verbose=true))
    out = let io = IOBuffer()
        print(io, m.flags)
        readlines(seek(io, 0))
    end
    @test length(out) == 3
    for line in out[2:end]
        sline = strip(line)
        @test isempty(sline) || length(split(sline, "=")) == 2
    end
    @test fullprint(IOBuffer(), m) === nothing
    @test_throws ModelBaseEcon.ModelError ModelBaseEcon.modelerror()
    @test contains(
        sprint(showerror, ModelBaseEcon.ModelError()),
        r"unknown error"i)
    @test contains(
        sprint(showerror, ModelBaseEcon.ModelNotInitError()),
        r"model not ready to use"i)
    @test contains(
        sprint(showerror, ModelBaseEcon.NotImplementedError("foobar")),
        r"feature not implemented: foobar"i)
    @variables m x y z
    @logvariables m k l m
    @steadyvariables m p q r
    @shocks m a b c
    for s in (:a, :b, :c)
        @test m.:($s) isa ModelSymbol && isshock(m.:($s))
    end
    for s in (:x, :y, :z)
        @test m.:($s) isa ModelSymbol && islin(m.:($s))
    end
    for s in (:k, :l, :m)
        @test m.:($s) isa ModelSymbol && islog(m.:($s))
    end
    for s in (:p, :q, :r)
        @test m.:($s) isa ModelSymbol && issteady(m.:($s))
    end
    @test_throws ErrorException m.a = 1
    @test_throws ModelBaseEcon.EqnNotReadyError ModelBaseEcon.eqnnotready()
    sprint(showerror, ModelBaseEcon.EqnNotReadyError())

    @test_throws ModelBaseEcon.ModelError @macroexpand @equations m p[t] = 0

    @equations m begin
        p[t] = 0
    end
    @test_throws ModelBaseEcon.ModelNotInitError ModelBaseEcon.getevaldata(m, :default)
    @test_warn ("unused variables", "unused shocks", r"different numbers of equations .* and endogenous variables") @initialize m

    unused = get_unused_symbols(m)
    @test unused[:variables] == [:x, :y, :z, :k, :l, :m, :q, :r]
    @test unused[:shocks] == [:a, :b, :c]
    @test unused[:parameters] == Vector{Symbol}()

    @test ModelBaseEcon.hasevaldata(m, :default)
    @test_throws ModelBaseEcon.ModelError @initialize m
    @test_throws ModelBaseEcon.EvalDataNotFound ModelBaseEcon.getevaldata(m, :nosuchevaldata)

    @test_logs (:error, r"Evaluation data for .* not found\..*"i) begin
        try
            ModelBaseEcon.getevaldata(m, :nosuchevaldata)
        catch E
            if E isa ModelBaseEcon.EvalDataNotFound
                @test true
                io = IOBuffer()
                showerror(io, E)
                seekstart(io)
                @error read(io, String)
            else
                rethrow(E)
            end
        end
    end
    @test_logs (:error, r"Solver data for .* not found\..*"i) begin
        try
            ModelBaseEcon.getsolverdata(m, :nosuchsolverdata)
        catch E
            if E isa ModelBaseEcon.SolverDataNotFound
                @test true
                io = IOBuffer()
                showerror(io, E)
                seekstart(io)
                @error read(io, String)
            else
                rethrow(E)
            end
        end
    end

    @test_throws ModelBaseEcon.SolverDataNotFound ModelBaseEcon.getsolverdata(m, :testdata)
    @test (ModelBaseEcon.setsolverdata!(m, testdata=nothing); ModelBaseEcon.hassolverdata(m, :testdata))
    @test ModelBaseEcon.getsolverdata(m, :testdata) === nothing

    @test Symbol(m.variables[1]) == m.variables[1]

    for (i, v) = enumerate(m.varshks)
        s = convert(Symbol, v)
        @test m.sstate[i] == m.sstate[v] == m.sstate[s] == m.sstate["$s"]
    end

    m.sstate.values .= rand(length(m.sstate.values))
    @test begin
        (l, s) = m.sstate.x.data
        l == m.sstate.x.level && s == m.sstate.x.slope
    end
    @test begin
        (l, s) = m.sstate.k.data
        exp(l) == m.sstate.k.level && exp(s) == m.sstate.k.slope
    end

    @test_throws ArgumentError m.sstate.x[1:8, ref=3.0]
    @test m.sstate.x[2, ref=3] ≈ m.sstate.x.level - m.sstate.x.slope

    xdata = m.sstate.x[1:8, ref=3]
    @test xdata[3] ≈ m.sstate.x.level
    @test xdata ≈ m.sstate.x.level .+ ((1:8) .- 3) .* m.sstate.x.slope
    kdata = m.sstate.k[1:8, ref=3]
    @test kdata[3] ≈ m.sstate.k.level
    @test kdata ≈ m.sstate.k.level .* m.sstate.k.slope .^ ((1:8) .- 3)

    @test_throws Exception m.sstate.x.data = [1, 2]
    @test_throws ArgumentError m.sstate.nosuchvariable

    @steadystate m m = l
    @steadystate m slope m = l
    @test length(m.sstate.constraints) == 2

    let io = IOBuffer()
        show(io, m.sstate.x)
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && occursin('+', lines[1])

        show(io, m.sstate.k)
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && !occursin('+', lines[1]) && occursin('*', lines[1])

        m.sstate.y.slope = 0
        show(io, m.sstate.y)
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && !occursin('+', lines[1]) && !occursin('*', lines[1])

        m.sstate.l.slope = 1
        show(io, m.sstate.l)
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && !occursin('+', lines[1]) && !occursin('*', lines[1])

        show(io, m.sstate.p)
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && !occursin('+', lines[1]) && !occursin('*', lines[1])

        ModelBaseEcon.show_aligned5(io, m.sstate.x, mask=[true, false])
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && length(split(lines[1], '?')) == 2

        ModelBaseEcon.show_aligned5(io, m.sstate.k, mask=[false, false])
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 1 && length(split(lines[1], '?')) == 3

        ModelBaseEcon.show_aligned5(io, m.sstate.l, mask=[false, false])
        println(io)
        ModelBaseEcon.show_aligned5(io, m.sstate.y, mask=[false, false])
        println(io)
        ModelBaseEcon.show_aligned5(io, m.sstate.p, mask=[false, true])
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 3
        for line in lines
            @test length(split(line, '?')) == 2
        end
        @test fullprint(io, m) === nothing
        @test show(io, m) === nothing
        @test show(IOBuffer(), MIME"text/plain"(), m) === nothing
        @test show(io, Model()) === nothing

        @test m.exogenous == ModelVariable[]
        @test m.nexog == 0
        @test_throws ErrorException m.dummy

        @test show(IOBuffer(), MIME"text/plain"(), m.flags) === nothing
    end

    @test_throws ModelBaseEcon.ModelError let m = Model()
        @parameters m a = 5
        @variables m a
        @equations m begin
            a[t] = 5
        end
        @initialize m
    end

    # test docstring
    @test begin
        local m = Model()
        @variables m a
        eq = ModelBaseEcon.process_equation(m, quote
                "this is equation 1"
                :E1 => a[t] = 0
            end, modelmodule=@__MODULE__, eqn_name=:A)
        eq.doc == "this is equation 1"
    end

    # test incomplete
    @test_throws ArgumentError begin
        local m = Model()
        @variables m a
        ModelBaseEcon.add_equation!(m, :A, Meta.parse("a[t] = "); modelmodule=@__MODULE__)
    end

end


@testset "Abstract" begin
    struct AM <: ModelBaseEcon.AbstractModel end
    m = AM()
    @test_throws ErrorException ModelBaseEcon.alleqns(m)
    @test_throws ErrorException ModelBaseEcon.allvars(m)
    @test_throws ErrorException ModelBaseEcon.nalleqns(m) == 0
    @test_throws ErrorException ModelBaseEcon.nallvars(m) == 0
    @test_throws ErrorException ModelBaseEcon.moduleof(m) == @__MODULE__
end

@testset "metafuncts" begin
    @test ModelBaseEcon.has_t(1) == false
    @test ModelBaseEcon.has_t(:(x[t] - x[t-1])) == true
    @test @lag(x[t], 0) == :(x[t])
    @test_throws ErrorException @macroexpand @d(x[t], 0, -1)
    @test @d(x[t], 3, 0) == :(((x[t] - 3 * x[t-1]) + 3 * x[t-2]) - x[t-3])
    @test @movsumew(x[t], 3, 2.0) == :(x[t] + (2.0 * x[t-1] + 4.0 * x[t-2]))
    @test @movsumew(x[t], 3, y) == :(x[t] + (y^1 * x[t-1] + y^2 * x[t-2]))
    @test @movavew(x[t], 3, 2.0) == :((x[t] + (2.0 * x[t-1] + 4.0 * x[t-2])) / 7.0)
    @test @movavew(x[t], 3, y) == :(((x[t] + (y^1 * x[t-1] + y^2 * x[t-2])) * (1 - y)) / (1 - y^3))
    @test @lag(x[t+4]) == :(x[t+3])
    @test @lag(x[t-1]) == :(x[t-2])
    @test @lag(x[3]) == :(x[3])
    @test_throws ErrorException @macroexpand @lag(x[3+t])
    @test @movsumw(a[t] + b[t+1], 2, p) == :(p[1] * (a[t] + b[t+1]) + p[2] * (a[t-1] + b[t]))
    @test @movavw(a[t] + b[t+1], 2, p) == :((p[1] * (a[t] + b[t+1]) + p[2] * (a[t-1] + b[t])) / (p[1] + p[2]))
    @test @movsumw(a[t] + b[t+1], 2, q, p) == :(q * (a[t] + b[t+1]) + p * (a[t-1] + b[t]))
    @test @movavw(a[t] + b[t+1], 2, q, p) == :((q * (a[t] + b[t+1]) + p * (a[t-1] + b[t])) / (q + p))
    @test @lead(v[t, 2]) == :(v[t+1, 2])
    @test @dlog(v[t-1, z, t+2], 1) == :(log(v[t-1, z, t+2]) - log(v[t-2, z, t+1]))
end

module MetaTest
using ModelBaseEcon
params = @parameters
custom(x) = x + one(x)
val = 12.0
pair = :hello => "world"
params.b = custom(val)
params.a = @link custom(val)
params.c = val
params.d = @link val
params.e = @link pair.first
params.f = @link pair[2]
end

@testset "Parameters" begin
    m = Model()
    params = Parameters()
    push!(params, :a => 1.0)
    push!(params, :b => @link 1.0 - a)
    push!(params, :c => @alias b)
    push!(params, :e => [1, 2, 3])
    push!(params, :d => @link (sin(2π / e[3])))
    @test length(params) == 5
    # dot notation evaluates
    @test params.a isa Number
    @test params.b isa Number
    @test params.c isa Number
    @test params.d isa Number
    @test params.e isa Vector{<:Number}
    # [] notation returns the holding structure
    a = params[:a]
    b = params[:b]
    c = params[:c]
    d = params[:d]
    e = params[:e]
    @test a isa ModelParam
    @test b isa ModelParam
    @test c isa ModelParam
    @test d isa ModelParam
    @test e isa ModelParam
    @test a.depends == Set([:b])
    @test b.depends == Set([:c])
    @test c.depends == Set([])
    @test d.depends == Set([])
    @test e.depends == Set([:d])
    # circular dependencies not allowed
    @test_throws ArgumentError push!(params, :a => @alias b)
    # even deep ones
    @test_throws ArgumentError push!(params, :a => @alias c)
    # even when it is in an expr
    @test_throws ArgumentError push!(params, :a => @link 5 + b^2)
    @test_throws ArgumentError push!(params, :a => @link 3 - c)

    @test params.d ≈ √3 / 2.0
    params.e[3] = 2
    m.parameters = params
    # update_links!(params)
    update_links!(params)
    @test 1.0 + params.d ≈ 1.0

    params.d = @link cos(2π / e[2])
    @test params.d ≈ -1.0

    @test_throws ArgumentError @alias a + 5
    @test_throws ArgumentError @link 28

    @test MetaTest.params.a ≈ 13.0
    @test MetaTest.params.b ≈ 13.0
    @test MetaTest.params.c ≈ 12.0
    @test MetaTest.params.d ≈ 12.0
    # Core.eval(MetaTest, :(custom(x) = 2x + one(x)))
    MetaTest.custom(x) = 2x + one(x)
    update_links!(MetaTest.params)
    @test MetaTest.params.a ≈ 25.0
    @test MetaTest.params.b ≈ 13.0
    @test MetaTest.params.c ≈ 12.0
    @test MetaTest.params.d ≈ 12.0
    Core.eval(MetaTest, :(val = 22))
    update_links!(MetaTest.params)
    @test MetaTest.params.a == 45
    @test MetaTest.params.b ≈ 13.0
    @test MetaTest.params.c ≈ 12.0
    @test MetaTest.params.d == 22

    @test MetaTest.params.e == :hello
    @test MetaTest.params.f == "world"
    Core.eval(MetaTest, :(pair = 27 => π))
    update_links!(MetaTest.params)
    @test MetaTest.params.e == 27
    @test MetaTest.params.f == π

    @test @alias(c) == ModelParam(Set(), :c, nothing)
    @test @link(c) == ModelParam(Set(), :c, nothing)
    @test @link(c + 1) == ModelParam(Set(), :(c + 1), nothing)

    @test_throws ArgumentError params[:contents] = 5
    @test_throws ArgumentError params.abc

    @test_logs (:error, r"While updating value for parameter b:*"i) begin
        try
            params.a = [1, 2, 3]
        catch E
            if E isa ModelBaseEcon.ParamUpdateError
                io = IOBuffer()
                showerror(io, E)
                seekstart(io)
                @error read(io, String)
            else
                rethrow(E)
            end
        end
    end
end

@testset "ifelse" begin
    m = Model()
    @variables m x
    @equations m begin
        x[t] = 0
    end
    @initialize m
    @test_throws ArgumentError ModelBaseEcon.process_equation(m, :(y[t] = 0), eqn_name=:_EQ2)
    @warn "disabled test with unknown parameter in equation"
    # @test_throws ArgumentError ModelBaseEcon.process_equation(m, :(x[t] = p), eqn_name=:_EQ2) #no exception thrown!
    @test_throws ArgumentError ModelBaseEcon.process_equation(m, :(x[t] = x[t-1])) #no equation name
    @test_throws ArgumentError ModelBaseEcon.process_equation(m, :(x[t] = if false
            2
        end), eqn_name=:_EQ2)
    @test ModelBaseEcon.process_equation(m, :(x[t] = if false
            2
        else
            0
        end), eqn_name=:_EQ2) isa Equation
    @test ModelBaseEcon.process_equation(m, :(x[t] = ifelse(false, 2, 0)), eqn_name=:_EQ3) isa Equation
    p = 0
    @test_logs (:warn, r"Variable or shock .* without `t` reference.*"i) @assert ModelBaseEcon.process_equation(m, "x=$p", eqn_name=:_EQ4) isa Equation
    @test ModelBaseEcon.process_equation(m, :(x[t] = if true && true
            1
        else
            2
        end), eqn_name=:_EQ2) isa Equation
    @test ModelBaseEcon.process_equation(m, :(x[t] = if true || x[t] == 1
            2
        else
            1
        end), eqn_name=:_EQ2) isa Equation
end

@testset "ifelse_eval" begin
    # this addresses issue #70
    @test let model = Model()
        @variables model a
        @parameters model cond = true
        @equations model begin
            :A => a[t] = cond ? 1.0 : -1.0
        end
        @initialize model
        r, j = eval_RJ(zeros(1, 1), model)
        r == [-1.0] && j == [1.0;;]
    end
    @test let model = Model()
        @variables model b
        @parameters model p = 0.5
        @equations model begin
            :B => b[t] = (0.0 <= p <= 1.0)
        end
        @initialize model
        r, j = eval_RJ(zeros(1, 1), model)
        r == [-1.0] && j == [1.0;;]
    end
end

@testset "Meta" begin
    mod = Model()
    @parameters mod a = 0.1 b = @link(1.0 - a)
    @variables mod x
    @shocks mod sx
    @equations mod begin
        x[t-1] = sx[t+1]
        @lag(x[t]) = @lag(sx[t+2])
        #
        x[t-1] + a = sx[t+1] + 3
        @lag(x[t] + a) = @lag(sx[t+2] + 3)
        #
        x[t-2] = sx[t]
        @lag(x[t], 2) = @lead(sx[t-2], 2)
        #
        x[t] - x[t-1] = x[t+1] - x[t] + sx[t]
        @d(x[t]) = @d(x[t+1]) + sx[t]
        #
        (x[t] - x[t+1]) - (x[t-1] - x[t]) = sx[t]
        @d(x[t] - x[t+1]) = sx[t]
        #
        x[t] - x[t-2] = sx[t]
        @d(x[t], 0, 2) = sx[t]
        #
        x[t] - 2x[t-1] + x[t-2] = sx[t]
        @d(x[t], 2) = sx[t]
        #
        x[t] - x[t-1] - x[t-2] + x[t-3] = sx[t]
        @d(x[t], 1, 2) = sx[t]
        #
        log(x[t] - x[t-2]) - log(x[t-1] - x[t-3]) = sx[t]
        @dlog(@d(x[t], 0, 2)) = sx[t]
        #
        (x[t] + 0.3x[t+2]) + (x[t-1] + 0.3x[t+1]) + (x[t-2] + 0.3x[t]) = 0
        @movsum(x[t] + 0.3x[t+2], 3) = 0
        #
        ((x[t] + 0.3x[t+2]) + (x[t-1] + 0.3x[t+1]) + (x[t-2] + 0.3x[t])) / 3 = 0
        @movav(x[t] + 0.3x[t+2], 3) = 0
    end
    @test_warn "different numbers" @initialize mod

    compare_resids(e1, e2) = (
        e1.resid.head == e2.resid.head && (
            (length(e1.resid.args) == length(e2.resid.args) == 2 && e1.resid.args[2] == e2.resid.args[2]) ||
            (length(e1.resid.args) == length(e2.resid.args) == 1 && e1.resid.args[1] == e2.resid.args[1])
        )
    )

    for i = 2:2:length(mod.equations)
        @test compare_resids(mod.equations[collect(keys(mod.equations))[i-1]], mod.equations[collect(keys(mod.equations))[i]])
    end
    # test errors and warnings
    mod.warn.no_t = false
    @test add_equation!(mod, :EQ1, :(x = sx[t])) isa Model
    @test add_equation!(mod, :EQ2, :(x[t] = sx)) isa Model
    @test add_equation!(mod, :EQ3, :(x[t] = sx[t])) isa Model
    @test compare_resids(mod.equations[:EQ3], mod.equations[:EQ2])
    @test compare_resids(mod.equations[:EQ3], mod.equations[:EQ1])
    @test_throws ArgumentError add_equation!(mod, :EQ4, :(@notametafunction(x[t]) = 7))
    @test_throws ArgumentError add_equation!(mod, :EQ5, :(x[t] = unknownsymbol))
    @test_throws ArgumentError add_equation!(mod, :EQ6, :(x[t] = unknownseries[t]))
    @test_throws ArgumentError add_equation!(mod, :EQ7, :(x[t] = let c = 5
        sx[t+c]
    end))
    @test ModelBaseEcon.update_auxvars(ones(2, 2), mod) == ones(2, 2)
end

############################################################################

@testset "export" begin
    let m = Model()
        m.warn.no_t = false
        @parameters m begin
            a = 0.3
            b = @link 1 - a
            d = [1, 2, 3]
            c = @link sin(2π / d[3])
        end
        @variables m begin
            "variable x"
            x
        end
        @shocks m sx
        @autoexogenize m s => sx
        @equations m begin
            "This equation is super cool"
            a * @d(x) = b * @d(x[t+1]) + sx
        end
        @initialize m
        @steadystate m x = a + 1

        export_model(m, "TestModel", "../examples/")

        @test isfile("../examples/TestModel.jl")
        @using_example TestModel

        @test parameters(TestModel.model) == parameters(m)
        @test variables(TestModel.model) == variables(m)
        @test shocks(TestModel.model) == shocks(m)
        @test equations(TestModel.model) == equations(m)
        @test sstate(TestModel.model).constraints == sstate(m).constraints

        m2 = TestModel.newmodel()
        @test parameters(m2) == parameters(m)
        @test variables(m2) == variables(m)
        @test shocks(m2) == shocks(m)
        @test equations(m2) == equations(m)
        @test sstate(m2).constraints == sstate(m).constraints

        @test_throws ArgumentError m2.parameters.d = @alias c

        @test export_parameters(m2) == Dict(:a => 0.3, :b => 0.7, :d => [1, 2, 3], :c => sin(2π / 3))
        @test export_parameters!(Dict{Symbol,Any}(), m2) == export_parameters(TestModel.model.parameters)

        p = deepcopy(parameters(m))
        # link c expects d to be a vector - it'll fail to update with a BoundsError if d is just a number
        @test_throws ModelBaseEcon.ParamUpdateError assign_parameters!(m2, d=2.0)
        map!(x -> ModelParam(), values(m2.parameters.contents))
        @test parameters(assign_parameters!(m2, p)) == p

        ss = Dict(:x => 0.0, :sx => 0.0)
        @test_logs (:warn, r"Model does not have the following variables:.*"i) assign_sstate!(m2, y=0.0)
        @test export_sstate(assign_sstate!(m2, ss)) == ss
        @test export_sstate!(Dict(), m2.sstate, ssZeroSlope=true) == ss

        ss = sstate(m)
        @test show(IOBuffer(), MIME"text/plain"(), ss) === nothing
        @test geteqn(1, m) == first(m.sstate.constraints)[2]
        @test geteqn(neqns(ss), m) == m.sstate.equations[last(collect(keys(m.sstate.equations)))]
        @test propertynames(ss, true) == (:x, :sx, :vars, :values, :mask, :equations, :constraints)
        @test fullprint(IOBuffer(), m) === nothing

        # rm("../examples/TestModel.jl")
    end
end

@testset "@log eqn" begin
    let m = Model()
        @parameters m rho = 0.1
        @variables m X
        @shocks m EX
        @equations m begin
            @log X[t] = rho * X[t-1] + EX[t]
        end
        @initialize m
        eq = m.equations[:_EQ1]
        @test length(m.equations) == 1 && islog(eq)
        @test contains(sprint(show, eq), "=> @log X[t]")
    end
end

############################################################################

function test_eval_RJ(m::Model, known_R, known_J; pt=zeros(0, 0))
    nrows = 1 + m.maxlag + m.maxlead
    ncols = length(m.allvars)
    if isempty(pt)
        pt = zeros(nrows, ncols)
    end
    R, J = eval_RJ(pt, m)
    @test R ≈ known_R atol = 1e-12
    @test J ≈ known_J
end

function compare_RJ_R!_(m::Model)
    nrows = 1 + m.maxlag + m.maxlead
    ncols = length(m.variables) + length(m.shocks) + length(m.auxvars)
    point = rand(nrows, ncols)
    R, J = eval_RJ(point, m)
    S = similar(R)
    eval_R!(S, point, m)
    @test R ≈ S
end

@using_example E1
@testset "Deepcopy" begin
    @test E1.model.evaldata[:default].params[] === E1.model.parameters
    m1 = deepcopy(E1.model)
    @test m1.evaldata[:default].params[] === m1.parameters
end

@testset "E1" begin
    mE1 = E1.newmodel()
    @test length(mE1.parameters) == 2
    @test length(mE1.variables) == 1
    @test length(mE1.shocks) == 1
    @test length(mE1.equations) == 1
    @test mE1.maxlag == 1
    @test mE1.maxlead == 1
    test_eval_RJ(mE1, [0.0], [-0.5 1.0 -0.5 0.0 -1.0 0.0])
    compare_RJ_R!_(mE1)
    @test mE1.tol == mE1.options.tol
    tol = mE1.tol
    mE1.tol = tol * 10
    @test mE1.options.tol == mE1.tol
    mE1.tol = tol
    @test mE1.linear == mE1.flags.linear
    mE1.linear = true
    @test mE1.linear
end

@testset "E1.sstate" begin
    let io = IOBuffer(), m = E1.newmodel()
        m.linear = true
        @test issssolved(m) == false
        m.sstate.mask .= true
        @test issssolved(m) == true
        @test neqns(m.sstate) == 2
        @steadystate m y = 5
        @test_throws ArgumentError @steadystate m sin(y + 7)
        @test length(m.sstate.constraints) == 1
        @test neqns(m.sstate) == 3
        @test length(alleqns(m.sstate)) == 3
        @steadystate m y = 3
        @test length(m.sstate.constraints) == 1
        @test neqns(m.sstate) == 3
        @test length(alleqns(m.sstate)) == 3
        printsstate(io, m)
        lines = split(String(take!(io)), '\n')
        @test length(lines) == 2 + length(m.allvars)
    end
end

@testset "E1.lin" begin
    m = E1.newmodel()
    m.sstate.mask .= true # declare steadystate solved
    with_linearized(m) do lm
        @test islinearized(lm)
        test_eval_RJ(lm, [0.0], [-0.5 1.0 -0.5 0.0 -1.0 0.0])
        compare_RJ_R!_(lm)
    end
    @test !islinearized(m)
    lm = linearized(m)
    test_eval_RJ(lm, [0.0], [-0.5 1.0 -0.5 0.0 -1.0 0.0])
    compare_RJ_R!_(lm)
    @test islinearized(lm)
    @test !islinearized(m)
    linearize!(m)
    @test islinearized(m)
end

@using_example E1
@testset "E1.params" begin
    let m = E1.newmodel()
        @test propertynames(m.parameters) == (:α, :β)
        @test m.nvarshks == 2
        @test peval(m, :α) == 0.5
        m.β = @link 1.0 - α
        m.parameters.beta = @alias β
        for α = 0.0:0.1:1.0
            m.α = α
            test_eval_RJ(m, [0.0], [-α 1.0 -m.beta 0.0 -1.0 0.0;])
        end
        @test_logs (:warn, r"Model does not have parameters*"i) assign_parameters!(m, γ=0)
    end
    let io = IOBuffer(), m = E1.model
        show(io, m.parameters)
        @test length(split(String(take!(io)), '\n')) == 1
        show(io, MIME"text/plain"(), m.parameters)
        @test length(split(String(take!(io)), '\n')) == 3
    end
end

@using_example E1_noparams
@testset "E1.equation change" begin
    for α = 0.0:0.1:1.0
        new_E1 = E1_noparams.newmodel()
        @equations new_E1 begin
            :maineq => y[t] = $α * y[t-1] + $(1 - α) * y[t+1] + y_shk[t]
        end
        @reinitialize(new_E1)
        test_eval_RJ(new_E1, [0.0], [-α 1.0 -(1 - α) 0.0 -1.0 0.0;])
    end
end

@testset "E1.equation change 2" begin
    m = E1.newmodel()
    @test propertynames(m.parameters) == (:α, :β)
    @test peval(m, :α) == 0.5
    m.parameters.beta = @alias β
    @parameters m begin
        β = 0.5
    end
    m.β = @link 1.0 - α
    @reinitialize(m)
    for α = 0.0:0.1:1.0
        m.α = α
        test_eval_RJ(m, [0.0], [-α 1.0 -m.beta 0.0 -1.0 0.0;])
    end
end

@testset "E1.equation change 3" begin
    m = E1.newmodel()
    @test propertynames(m.parameters) == (:α, :β)
    @test peval(m, :α) == 0.5
    m.parameters.beta = @alias β
    m.β = @link 1.0 - α
    @parameters m begin
        α = 0.5
    end
    @reinitialize(m)
    for α = 0.0:0.1:1.0
        m.α = α
        test_eval_RJ(m, [0.0], [-α 1.0 -m.beta 0.0 -1.0 0.0;])
    end
end


@testset "E1.equation change 4" begin
    # don't recompile existing functions

    modelmodule = E1_noparams

    for i = 1:5
        α = 0.132434
        new_E1 = E1_noparams.newmodel()
        prev_length = length(names(modelmodule, all=true))
        @equations new_E1 begin
            :maineq => y[t] = $α * y[t-1] + $(1 - α) * y[t+1] + y_shk[t]
        end
        @reinitialize(new_E1)
        new_length = length(names(modelmodule, all=true))
        if i == 1
            @test new_length == prev_length + 3
        else
            @test new_length == prev_length
        end
        @test ModelBaseEcon.moduleof(new_E1.equations[:maineq]) === E1_noparams
        # also make sure moduleof doesn't add any new symbols to modules
        @test ModelBaseEcon.moduleof(new_E1) === E1_noparams
        @test new_length == length(names(modelmodule, all=true))
    end
end

module AUX
using ModelBaseEcon
model = Model()
model.substitutions = true
@variables model x y
@equations model begin
    x[t+1] = log(x[t] - x[t-1])
    y[t+1] = y[t] + log(y[t-1])
end
@initialize model
end
@testset "AUX" begin
    let m = AUX.model
        @test m.nvars == 2
        @test m.nshks == 0
        @test m.nauxs == 2
        @test_throws ErrorException m.aux1 = 1
        @test (m.aux1 = update(m.aux1; doc="aux1")) == :aux1
        @test length(m.auxeqns) == ModelBaseEcon.nauxvars(m) == 2
        x = ones(2, 2)
        @test_throws ModelBaseEcon.ModelError ModelBaseEcon.update_auxvars(x, m)
        x = ones(4, 3)
        @test_throws ModelBaseEcon.ModelError ModelBaseEcon.update_auxvars(x, m)
        x = 2 .* ones(4, 2)
        ax = ModelBaseEcon.update_auxvars(x, m; default=0.1)
        @test size(ax) == (4, 4)
        @test x == ax[:, 1:2]  # exactly equal
        @test ax[:, 3:4] ≈ [0.0 0.0; 0.1 log(2.0); 0.1 log(2.0); 0.1 log(2.0)] # computed values, so ≈ equal
        @test propertynames(AUX.model) == (fieldnames(Model)..., :exogenous, :nvars, :nshks, :nauxs, :nexog, :allvars, :varshks, :alleqns,
            keys(AUX.model.options)..., fieldnames(ModelBaseEcon.ModelFlags)..., Symbol[AUX.model.variables...]...,
            Symbol[AUX.model.shocks...]..., keys(AUX.model.parameters)...,)
        @test show(IOBuffer(), m) === nothing
        @test show(IOContext(IOBuffer(), :compact => true), m) === nothing
    end
end


@using_example E2
@testset "E2" begin
    @test length(E2.model.parameters) == 3
    @test length(E2.model.variables) == 3
    @test length(E2.model.shocks) == 3
    @test length(E2.model.equations) == 3
    @test E2.model.maxlag == 1
    @test E2.model.maxlead == 1
    test_eval_RJ(E2.model, [0.0, 0.0, 0.0],
        [-0.5 1 -0.48 0 0 0 0 -0.02 0 0 -1 0 0 0 0 0 0 0
            0 -0.375 0 -0.75 1 0 0 -0.125 0 0 0 0 0 -1 0 0 0 0
            0 0 -0.02 0 0.02 0 -0.5 1 -0.48 0 0 0 0 0 0 0 -1 0])
    compare_RJ_R!_(E2.model)
end


@testset "E2.sstate" begin
    m = E2.newmodel()
    ss = m.sstate
    empty!(ss.constraints)
    out = let io = IOBuffer()
        print(io, ss)
        readlines(seek(io, 0))
    end
    @test length(out) == 2
    @steadystate m pinf = rate + 1
    out = let io = IOBuffer()
        print(io, ss)
        readlines(seek(io, 0))
    end
    @test length(out) == 3
    @test length(split(out[end], "=")) == 3
    @test length(split(out[end], "=>")) == 2
    #
    @test propertynames(ss) == tuple(m.allvars...)
    @test ss.pinf.level == ss.pinf.data[1]
    @test ss.pinf.slope == ss.pinf.data[2]
    ss.pinf.data .= [2.3, 0.7]
    @test ss.values[1:2] == [2.3, 0.7]
    ss.rate.level = 21
    ss.rate.slope = 0.21
    @test ss.rate.level == 21 && ss.rate.slope == 0.21
    @test ss.rate.data == [21, 0.21]
end

@using_example E3
@testset "E3" begin
    @test length(E3.model.parameters) == 3
    @test length(E3.model.variables) == 3
    @test length(E3.model.shocks) == 3
    @test length(E3.model.equations) == 3
    @test ModelBaseEcon.nallvars(E3.model) == 6
    @test ModelBaseEcon.allvars(E3.model) == ModelVariable.([:pinf, :rate, :ygap, :pinf_shk, :rate_shk, :ygap_shk])
    @test ModelBaseEcon.nalleqns(E3.model) == 3
    @test E3.model.maxlag == 2
    @test E3.model.maxlead == 3
    compare_RJ_R!_(E3.model)
    test_eval_RJ(E3.model, [0.0, 0.0, 0.0],
        sparse(
            [1, 1, 2, 1, 3, 1, 1, 2, 2, 3, 3, 3, 1, 2, 3, 3, 1, 2, 3],
            [2, 3, 3, 4, 4, 5, 6, 8, 9, 9, 13, 14, 15, 15, 15, 16, 21, 27, 33],
            [-0.5, 1.0, -0.375, -0.3, -0.02, -0.05, -0.05, -0.75, 1.0, 0.02, -0.25,
                -0.25, -0.02, -0.125, 1.0, -0.48, -1.0, -1.0, -1.0],
            3, 36,
        )
    )
    # @test_throws ModelBaseEcon.ModelNotInitError eval_RJ(zeros(2, 2), ModelBaseEcon.NoModelEvaluationData())
end


@using_example E6
@testset "E6" begin
    @test length(E6.model.parameters) == 2
    @test length(E6.model.variables) == 6
    @test length(E6.model.shocks) == 2
    @test length(E6.model.equations) == 6
    @test E6.model.maxlag == 2
    @test E6.model.maxlead == 3
    compare_RJ_R!_(E6.model)
    nt = 1 + E6.model.maxlag + E6.model.maxlead
    test_eval_RJ(E6.model, [-0.0027, -0.0025, 0.0, 0.0, 0.0, 0.0],
        sparse(
            [2, 2, 2, 3, 5, 2, 2, 2, 1, 1, 3, 4, 1, 3, 6, 5, 5, 4, 4, 6, 6, 2, 1],
            [1, 2, 3, 3, 3, 4, 5, 6, 8, 9, 9, 9, 10, 15, 15, 20, 21, 26, 27, 32, 33, 39, 45],
            [-0.1, -0.1, 1.0, -1.0, -1.0, -0.1, -0.1, -0.1, -0.2, 1.0, -1.0, -1.0, -0.2, 1.0,
                -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0],
            6, 6 * 8,
        ))
end


@testset "VarTypesSS" begin
    let m = Model()
        m.verbose = !true

        @variables m begin
            p
            @log q
        end
        @equations m begin
            2p[t] = p[t+1] + 0.1
            q[t] = p[t] + 1
        end
        @initialize m

        # clear_sstate!(m)
        # ret = sssolve!(m)
        # @test ret ≈ [0.1, 0.0, log(1.1), 0.0]

        eq1, eq2, eq3, eq4 = [eqn_pair[2] for eqn_pair in m.sstate.equations]
        x = rand(Float64, (4,))
        R, J = eq1.eval_RJ(x[eq1.vinds])
        @test R ≈ x[1] - x[2] - 0.1
        @test J ≈ [1.0, -1.0, 0, 0][eq1.vinds]

        for sh = 1:5
            m.shift = sh
            R, J = eq3.eval_RJ(x[eq3.vinds])
            @test R ≈ x[1] + (sh - 1) * x[2] - 0.1
            @test J ≈ [1.0, sh - 1.0, 0, 0][eq3.vinds]
        end

        R, J = eq2.eval_RJ(x[eq2.vinds])
        @test R ≈ exp(x[3]) - x[1] - 1
        @test J ≈ [-1, 0.0, exp(x[3]), 0.0][eq2.vinds]

        for sh = 1:5
            m.shift = sh
            R, J = eq4.eval_RJ(x[eq4.vinds])
            @test R ≈ exp(x[3] + sh * x[4]) - x[1] - sh * x[2] - 1
            @test J ≈ [-1.0, -sh, exp(x[3] + sh * x[4]), exp(x[3] + sh * x[4]) * sh][eq4.vinds]
        end

    end

    let m = Model()
        @variables m begin
            lx
            @log x
        end
        @shocks m s1 s2
        @equations m begin
            "linear growth with slope 0.2"
            lx[t] = lx[t-1] + 0.2 + s1[t]
            "exponential with the same rate as the slope of lx"
            log(x[t]) = lx[t] + s2[t+1]
        end
        @initialize m
        #
        @test nvariables(m) == 2
        @test nshocks(m) == 2
        @test nequations(m) == 2
        ss = sstate(m)
        @test neqns(ss) == 4
        eq1, eq2, eq3, eq4 = [eqn_pair[2] for eqn_pair in ss.equations]
        @test length(ss.values) == 2 * length(m.allvars)
        #
        # test with eq1
        ss.lx.data .= [1.5, 0.2]
        ss.x.data .= [0.0, 0.2]
        ss.s1.data .= [0.0, 0.0]
        ss.s2.data .= [0.0, 0.0]
        for s1 = -2:0.1:2
            ss.s1.level = s1
            @test eq1.eval_resid(ss.values[eq1.vinds]) ≈ -s1
        end
        ss.s1.level = 0.0
        for lxslp = -2:0.1:2
            ss.lx.slope = lxslp
            @test eq1.eval_resid(ss.values[eq1.vinds]) ≈ lxslp - 0.2
        end
        ss.lx.slope = 0.2
        R, J = eq1.eval_RJ(ss.values[eq1.vinds])
        TMP = fill!(similar(ss.values), 0.0)
        TMP[eq1.vinds] .= J
        @test R == 0
        @test TMP[[1, 2, 5]] ≈ [0.0, 1.0, -1.0]
        # test with eq4
        ss.lx.data .= [1.5, 0.2]
        ss.x.data .= [1.5, 0.2]
        ss.s1.data .= [0.0, 0.0]
        ss.s2.data .= [0.0, 0.0]
        for s2 = -2:0.1:2
            ss.s2.level = s2
            @test eq4.eval_resid(ss.values[eq4.vinds]) ≈ -s2
        end
        ss.s2.level = 0.0
        for lxslp = -2:0.1:2
            ss.lx.slope = lxslp
            @test eq4.eval_resid(ss.values[eq4.vinds]) ≈ m.shift * (0.2 - lxslp)
        end
        ss.lx.slope = 0.2
        for xslp = -2:0.1:2
            ss.x.data[2] = xslp
            @test eq4.eval_resid(ss.values[eq4.vinds]) ≈ m.shift * (xslp - 0.2)
        end
        ss.x.slope = exp(0.2)
        R, J = eq4.eval_RJ(ss.values[eq4.vinds])
        TMP = fill!(similar(ss.values), 0.0)
        TMP[eq4.vinds] .= J
        @test R + 1.0 ≈ 0.0 + 1.0
        @test TMP[[1, 2, 3, 4, 7]] ≈ [-1.0, -m.shift, 1.0, m.shift, -1.0]
        for xlvl = 0.1:0.1:2
            ss.x.level = exp(xlvl)
            R, J = eq4.eval_RJ(ss.values[eq4.vinds])
            @test R ≈ xlvl - 1.5
            TMP[eq4.vinds] .= J
            @test TMP[[1, 2, 3, 4, 7]] ≈ [-1.0, -m.shift, 1.0, m.shift, -1.0]
        end
    end
end

@testset "bug #28" begin
    let
        m = Model()
        @variables m (@log(a); la)
        @equations m begin
            a[t] = exp(la[t])
            la[t] = 20
        end
        @initialize m
        assign_sstate!(m, a=20, la=log(20))
        @test m.sstate.a.level ≈ 20 atol = 1e-14
        @test m.sstate.a.slope == 1.0
        @test m.sstate.la.level ≈ log(20) atol = 1e-14
        @test m.sstate.la.slope == 0.0
        assign_sstate!(m, a=(level=20,), la=[log(20), 0])
        @test m.sstate.a.level ≈ 20 atol = 1e-14
        @test m.sstate.a.slope == 1.0
        @test m.sstate.la.level ≈ log(20) atol = 1e-14
        @test m.sstate.la.slope == 0.0
    end
end

@testset "lin" begin
    let m = Model()
        @variables m a
        @equations m begin
            a[t] = 0
        end
        @initialize m
        # steady state not solved
        fill!(m.sstate.mask, false)
        @test_throws ModelBaseEcon.LinearizationError linearize!(m)
        m.sstate.values .= rand(2)
        # steady state with non-zero slope
        fill!(m.sstate.mask, true)
        m.sstate.values .= 1.0
        @test_throws ModelBaseEcon.LinearizationError linearize!(m)
        # succeed
        m.sstate.values .= 0.0
        @test (linearize!(m); islinearized(m))
        delete!(m.evaldata, :linearize)
        @test_throws ErrorException with_linearized(m) do m
            error("hello")
        end
        @test !ModelBaseEcon.hasevaldata(m, :linearize)
    end
end

@testset "sel_lin" begin
    let
        m = Model()
        @variables m (la; @log a)
        @equations m begin
            @lin a[t] = exp(la[t])
            @lin la[t] = 2
        end
        @initialize m
        assign_sstate!(m; a=exp(2), la=2)
        @test_nowarn (selective_linearize!(m); true)
    end
end

include("auxsubs.jl")
include("sstate.jl")

@using_example E3
@testset "print_linearized" begin
    m = E3.newmodel()
    m.cp[1] = 0.9383860755808812
    fill!(m.sstate.values, 0)
    fill!(m.sstate.mask, true)
    delete!(m.evaldata, :linearize)
    @test_throws ArgumentError print_linearized(m)
    linearize!(m)
    io = IOBuffer()
    print_linearized(io, m, compact=false)
    seekstart(io)
    lines = readlines(io)
    @test length(lines) == 3
    @test lines[1] == " 0 = -0.9383860755808812*pinf[t - 1] +pinf[t] -0.3*pinf[t + 1] -0.05*pinf[t + 2] -0.05*pinf[t + 3] -0.02*ygap[t] -pinf_shk[t]"
    @test lines[2] == " 0 = -0.375*pinf[t] -0.75*rate[t - 1] +rate[t] -0.125*ygap[t] -rate_shk[t]"
    @test lines[3] == " 0 = -0.02*pinf[t + 1] +0.02*rate[t] -0.25*ygap[t - 2] -0.25*ygap[t - 1] +ygap[t] -0.48*ygap[t + 1] -ygap_shk[t]"
    out = sprint(print_linearized, m)
    @test startswith(out, " 0 = -0.938386*pinf[t - 1] +")
end


@testset "Model edits, autoexogenize" begin
    m = E2.newmodel()

    @test length(m.autoexogenize) == 3
    @test m.autoexogenize[:pinf] == :pinf_shk
    @test m.autoexogenize[:rate] == :rate_shk

    @autoexogenize m @delete ygap = ygap_shk
    @test length(m.autoexogenize) == 2
    @test !haskey(m.autoexogenize, :ygap)

    @autoexogenize m ygap = ygap_shk
    @test length(m.autoexogenize) == 3
    @test m.autoexogenize[:ygap] == :ygap_shk

    @autoexogenize m begin
        @delete ygap = ygap_shk
    end
    @test length(m.autoexogenize) == 2
    @test !haskey(m.autoexogenize, :ygap)

    @autoexogenize m begin
        ygap = ygap_shk
    end
    @test length(m.autoexogenize) == 3
    @test m.autoexogenize[:ygap] == :ygap_shk

    m = E2.newmodel()
    @autoexogenize m begin
        @delete (ygap = ygap_shk) (pinf = pinf_shk)
    end
    @test length(m.autoexogenize) == 1
    @test !haskey(m.autoexogenize, :ygap)
    @test !haskey(m.autoexogenize, :pinf)

    # using shock to remove key
    m = E2.newmodel()
    @autoexogenize m begin
        @delete ygap_shk = ygap
    end
    @test length(m.autoexogenize) == 2
    @test !haskey(m.autoexogenize, :ygap)

    m = E2.newmodel()
    @autoexogenize m begin
        @delete ygap_shk => ygap
    end
    @test length(m.autoexogenize) == 2
    @test !haskey(m.autoexogenize, :ygap)

    m = E2.newmodel()
    @test_logs (:warn, r"Cannot remove autoexogenize ygap2 => ygap2_shk.\nNeither ygap2 nor ygap2_shk are entries in the autoexogenize list."i) @autoexogenize m @delete ygap2 = ygap2_shk
    @test_logs (:warn, r"Cannot remove autoexogenize ygap => ygap2_shk.\nThe paired symbol for ygap is ygap_shk."i) @autoexogenize m @delete ygap = ygap2_shk
    @test_logs (:warn, r"Cannot remove autoexogenize ygap2_shk => ygap.\nThe paired symbol for ygap is ygap_shk."i) @autoexogenize m @delete ygap2_shk = ygap
    @test_logs (:warn, r"Cannot remove autoexogenize ygap_shk => ygap2.\nThe paired symbol for ygap_shk is ygap."i) @autoexogenize m @delete ygap_shk = ygap2
    @test_logs (:warn, r"Cannot remove autoexogenize ygap2 => ygap_shk.\nThe paired symbol for ygap_shk is ygap."i) @autoexogenize m @delete ygap2 = ygap_shk

end

@testset "Model edits, variables" begin
    m = E2.newmodel()

    @test length(m.variables) == 3

    @variables m @delete pinf rate
    @test length(m.variables) == 1

    @variables m pinf rate
    @test length(m.variables) == 3

    @variables m begin
        @delete pinf rate
    end
    @test length(m.variables) == 1

    @variables m (pinf; rate)
    @test length(m.variables) == 3

    @variables m begin
        @delete pinf
        @delete rate
    end
    @test length(m.variables) == 1

    @variables m (@delete ygap; rate)
    @test length(m.variables) == 1
    @test m.variables[1].name == :rate

end

@testset "Model edits, shocks" begin
    m = E2.newmodel()

    @test length(m.shocks) == 3

    @shocks m @delete pinf_shk rate_shk
    @test length(m.shocks) == 1

    @shocks m pinf_shk rate_shk
    @test length(m.shocks) == 3

    @shocks m begin
        @delete pinf_shk rate_shk
    end
    @test length(m.shocks) == 1

    @shocks m (pinf_shk; rate_shk)
    @test length(m.shocks) == 3

    @shocks m begin
        @delete pinf_shk
        @delete rate_shk
    end
    @test length(m.shocks) == 1

    @shocks m (@delete ygap_shk; rate_shk)
    @test length(m.shocks) == 1
    @test m.shocks[1].name == :rate_shk

end

@testset "Model edits, steadystate" begin
    m = S1.newmodel()

    @test length(m.sstate.constraints) == 1
    @parameters m begin
        b_ss = 1.2
    end
    @steadystate m begin
        @delete _SSEQ1
        @level a = a_ss
        @slope b = b_ss
    end
    @test length(m.sstate.constraints) == 2

    # @test_throws MethodError @steadystate @somethingelse b = b_ss


end

@testset "Model edits, equations" begin
    m = S1.newmodel()

    @equations m begin
        @delete _EQ2
    end

    @test length(m.equations) == 2
    @test collect(keys(m.equations)) == [:_EQ1, :_EQ3]

    @test_logs(
        (:warn, "Model contains unused shocks: [:b_shk]"),
        (:warn, "Model contains different numbers of equations (2) and endogenous variables (3)."),
        @reinitialize m)

    @equations m begin
        b[t] = @sstate(b) * (1 - α) + α * b[t-1] + b_shk[t]
    end

    @test length(m.equations) == 3
    @test collect(keys(m.equations)) == [:_EQ1, :_EQ3, :_EQ4]


    maux = deepcopy(AUX.model)
    @test length(maux.equations) == 2
    @test length(maux.alleqns) == 4
    @equations maux begin
        @delete _EQ1
    end
    @test length(maux.equations) == 1
    @test length(maux.alleqns) == 2
    @equations maux begin
        x[t+1] = log(x[t] - x[t-1])
    end
    @test length(maux.equations) == 2
    @test length(maux.alleqns) == 4

    # option to not show a warning
    m = S1.newmodel()

    @equations m begin
        @delete _EQ2
    end

    @test length(m.equations) == 2
    @test collect(keys(m.equations)) == [:_EQ1, :_EQ3]
    m.options.unused_varshks = [:b_shk]

    @test_logs (:warn, "Model contains different numbers of equations (2) and endogenous variables (3).") @reinitialize m

    # option to not show a warning
    m = S1.newmodel()
    @equations m begin
        @delete _EQ1
    end
    @steadystate m begin
        @delete _SSEQ1
    end
    m.options.unused_varshks = [:a]
    @test_logs (:warn, "Model contains different numbers of equations (2) and endogenous variables (3).") @reinitialize m
end

@using_example E2sat
m2_for_sattelite_tests = E2sat.newmodel()
@testset "satellite models" begin
    m1 = E2.newmodel()

    m_sattelite = Model()

    @parameters m_sattelite begin
        _parent = E2.model
        cx = @link _parent.cp
    end
    @test m1.cp == [0.5, 0.02]
    @test m_sattelite.cx == [0.5, 0.02]

    m1.cp = [0.6, 0.03]
    @test m1.cp == [0.6, 0.03]

    m_sattelite.parameters._parent = m1.parameters
    update_links!(m_sattelite)
    @test m_sattelite.cx == [0.6, 0.03]

    # m2_for_sattelite_tests = E2sat.newmodel()
    m2_sattelite = deepcopy(E2sat.satmodel)

    m2_for_sattelite_tests.cp = [0.7, 0.05]

    @test m2_for_sattelite_tests.cp == [0.7, 0.05]
    @test m2_sattelite.cz == [0.5, 0.02]
    @replaceparameterlinks m2_sattelite E2sat.model => m2_for_sattelite_tests
    @test m2_sattelite.cz == [0.7, 0.05]
    m2_for_sattelite_tests.cp = [0.3, 0.08]
    update_links!(m2_sattelite.parameters)
    @test m2_sattelite.cz == [0.3, 0.08]

end
m2_for_sattelite_tests = nothing

@testset "Model find" begin
    m = E3.newmodel()
    @test length(findequations(m, :cr; verbose=false)) == 1
    @test length(findequations(m, :pinf; verbose=false)) == 3

    @test find_main_equation(m, :rate) == :_EQ2

    @test findequations(S1.model, :a; verbose=false) == [:_EQ1, :_SSEQ1]

    @test_logs (:debug, ":_EQ2 => rate[t] = cr[1] * rate[t - 1] + ((1 - cr[1]) * (cr[2] * pinf[t] + cr[3] * ygap[t]) + rate_shk[t])")

    original_stdout = stdout
    (read_pipe, write_pipe) = redirect_stdout()
    findequations(m, :cr)
    redirect_stdout(original_stdout)
    close(write_pipe)
    @test readline(read_pipe) == ":_EQ2 => \e[38;2;29;120;116mrate\e[39m[t] = \e[38;2;244;192;149;1mcr\e[39;22m[1] * \e[38;2;29;120;116mrate\e[39m[t - 1] + ((1 - \e[38;2;244;192;149;1mcr\e[39;22m[1]) * (\e[38;2;244;192;149;1mcr\e[39;22m[2] * \e[38;2;29;120;116mpinf\e[39m[t] + \e[38;2;244;192;149;1mcr\e[39;22m[3] * \e[38;2;29;120;116mygap\e[39m[t]) + \e[38;2;238;46;49mrate_shk\e[39m[t])"

end

@testset "misc codecoverage" begin
    m = E2.newmodel()
    @test_throws ErrorException m.pinf_shk = m.rate_shk

    pinf = ModelVariable(:pinf)
    m.pinf = pinf
    @test m.pinf isa ModelVariable
end

@testset "fix#58" begin
    @using_example E7

    m = E7.newmodel()

    @test length(m.equations) == 7 && length(m.auxeqns) == 2
    @equations m begin
        @delete _EQ6
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 2
    @equations m begin
        @delete :_EQ7
    end
    @test length(m.equations) == 5 && length(m.auxeqns) == 1
    @test_throws ArgumentError @equations m begin
        :E6 => ly[t] - ly[t-1]
    end
    @test length(m.equations) == 5 && length(m.auxeqns) == 1

    @equations m begin
        dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:_EQ6]; eq.doc == "" && eq.name == :_EQ6 && !islin(eq) && !islog(eq))
    @equations m begin
        @delete _EQ6
        :E6 => dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:E6]; eq.doc == "" && eq.name == :E6 && !islin(eq) && !islog(eq))
    @equations m begin
        :E6 => @log dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:E6]; eq.doc == "" && eq.name == :E6 && !islin(eq) && islog(eq))
    @equations m begin
        :E6 => @lin dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:E6]; eq.doc == "" && eq.name == :E6 && islin(eq) && !islog(eq))

    @equations m begin
        @delete E6
        "equation 6"
        dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:_EQ6]; eq.doc == "equation 6" && eq.name == :_EQ6 && !islin(eq) && !islog(eq))
    @equations m begin
        @delete _EQ6
        "equation 6"
        :E6 => dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:E6]; eq.doc == "equation 6" && eq.name == :E6 && !islin(eq) && !islog(eq))
    @equations m begin
        "equation 6"
        :E6 => @log dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:E6]; eq.doc == "equation 6" && eq.name == :E6 && !islin(eq) && islog(eq))
    @equations m begin
        "equation 6"
        :E6 => @lin dly[t] = ly[t] - ly[t-1]
    end
    @test length(m.equations) == 6 && length(m.auxeqns) == 1
    @test (eq = m.equations[:E6]; eq.doc == "equation 6" && eq.name == :E6 && islin(eq) && !islog(eq))
end

@testset "fix#63" begin
    let model = Model()
        @variables model y
        @shocks model y_shk
        @parameters model p = 0.2
        @equations model begin
            y[t] = p[t] * y[t-1] + y_shk[t]
        end
        # test the exception type
        @test_throws ArgumentError @initialize model
        # test the error message
        if Base.VERSION >= v"1.8"
            # this version of @test_throws requires Julia 1.8
            @test_throws r".*Indexing parameters on time not allowed: p[t]*"i @initialize model
        end

        # do not allow multiple indexing of variables
        @equations model begin
            @delete :_EQ1
            y[t, 1] = p[t] * y[t-1] + y_shk[t]
        end
        @test_throws ArgumentError @initialize model
        Base.VERSION >= v"1.8" && @test_throws r".*Multiple indexing of variable or shock: y[t, 1]*"i @initialize model
    end
end


@testset "issue68" begin
    # Parameters with more than one index are parsed incorrectly (fixed by PR#67)
    # This test fails in v0.6.2, fixed as of v0.6.3
    let model = Model()
        @variables model x
        @shocks model e
        @parameters model begin
            c = [0.1 0.2]
        end
        @equations model begin
            :E1 => x[t] = c[1, 1] * x[t-1] + c[1, 2] * x[t-2] + e[t]
        end
        @initialize model
        x = Float64[0, 0.375, 0.128, 0]
        x[1] = model.parameters.c[1] * x[2] + model.parameters.c[2] * x[3]
        eq = model.equations[:E1]
        @test 0 == eq.eval_resid(x)
    end
end

@testset "equation_parentheses" begin
    @test_warn "Model contains different numbers of equations (3) and endogenous variables (1)." let model = Model()
        @variables model x
        @equations model begin
            :EQ_x1 => (x[t] = 0)
            (x[t] = 0)
            :EQ_x1 => (@lin x[t] = 0)
            (@lin x[t] = 0)
        end
        @initialize(model)
        true
    end
end

@testset "eval_equation" begin
    model = Model()
    @parameters model p = 0.1
    @variables model x
    @shocks model x_shk
    @equations model begin
        :EQ01 => x[t] = (1 - 0.50) * @sstate(x) + 0.25 * x[t-1] + 0.25 * x[t+1] + x_shk[t]
    end
    @initialize model
    @steadystate model x = 2.0
    model.sstate.x.level = 2.0
    sim_data = [0.5 0.0;
        1.5980861244019138 0.0;
        1.8923444976076556 0.0;
        1.9712918660287082 0.0;
        1.992822966507177 0.0;
        2.0 0.0]

    eqtn = model.equations[:EQ01]
    res = eval_equation(model, eqtn, sim_data)
    @test isnan(res[1]) && isapprox(res[2:5], [0.0, 0.0, 0.0, 0.0]; atol=1e-12) && isnan(res[6])

    sim_data[3, 1] += 1
    @test eval_equation(model, eqtn, sim_data, 3:4) ≈ [1.0, -0.25]

    @test_throws AssertionError eval_equation(model, eqtn, sim_data, 1:7)
end

include("dfmmodels.jl")

nothing
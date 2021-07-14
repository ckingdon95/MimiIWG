
# helper function for linear interpolation
function _interpolate(values, orig_x, new_x)
    itp = extrapolate(
                interpolate((orig_x,), Array{Float64,1}(values), Gridded(Linear())), 
                Line())
    return itp(new_x)
end


# helper function for connecting a list of (compname, paramname) pairs all to the same source pair
function connect_all!(m::Model, comps::Vector{Pair{Symbol, Symbol}}, src::Pair{Symbol, Symbol})
    for dest in comps 
        connect_param!(m, dest, src)
    end
end
    
#helper function for connecting a list of compnames all to the same source pair. The parameter name in all the comps must be the same as in the src pair.
function connect_all!(m::Model, comps::Vector{Symbol}, src::Pair{Symbol, Symbol})
    src_comp, param = src
    for comp in comps 
        connect_param!(m, comp=>param, src_comp=>param)
    end
end

# helper function for writing the SCC values to files at the end of a monte carlo simulation
function write_scc_values(values, output_dir, perturbation_years, discount_rates; domestic=false)
    mkpath(output_dir)
    for scenario in scenarios, (j, rate) in enumerate(discount_rates)   # separate file for each scenario/discount combo
        i, scenario_name = Int(scenario), string(scenario)

        filename = domestic ? "$scenario_name $rate domestic.csv" : "$scenario_name $rate.csv"
        filepath = joinpath(output_dir, filename)

        open(filepath, "w") do f
            write(f, join(perturbation_years, ","), "\n")   # each column is a different SCC year, each row is a different trial result
            writedlm(f, values[:, :, i, j], ',')
        end
    end
end

# helper function for computing percentile tables at the end of a monte carlo simulation
function make_percentile_tables(output_dir, gas, discount_rates, perturbation_years, drop_discontinuities=false)
    scc_dir = "$output_dir/SC-$gas"     # folder with output from the MCS runs
    drop_discontinuities ? disc_dir = joinpath(output_dir, "discontinuity_mismatch/") : nothing
    tables = "$output_dir/Tables/Percentiles"   # folder to save TSD tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    pcts = [.01, .05, .1, .25, .5, :avg, .75, .90, .95, .99]

    for dr in discount_rates, (idx, year) in enumerate(perturbation_years)
        table = joinpath(tables, "$year SC-$gas Percentiles - $(dr*100)%.csv")
        open(table, "w") do f 
            write(f, "Scenario,1st,5th,10th,25th,50th,Avg,75th,90th,95th,99th\n")
            for fn in filter(x -> endswith(x, "$dr.csv"), results)  # Get the results files for this discount rate
                scenario = split(fn)[1] # get the scenario name
                d = readdlm(joinpath(scc_dir, fn), ',')[2:end, idx]
                if drop_discontinuities
                    disc_idx = convert(Array{Bool}, readdlm(joinpath(disc_dir, fn), ',')[2:end, idx])
                    d = d[map(!, disc_idx)]    
                end
                filter!(x->!isnan(x), d)
                values = [pct == :avg ? Int(round(mean(d))) : Int(round(quantile(d, pct))) for pct in pcts]
                write(f, "$scenario,", join(values, ","), "\n")
            end 
        end
    end
    nothing  
end

# helper funcion for computing std error tables at the end of a monte carlo simulation
function make_stderror_tables(output_dir, gas, discount_rates, perturbation_years, drop_discontinuities=false)
    scc_dir = "$output_dir/SC-$gas"     # folder with output from the MCS runs
    drop_discontinuities ? disc_dir = joinpath(output_dir, "discontinuity_mismatch/") : nothing
    tables = "$output_dir/Tables/Std Errors"   # folder to save the tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    for dr in discount_rates, (idx, year) in enumerate(perturbation_years)
        table = joinpath(tables, "$year SC-$gas Std Errors - $(dr*100)%.csv")
        open(table, "w") do f 
            write(f, "Scenario,Mean,SE\n")
            for fn in filter(x -> endswith(x, "$dr.csv"), results)  # Get the results files for this discount rate
                scenario = split(fn)[1] # get the scenario name
                d = readdlm(joinpath(scc_dir, fn), ',')[2:end, idx] 
                if drop_discontinuities
                    disc_idx = convert(Array{Bool}, readdlm(joinpath(disc_dir, fn), ',')[2:end, idx])
                    d = d[map(!, disc_idx)]    
                end
                filter!(x->!isnan(x), d)
                write(f, "$scenario, $(round(mean(d), digits=2)), $(round(sem(d), digits=2)) \n")
            end 
        end
    end
    nothing  
end

# helper function for computing a summary table. Reports average values for all discount rates and years, and high impact values (95th pct)
function make_summary_table(output_dir, gas, discount_rates, perturbation_years, drop_discontinuities=false)

    scc_dir = "$output_dir/SC-$gas"     # folder with output from the MCS runs
    drop_discontinuities ? disc_dir = joinpath(output_dir, "discontinuity_mismatch/") : nothing
    tables = "$output_dir/Tables"   # folder to save the table to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    data = Array{Any, 2}(undef, length(perturbation_years)+1, 2*length(discount_rates)+1)
    data[1, :] = ["Year", ["$(r*100)% Average" for r in discount_rates]..., ["High Impact (95th Pct at $(r*100)%)" for r in discount_rates]...]
    data[2:end, 1] = perturbation_years

    for (j, dr) in enumerate(discount_rates)
        vals = Matrix{Union{Missing, Float64}}(undef, 0, length(perturbation_years))
        for scenario in scenarios
            curr_vals = convert(Array{Union{Missing, Float64}}, readdlm(joinpath(scc_dir, "$(string(scenario)) $dr.csv"), ',')[2:end, :])
            if drop_discontinuities
                disc_idx = convert(Array{Bool}, readdlm(joinpath(disc_dir, "$(string(scenario)) $dr.csv"), ',')[2:end, :])
                curr_vals[disc_idx] .= missing
            end
            vals = vcat(vals, curr_vals)
        end
        data[2:end, j+1] = mapslices(x -> mean(skipmissing(x)), vals, dims=1)[:]
        data[2:end, j+1+length(discount_rates)] = [quantile(skipmissing(vals[2:end, y]), .95) for y in 1:length(perturbation_years)]
    end

    table = joinpath(tables, "Summary Table.csv")
    writedlm(table, data, ',')
    nothing 
end

function discrete_df(prtp, eta, g)
    r = prtp .+ eta .* g     # calculate annual discount rates
    df = [1, [prod([(1 + r[i])^-1 for i in 2:t]) for t in 2:length(r)]...] # calculate the discount factor for each year using discrete time discounting
    return df
end

# marginaldamages: stream of global marginal damages starting in the scc emission year
# g: stream of annual global gdp/cap growth rates starting in the scc emission year 
function scc_discrete(marginaldamages, prtp, eta, g; timestep=1)
    discount_factor = discrete_df(prtp, eta, g)   
    npv_md = discount_factor .* marginaldamages * timestep    # calculate net present value of marginal damages in each year
    scc = sum(npv_md)    # sum damages to the scc
    return scc
end

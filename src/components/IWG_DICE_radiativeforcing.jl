# Difference from the original DICE radiativeforcing component:
#   - In the final timestep, the IWG calculates MAT_avg differently
@defcomp IWG_DICE_radiativeforcing begin
    FORC      = Variable(index=[time])   # Increase in radiative forcing (watts per m2 from 1900)

    forcoth   = Parameter(index=[time])  # Exogenous forcing for other greenhouse gases
    MAT       = Parameter(index=[time])  # Carbon concentration increase in atmosphere (GtC from 1750)
    fco22x    = Parameter()              # Forcings of equilibrium CO2 doubling (Wm-2)


    function run_timestep(p, v, d, t)

        if !is_last(t)
            MAT_avg = (p.MAT[t] + p.MAT[t + 1]) / 2
        else 
            MAT_avg = 0.9796 * (p.MAT[t - 1] + p.MAT[t]) / 2
        end

        v.FORC[t] = p.fco22x * (log((MAT_avg + 0.000001) / 596.4) / log(2)) + p.forcoth[t]

    end

end
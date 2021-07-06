# Since the IWG sampled from the Roe & Baker distribution for equilibrium climate sensitivity (t2xco2), they added in the catch case for values less than 0.5 in the code below.
@defcomp IWG_DICE_climatedynamics begin

    TATM    = Variable(index=[time])    # Increase in temperature of atmosphere (degrees C from 1900)
    TOCEAN  = Variable(index=[time])    # Increase in temperature of lower oceans (degrees C from 1900)
    TA_eq   = Variable(index=[time])    

    FORC    = Parameter(index=[time])   # Increase in radiative forcing (watts per m2 from 1900)
    fco22x  = Parameter()               # Forcings of equilibrium CO2 doubling (Wm-2)
    t2xco2  = Parameter(default=3)      # Equilibrium temp impact (oC per doubling CO2)
    tatm0   = Parameter()               # Initial atmospheric temp change (C from 1900) in 2005
    tocean0 = Parameter()               # Initial lower stratum temp change (C from 1900)

    # Transient TSC Correction ("Speed of Adjustment Parameter")
    c1 = Parameter()                    # Speed of adjustment parameter for atmospheric temperature
    c3 = Parameter()                    # Coefficient of heat loss from atmosphere to oceans
    c4 = Parameter()                    # Coefficient of heat gain by deep oceans.


    function run_timestep(p, v, d, t)

        # TA_eq added by EPA "to avoid over- and under-shoots to eq T when CS is very low
        if is_first(t)
            v.TA_eq[t] = 0.083
        else
            v.TA_eq[t] = p.FORC[t] * p.t2xco2 / p.fco22x
        end

        # Define function for TATM
        if is_first(t)
            v.TATM[t] = p.tatm0
        elseif p.t2xco2 < 0.5
            v.TATM[t] = v.TA_eq[t]
        else
            v.TATM[t] = v.TATM[t - 1] + p.c1 * ((p.FORC[t] - (p.fco22x / p.t2xco2) * v.TATM[t - 1]) - (p.c3 * (v.TATM[t - 1] - v.TOCEAN[t - 1])))
        end

        # Define function for TOCEAN
        if is_first(t)
            v.TOCEAN[t] = p.tocean0
        else
            v.TOCEAN[t] = v.TOCEAN[t - 1] + p.c4 * (v.TATM[t - 1] - v.TOCEAN[t - 1])
        end

    end

end
# The difference in this component compared to the original neteconomy component in DICE2010 is the simlified function for calculating C.
#       In the original component, there are different values for the first and last timestep calculations of C.
@defcomp IWG_DICE_neteconomy begin

    ABATECOST   = Variable(index=[time])    # Cost of emissions reductions  (trillions 2005 USD per year)
    C           = Variable(index=[time])    # Consumption (trillions 2005 US dollars per year)
    CPC         = Variable(index=[time])    # Per capita consumption (thousands 2005 USD per year)
    CPRICE      = Variable(index=[time])    # Carbon price (2005$ per ton of CO2)
    I           = Variable(index=[time])    # Investment (trillions 2005 USD per year)
    Y           = Variable(index=[time])    # Gross world product net of abatement and damages (trillions 2005 USD per year)
    YNET        = Variable(index=[time])    # Output net of damages equation (trillions 2005 USD per year)

    cost1       = Parameter(index=[time])   # Abatement cost function coefficient
    DAMFRAC     = Parameter(index=[time])   # Damages (fraction of gross output)
    l           = Parameter(index=[time])   # Level of population and labor
    MIU         = Parameter(index=[time])   # Emission control rate GHGs
    partfract   = Parameter(index=[time])   # Fraction of emissions in control regime
    pbacktime   = Parameter(index=[time])   # Backstop price
    S           = Parameter(index=[time])   # Gross savings rate as fraction of gross world product
    YGROSS      = Parameter(index=[time])   # Gross world product GROSS of abatement and damages (trillions 2005 USD per year)
    expcost2    = Parameter()               # Exponent of control cost function


    function run_timestep(p, v, d, t)

        # Define function for YNET
        v.YNET[t] = p.YGROSS[t] / (1 + p.DAMFRAC[t])

        # Define function for ABATECOST
        v.ABATECOST[t] = p.YGROSS[t] * p.cost1[t] * (p.MIU[t]^p.expcost2) * (p.partfract[t]^(1 - p.expcost2))

        # Define function for Y
        v.Y[t] = v.YNET[t] - v.ABATECOST[t]

        # Define function for I
        v.I[t] = p.S[t] * v.Y[t]

        # Define function for C
        v.C[t] = v.Y[t] - v.I[t]

        # Define function for CPC
        v.CPC[t] = 1000 * v.C[t] / p.l[t]

        # Define function for CPRICE
        if t.t == 26
            v.CPRICE[t] = v.CPRICE[t - 1]
        else
            v.CPRICE[t] = p.pbacktime[t] * 1000 * p.MIU[t]^(p.expcost2 - 1)
        end

    end

end

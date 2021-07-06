@defcomp IWG_DICE_simple_gas_cycle begin

    # Output: forcing
    F_CH4 = Variable(index=[decades])    # Path of CH4 forcing [W/m^2] - decadal time step
    F_N2O = Variable(index=[decades])    # Path of N2O forcing [W/m^2] - decadal time step

    # Input: emissions
    E_CH4A = Parameter(index=[time])  # Annual CH4 emissions
    E_N2OA = Parameter(index=[time])  # Annual N2O emissions

    # Atmospheric concentration dynamics coefficients
    delta_ch4 = Parameter(default=1 / 12)   # Annual rate of decay of CH4 (IPCC FAR)
    gamma_ch4 = Parameter(default=0.3597) # Mass to volume conversion factor [ppb CH4/Mt CH4]
    alpha_ch4 = Parameter(default=0.036)  # Radiative forcing parameter (TAR page 358)
    delta_n2o = Parameter(default=1 / 114)  # Rate of decay of N2O (IPCC FAR)
    gamma_n2o = Parameter(default=0.2079) # Mass to volume conversion factor [ppb N2O/Mt N]
    alpha_n2o = Parameter(default=0.12)   # Radiative forcing parameter    
    ipcc_adj =  Parameter(default=1.4)    # IPCC AR4 adjustment for tropospheric ozone effect (25%) and stratospheric water vapor effect (15%)

    M_pre = Parameter(default=700)    # Pre-industrial CH4 concentrations [ppb](TAR page 358)
    N_pre = Parameter(default=270)    # Pre-industrial N2O concentrations [ppb](TAR page 358)
    
    M_AA_2005 = Parameter(default=1774)  # 2005 concentration of CH4
    N_AA_2005 = Parameter(default=319)   # 2005 concentration of N2O

    # Other intermediate variables to calculate
    M_AA     = Variable(index=[time]) # Atmospheric CH4 concentration (annual)
    F_CH4A   = Variable(index=[time]) # Contribution of atmospheric CH4 to radiative forcing (annual)
    N_AA     = Variable(index=[time]) # Atmospheric N2O concentration (annual)
    F_N2OA   = Variable(index=[time]) # Contribution of atmospheric N2O to radiative forcing (annual)
    pre_f    = Variable()    # pre-industrial interaction effect

    function run_timestep(p, v, d, t)

        function f(M_A, N_A)
            # calculate the interaction effect on radiative forcing
            return 0.47 * log(1 + 2.01 * 10^-5 * (M_A * N_A)^0.75 + 5.31 * 10^-15 * M_A * (M_A * N_A)^1.52)
        end

        # Calculate the annual atmospheric concentrations
        if is_first(t)
            v.M_AA[t] = p.M_AA_2005
            v.N_AA[t] = p.N_AA_2005  

            v.pre_f = f(p.M_pre, p.N_pre)   # only need to calculate this once; used in each timestep below
        else
            v.M_AA[t] = (1 - p.delta_ch4) * v.M_AA[t - 1] + p.delta_ch4 * p.M_pre + p.gamma_ch4 * p.E_CH4A[t - 1]
            v.N_AA[t] = (1 - p.delta_n2o) * v.N_AA[t - 1] + p.delta_n2o * p.N_pre + p.gamma_n2o * (28 / 44) * p.E_N2OA[t - 1]
        end

        # Calculate the annual forcing
        v.F_CH4A[t] = p.ipcc_adj * (p.alpha_ch4 * (sqrt(v.M_AA[t]) - sqrt(p.M_pre)) - (f(v.M_AA[t], p.N_pre) - v.pre_f))
        v.F_N2OA[t] = p.alpha_n2o * (sqrt(v.N_AA[t]) - sqrt(p.N_pre)) - (f(p.M_pre, v.N_AA[t]) - v.pre_f)

        # calculate the decadal forcing at the end
        if is_last(t)
            v.F_CH4[:] = mean(reshape(v.F_CH4A[:], 10, length(d.decades)), dims=1)
            v.F_N2O[:] = mean(reshape(v.F_N2OA[:], 10, length(d.decades)), dims=1)
        end

    end
end



# From the EPA's matlab functions:

# function [F] = f(ts, X, Y)
#     %   INPUTS:
#     %   M_A   -- Path of CH4 atmospheric concentration 
#     %   N_A   -- Path of N20 atmospheric concentration 
#     %   OUTPUT: CH4-N2O intercation effect on radiative forcing (TAR page 358)
#     %   f(M, N)
    
#     years = ts;
#     F   = zeros(size(years)); 
#     F = 0.47*log(1+2.01*10^-5*(X*Y).^0.75+5.31*10^-15*X.*(X*Y).^1.52);
    
# end

# function [F_CH4, F_N20] = SCC_EPA_simple_gas_cycle(ts, Tannual, ECH4A, EN20A)


#     %INPUTS:
#     %  ts = Years defining time periods (decadal)
#     %  Tannual = Years defining time periods (annual)
#     %  ECH4A = annual CH4 emissions
#     %  EN20A = annual N20 emissions
#     %OUTPUTS:
#     %   F_CH4 -- Path of CH4 forcing [W/m^2] - decadal time step
#     %   F_N20 -- Path of N20 forcing [W/m^2] - decadal time step 
        
#     % Atmospheric concentration dynamics coefficients:
#     delta_ch4 = 1/12; % Annual rate of decay of CH4 (IPCC FAR)
#     gamma_ch4 = 0.3597;   % Mass to volume conversion factor [ppb CH4/Mt CH4]
#     alpha_ch4 = 0.036;  % Radiative forcing parameter (TAR page 358)
#     delta_n20 = 1/114;  % Rate of decay of N20 (IPCC FAR)
#     gamma_n20 = 0.2079;   % Mass to volume conversion factor [ppb N2O/Mt N]
#     alpha_n20 = 0.12;   % Radiative forcing parameter
    
    
#     years = ts;
#     F_CH4   = zeros(size(years)); % Contribution of atmospheric CH4 to radiative forcing (decadal time step)
#     F_N20   = zeros(size(years)); % Contribution of atmospheric N20 to radiative forcing (decadal time step)
    
#     M_pre = 700; % Pre-industrial CH4 concentrations [ppb](TAR page 358)
#     N_pre = 270; % Pre-industrial N20 concentrations [ppb](TAR page 358)
#     M_AA     = zeros(size(Tannual)); % Atmospheric CH4 concentration (annual)
#     F_CH4A   = zeros(size(Tannual)); % Contribution of atmospheric CH4 to radiative forcing (annual)
#     N_AA     = zeros(size(Tannual)); % Atmospheric N20 concentration (annual)
#     F_N20A   = zeros(size(Tannual)); % Contribution of atmospheric N20 to radiative forcing (annual)
    
#     M_AA(1) = 1774; %2005 concentration
#     N_AA(1) = 319; %2005 concentration
#      % 2005 CH4 and N20 forcing:
#     F_CH4A(1) = alpha_ch4*(sqrt(M_AA(1))-sqrt(M_pre))-(f(Tannual, M_AA(1),N_pre)-f(Tannual, M_pre,N_pre));
#     F_CH4A(1) = 1.4*F_CH4A(1); %IPCC AR4 adjustment for tropospheric ozone effect (25%) and
#         %stratospheric water vapor effect (15%)
#     F_N20A(1) = alpha_n20*(sqrt(N_AA(1))-sqrt(N_pre))-(f(Tannual, M_pre,N_AA(1))-f(Tannual, M_pre,N_pre));
    
#     tt = 1;
#     for yeart = Tannual(2:end)'; tt = tt + 1;
#     % CH4 and N20 concentration and forcing equations:
#     % Discrete annual version of concentration eq: Mt+1=(1-delta)*Mt+delta*Mpre+Et-1
#        M_AA(tt) = (1-delta_ch4)*M_AA(tt-1) + delta_ch4*M_pre + gamma_ch4*ECH4A(tt-1);
#        N_AA(tt) = (1-delta_n20)*N_AA(tt-1) + delta_n20*N_pre + gamma_n20*(28/44)*EN20A(tt-1);
#        F_CH4A(tt) = alpha_ch4*(sqrt(M_AA(tt))-sqrt(M_pre))-(f(Tannual, M_AA(tt),N_pre)-f(Tannual, M_pre,N_pre));
#        F_CH4A(tt) = 1.4*F_CH4A(tt);
#        F_N20A(tt) = alpha_n20*(sqrt(N_AA(tt))-sqrt(N_pre))-(f(Tannual, M_pre,N_AA(tt))-f(Tannual, M_pre,N_pre));
#      end;
    
#     F_CH4av = mean(reshape(F_CH4A,10,length(F_CH4A)/10),1)';
#     F_N20av = mean(reshape(F_N20A,10,length(F_N20A)/10),1)';
    
#     t = 0;
#     for year = years(1:30)'; t = t + 1;    
#     F_CH4(t) = F_CH4av(t);
#     F_N20(t) = F_N20av(t);
#     end;
    
    
#     end
       
    
    
classdef sair_const
%SAIR_CONST  Canonical constants for the SAIR pipeline.
%   Every value is traceable either to the External Calibration & Citation Dossier
%   (wind Cp-TSR, single-diode KC200GT, PMSG / hydro efficiency maps) or to the
%   uploaded human bench dataset (effective crank lever arm).
%
%   Access as sair_const.RHO_AIR, sair_const.PV.Voc, etc.

    properties (Constant)
        % --- mechanical link recovered from P = F*omega*r on the bench data ---
        LEVER_R = 0.03867;          % m

        % --- wind (dossier sec.2) ---
        RHO_AIR = 1.225;            % kg/m^3
        CP_MAX  = 0.48;             % Betz-practical peak power coefficient
        LAM_OPT = 8.1;              % optimal tip-speed ratio
        V_CI    = 3.5;              % cut-in  (m/s)
        V_R     = 12.0;             % rated   (m/s)
        V_CO    = 25.0;             % cut-out (m/s)
        TI_WIND = 0.13;             % onshore turbulence intensity
        ROTOR_R = 41.0;             % m  (82 m rotor class)

        % --- solar single-diode KC200GT (Villalva 2009, dossier sec.3) ---
        PV = struct('Iph',8.214,'I0',9.825e-8,'Rs',0.221,'Rsh',415.405, ...
                    'a',1.3,'Ns',54,'Voc',32.9,'Isc',8.21,'Vmp',26.3, ...
                    'Imp',7.61,'Pmax',200.0,'Ki',3.18e-3,'Kv',-0.123);
        Q_E = 1.602176634e-19;      % C
        K_B = 1.380649e-23;         % J/K

        % --- micro-hydro (dossier sec.4) ---
        G_ACC = 9.81;               % m/s^2
        RHO_W = 1000.0;             % kg/m^3

        % --- control / state ---
        DT    = 1.0;                % s   control step
        N_WIN = 6;                  % power-buffer window length
    end
end

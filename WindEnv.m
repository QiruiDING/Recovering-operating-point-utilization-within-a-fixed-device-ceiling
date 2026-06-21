classdef WindEnv < BaseEnv
%WINDENV  Wind PMSG source (transfer target).
%   u sets the target tip-speed ratio; rotor inertia makes the operating TSR track
%   with a first-order lag.  lambda_opt = 8.1 maximises Cp (the MPP); SAIR additionally
%   honours mechanical-stress / overspeed health.  tsr is the operating TSR (distinct
%   from the reward weight lam inherited from BaseEnv).

    properties
        Vbar = 9.0; R; A;
        LAM_MIN = 4.0; LAM_MAX = 12.0;
        tsr; stress
    end

    methods
        function obj = WindEnv(varargin)
            obj@BaseEnv(varargin{:});
            obj.dumax = 0.15; obj.R = sair_const.ROTOR_R; obj.A = pi*obj.R^2;
            obj.P_rated = 0.5*sair_const.RHO_AIR*obj.A*sair_const.CP_MAX*sair_const.V_R^3/1e3;
        end

        function aux_reset(obj), obj.tsr = sair_const.LAM_OPT; obj.stress = 0.0; obj.hrate = 0.0; end

        function v = source(obj)
            n = obj.T + 2; v = zeros(1,n); v(1) = obj.Vbar;
            ti = sair_const.TI_WIND;
            for i = 2:n
                v(i) = min(max(0.92*v(i-1) + 0.08*obj.Vbar + ti*obj.Vbar*randn(obj.rng), ...
                              sair_const.V_CI), sair_const.V_CO);
            end
            g = randi(obj.rng,[40,n-40],1,4);              % embedded gusts
            for k = 1:numel(g)
                idx = g(k):g(k)+7;
                v(idx) = min(max(v(idx) + linspace(0,0.45*obj.Vbar,8), sair_const.V_CI), sair_const.V_CO);
            end
        end

        function [Pe,Pa,etaDev,health,uOpt,ex] = extract(obj, u, v, uprev)
            lam_tgt = obj.LAM_MIN + u*(obj.LAM_MAX - obj.LAM_MIN);
            obj.tsr = obj.tsr + 0.45*(lam_tgt - obj.tsr);   % rotor-inertia lag
            cp = phys.cp_curve(obj.tsr);
            P_aero = min(0.5*sair_const.RHO_AIR*obj.A*cp*v^3/1e3, obj.P_rated);
            Pa     = min(0.5*sair_const.RHO_AIR*obj.A*sair_const.CP_MAX*v^3/1e3, obj.P_rated);
            lf = min(max(P_aero/obj.P_rated,0),1);
            sf = min(max(obj.tsr/obj.LAM_MAX,0),1.2);
            eta = phys.pmsg_eff(lf, sf); Pe = eta*P_aero;
            overspeed = max(0, obj.tsr/(1.25*sair_const.LAM_OPT)-1)*max(0, v/sair_const.V_R);
            obj.stress = 0.9*obj.stress + 0.1*(lf*max(v/obj.Vbar,1))^2;
            obj.hrate  = obj.stress*0.4 + overspeed*3;
            health = min(max(1 - 0.45*obj.stress - overspeed, 0), 1);
            uOpt = (sair_const.LAM_OPT - obj.LAM_MIN)/(obj.LAM_MAX - obj.LAM_MIN);
            etaDev = cp/sair_const.CP_MAX;
            ex = struct('C_health',obj.hrate,'lam_op',obj.tsr,'cp',cp,'v',v, ...
                        'shield_block', overspeed>0.3 && u>uprev);
            Pa = max(Pa, 1e-3);
        end
    end
end

classdef HydroEnv < BaseEnv
%HYDROENV  Francis-type micro-hydro source (transfer target, the steady source).
%   u (guide-vane / load) sets the through-flow operating fraction qf = 0.3 + 1.3 u.
%   Efficiency peaks sharply at the best-efficiency point qf = 1; beyond it efficiency
%   falls faster than flow rises, so the max-power flow is min(Q,Qdes).  Cavitation
%   (qf >> 1) degrades health.

    properties
        H = 30.0; Qdes = 0.5;
    end

    methods
        function obj = HydroEnv(varargin)
            obj@BaseEnv(varargin{:});
            obj.dumax = 0.14;
            obj.P_rated = sair_const.RHO_W*sair_const.G_ACC*obj.Qdes*obj.H*0.90/1e3;
        end

        function aux_reset(obj), obj.hrate = 0.0; end

        function q = source(obj)
            n = obj.T + 2; q = zeros(1,n); q(1) = obj.Qdes;
            for i = 2:n
                q(i) = min(max(0.96*q(i-1) + 0.04*obj.Qdes + 0.07*obj.Qdes*randn(obj.rng), ...
                              0.15*obj.Qdes), 1.8*obj.Qdes);
            end
        end

        function [Pe,Pa,etaDev,health,uOpt,ex] = extract(obj, u, Q, ~)
            g = sair_const.G_ACC; rw = sair_const.RHO_W;
            qf_op = min(max(0.3 + 1.3*u, 0.2), 1.6);
            Qop   = min(qf_op*obj.Qdes, Q);                 % cannot exceed available flow
            eta   = phys.francis_eff(Qop/obj.Qdes);
            Pe    = rw*g*Qop*obj.H*eta/1e3;
            Qeff  = min(Q, obj.Qdes);                       % max-power flow
            Pa    = rw*g*Qeff*obj.H*phys.francis_eff(Qeff/obj.Qdes)/1e3;
            cav   = max(0, qf_op-1.4); health = min(max(1-cav,0),1); obj.hrate = cav*2;
            uOpt  = min(max((min(Q,obj.Qdes)/obj.Qdes - 0.3)/1.3, 0.05), 0.95);
            etaDev = eta/0.90;
            ex = struct('C_health',obj.hrate,'Q',Q,'eta',eta,'shield_block',false);
            Pa = max(Pa, 1e-3);
        end
    end
end

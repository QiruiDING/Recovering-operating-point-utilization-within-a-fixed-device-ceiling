classdef SolarEnv < BaseEnv
%SOLARENV  PV single-diode KC200GT source (transfer target).
%   u sets the operating-voltage fraction V_op = u*Voc.  The MPP sits at Vmp/Voc;
%   cloud-edge transients move it, and cell heating degrades health.

    methods
        function obj = SolarEnv(varargin)
            obj@BaseEnv(varargin{:});
            obj.dumax = 0.16; obj.P_rated = sair_const.PV.Pmax;
        end

        function aux_reset(obj), obj.hrate = 0.0; end

        function G = source(obj)
            n = obj.T + 2; t = 0:n-1;
            clear = min(max(sin(pi*t/n)*1000, 50), 1000);    % bell-shaped clear-sky GHI
            G = clear;
            c = randi(obj.rng,[20,n-20],1,6);                % cloud-edge transients
            for k = 1:numel(c)
                w = randi(obj.rng,[4,13]);
                idx = c(k):min(c(k)+w-1,n);
                G(idx) = G(idx) * (0.25 + 0.35*rand(obj.rng));
            end
            G = min(max(G,30),1100);
        end

        function [Pe,Pa,etaDev,health,uOpt,ex] = extract(obj, u, G, ~)
            PV = sair_const.PV;
            Tc = 25 + 0.03*G + 1.5*randn(obj.rng);
            [Vmpp, Pmpp] = phys.pv_mpp(G, Tc);
            Voc = PV.Voc*(1 + PV.Kv/PV.Voc*(Tc-25));
            Vop = min(max(u*Voc, 0.05), Voc);
            P   = Vop*phys.pv_iv(Vop, G, Tc);
            Pe  = P*0.97;                                    % incl converter
            health = min(max(1 - (Tc-25)/60, 0), 1); obj.hrate = max(0,(Tc-45)/30);
            uOpt = min(max(Vmpp/Voc, 0.2), 0.98);
            etaDev = P/max(Pmpp,1e-3);
            ex = struct('C_health',obj.hrate,'G',G,'Tc',Tc,'Vmpp',Vmpp,'Vop',Vop, ...
                        'shield_block', false);
            Pa = max(Pmpp*0.97, 1e-3);
        end
    end
end

classdef BaseEnv < handle
%BASEENV  Shared state assembly + safety shield + reward for all source adapters.
%   Unified normalised state s = [p, u, g1, g2, health, buf(1..N_WIN)] (dim 5+N_WIN).
%   Objective per step  r = Pn - lam*C_health - mu*C_smooth - 0.05*viol , where
%   Pn = min(P_elec,P_avail)/P_rated is sustainable useful power (capped at the optimum),
%   so lam=mu=0 recovers classic MPP maximisation (SAIR is a strict superset).
%   Sub-classes implement source() and extract().

    properties
        name = 'base';
        P_rated = 1.0;
        lam = 0.25; mu = 0.08;
        dumax = 0.15;                 % rate-shield slew limit  (<= 2 levels/s)
        T; rng; t; u; src; buf; health; hrate = 0.0;
    end

    methods (Abstract)
        s = source(obj)                              % time series of the source state
        [Pe,Pa,etaDev,health,uOpt,ex] = extract(obj,u,sst,uprev)
    end

    methods
        function obj = BaseEnv(T, seed, lam, mu)
            if nargin>=1 && ~isempty(T),  obj.T = T;   else, obj.T = 600; end
            if nargin<2 || isempty(seed), seed = 0;    end
            if nargin>=3 && ~isempty(lam), obj.lam = lam; end
            if nargin>=4 && ~isempty(mu),  obj.mu  = mu;  end
            obj.rng = RandStream('mt19937ar','Seed',seed);
        end

        function aux_reset(~), end                    % subclass hook

        function s = reset(obj)
            obj.t = 0; obj.u = 0.5; obj.src = obj.source();
            obj.buf = zeros(1, sair_const.N_WIN);
            obj.health = 1.0; obj.aux_reset();
            s = obj.observe(obj.u, 0.0);
        end

        function s = observe(obj, u, Pe)
            p = Pe/obj.P_rated;
            obj.buf = [obj.buf(2:end), p];
            [g1,g2] = phys.grad(obj.buf);
            s = [p, u, g1, g2, obj.health, obj.buf];
        end

        function [s,r,done,info] = step(obj, u)
            u   = min(max(u,0),1);
            du  = u - obj.u; viol = 0.0;
            if abs(du) > obj.dumax                    % rate shield clips the slew
                u = obj.u + sign(du)*obj.dumax; viol = 1.0;
            end
            sst = obj.src(obj.t+1);
            [Pe,Pa,etaDev,health,uOpt,ex] = obj.extract(u, sst, obj.u);
            if isfield(ex,'shield_block') && ex.shield_block   % model-based override
                u = obj.u; viol = 1.0;
            end
            obj.health = health; obj.u = u;
            s  = obj.observe(u, Pe);
            Pn = min(Pe,Pa)/obj.P_rated;
            etaTrack = min(Pe/max(Pa,1e-6), 1.2);
            if isfield(ex,'C_health'), Ch = ex.C_health; else, Ch = max(0,-obj.hrate); end
            Cs = du^2;
            r  = Pn - obj.lam*Ch - obj.mu*Cs - 0.05*viol;
            obj.t = obj.t + 1; done = obj.t >= obj.T;
            info = ex;
            info.P_elec=Pe; info.P_avail=Pa; info.eta_track=etaTrack;
            info.eta_dev=etaDev; info.health=obj.health; info.u_opt=uOpt;
            info.u=u; info.viol=viol;
        end
    end
end

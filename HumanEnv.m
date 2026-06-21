classdef HumanEnv < BaseEnv
%HUMANENV  Human-powered source (training domain, most non-stationary).
%   Resistance u sets the load line; mechanical demand is an inverted-U in u peaking
%   at u_P (the point a greedy MPP chases).  Demand above critical power CP drains a
%   finite anaerobic reserve W'; as W' empties the deliverable-power ceiling collapses
%   (the rider "bonks").  A greedy power-chaser exhausts the reserve and loses on both
%   energy and health; the health-aware SAIR optimum paces just below CP.
%   P_avail is the instantaneous *sustainable* (health-constrained) optimum.

    properties
        hd
        u_P = 0.58; sig = 0.26;
        base = 66.0; CP = 46.0; Wp = 5000.0;
        floor = 0.40; krec = 0.60;
        Wbal
    end

    methods
        function obj = HumanEnv(hd, varargin)
            obj@BaseEnv(varargin{:});
            obj.hd = hd; obj.dumax = 0.18; obj.P_rated = 66.0;
            if isempty(varargin), obj.lam = 0.4; end       % default human weighting
        end

        function aux_reset(obj), obj.Wbal = obj.Wp; obj.hrate = 0.0; end

        function m = source(obj)
            n = obj.T + 2; m = zeros(1,n); m(1) = 0.78;
            for i = 2:n
                m(i) = min(max(0.90*m(i-1) + 0.10*0.80 + 0.045*randn(obj.rng), 0.5), 1.0);
            end
            m(1:40) = m(1:40) .* min(max(linspace(0.75,1.0,40),0),1);
        end

        function v = shape(obj, u), v = exp(-((u-obj.u_P).^2)/(2*obj.sig^2)); end

        function us = u_sus(~, fatigue)
            us = min(max(0.255 - 0.045*fatigue, 0.20), 0.40);
        end

        function [Pe,Pa,etaDev,health,uOpt,ex] = extract(obj, u, mot, uprev)
            rf = obj.Wbal/obj.Wp; mscale = 0.90 + 0.10*mot;
            cap  = obj.floor + (1-obj.floor)*min(max(rf/0.28,0),1);
            Pcap = obj.base*cap*mscale;
            Pdem = obj.base*obj.shape(u)*mscale;
            P_mech = min(max(min(Pdem,Pcap) + 1.3*randn(obj.rng), 1), obj.base*1.12);
            drain = Pdem - obj.CP;                          % W'-balance keyed to demand
            if drain > 0, obj.Wbal = obj.Wbal - drain*sair_const.DT;
            else,         obj.Wbal = obj.Wbal + obj.krec*(-drain)*sair_const.DT; end
            obj.Wbal = min(max(obj.Wbal,0), obj.Wp);
            rpm   = min(max((150-70*u)*(0.85+0.15*mot)*(0.7+0.3*rf) + 3*randn(obj.rng), 15), 170);
            omega = 2*pi*rpm/60;
            torque= min(max((5+34*u)*sair_const.LEVER_R*30*(0.85+0.15*mot), 0.2), 4.4);
            eta   = obj.hd.eta_gen(omega, torque, P_mech*0.90);
            Pe    = eta*P_mech;
            fatigue = 1 - rf; obj.hrate = max(0,(P_mech-obj.CP)/obj.CP);
            health  = rf;
            P_sus = obj.base*obj.shape(obj.u_sus(fatigue))*mscale;  % health-aware reference
            Pa    = eta*min(P_sus, obj.CP*0.99);
            uOpt  = obj.u_sus(fatigue); etaDev = eta;
            ex = struct('C_health',obj.hrate,'rpm',rpm,'P_mech',P_mech, ...
                        'fatigue',fatigue,'shield_block', rf<0.03 && u>uprev);
            Pa = max(Pa, 1e-3);
        end
    end
end

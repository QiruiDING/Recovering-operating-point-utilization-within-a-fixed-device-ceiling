classdef PnO < handle
%PNO  Perturb & Observe MPPT baseline: climbs instantaneous power, ignores health.
    properties
        step = 0.05; dir = 1; pp = -1;
    end
    methods
        function obj = PnO(step), if nargin>=1 && ~isempty(step), obj.step = step; end, end
        function du = act(obj, P)
            if P < obj.pp, obj.dir = -obj.dir; end
            obj.pp = P; du = obj.dir*obj.step;
        end
        function reset(obj), obj.dir = 1; obj.pp = -1; end
    end
end

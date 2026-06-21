classdef INC < handle
%INC  Incremental-conductance-style MPPT baseline (smaller perturbation, slope sign).
    properties
        step = 0.03; dir = 1; pp = -1;
    end
    methods
        function obj = INC(step), if nargin>=1 && ~isempty(step), obj.step = step; end, end
        function du = act(obj, P, ~)
            if P < obj.pp, obj.dir = -obj.dir; end
            obj.pp = P; du = obj.dir*obj.step;
        end
        function reset(obj), obj.dir = 1; obj.pp = -1; end
    end
end

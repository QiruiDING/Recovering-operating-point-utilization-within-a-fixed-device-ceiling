classdef Policy
%POLICY  pi_theta(u|s,z): compact 2-layer tanh MLP returning the learned CORRECTION
%   du in [-0.12,0.12] that modulates the gradient-following base controller.
%   Parameters are packed in a single vector theta (trained by Cross-Entropy Method).

    properties
        in_dim; h = 16; n; theta
    end

    methods
        function obj = Policy(in_dim, h, seed)
            if nargin >= 2 && ~isempty(h), obj.h = h; end
            if nargin < 3 || isempty(seed), seed = 0; end
            obj.in_dim = in_dim;
            shapes = obj.shapeList();
            obj.n  = sum(cellfun(@prod, shapes));
            r = RandStream('mt19937ar','Seed',seed);
            obj.theta = 0.25*randn(r, obj.n, 1);
        end

        function shapes = shapeList(obj)
            shapes = {[obj.in_dim obj.h], [1 obj.h], [obj.h obj.h], [1 obj.h], [obj.h 1], [1 1]};
        end

        function P = setTheta(obj, th), P = obj; P.theta = th(:); end

        function varargout = unpack(obj)
            shapes = obj.shapeList(); out = cell(1,numel(shapes)); i = 1;
            for k = 1:numel(shapes)
                sz = prod(shapes{k});
                out{k} = reshape(obj.theta(i:i+sz-1), shapes{k}); i = i + sz;
            end
            varargout = out;
        end

        function du = act(obj, s, z)
            [W1,b1,W2,b2,W3,b3] = obj.unpack();
            x  = [s(:).' , z(:).'];               % 1 x in_dim
            hh = tanh(x*W1 + b1);
            hh = tanh(hh*W2 + b2);
            du = tanh(hh*W3 + b3)*0.12;
        end
    end
end

classdef ctrl
%CTRL  Controller factories returning step functions f(env,s,t) -> absolute u in [0,1].
%   The SAIR controller is a residual policy: a model-free gradient-following base
%   (P&O) that climbs power on ANY source (so the policy transfers), plus the learned
%   context-conditioned correction pi_theta (smarter step-sizing / anticipation /
%   health-aware pacing).  Residual RL over a classical MPPT prior.

methods (Static)

    function f = policy(pol, base_step)
        if nargin < 2 || isempty(base_step), base_step = 0.03; end
        base = PnO(base_step);
        f = @stepfun;
        function u = stepfun(env, s, t)
            if t == 0, base.reset(); end
            z = phys.context(env.buf);
            du_base = base.act(s(1)*env.P_rated);     % climbs instantaneous power
            du_corr = pol.act(s, z);                  % learned correction (+/-0.12)
            u = env.u + du_base + du_corr;
        end
    end

    function f = pno(step)
        if nargin < 1 || isempty(step), step = 0.04; end
        base = PnO(step);
        f = @stepfun;
        function u = stepfun(env, s, t)
            if t == 0, base.reset(); end
            u = env.u + base.act(s(1)*env.P_rated);
        end
    end

    function f = inc(step)
        if nargin < 1 || isempty(step), step = 0.03; end
        base = INC(step);
        f = @stepfun;
        function u = stepfun(env, s, t)
            if t == 0, base.reset(); end
            u = env.u + base.act(s(1)*env.P_rated, env.u);
        end
    end

    function f = const(u0)
        f = @(env,s,t) u0;
    end

end
end

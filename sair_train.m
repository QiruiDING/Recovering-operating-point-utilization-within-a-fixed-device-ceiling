classdef sair_train
%SAIR_TRAIN  Gradient-free training (Cross-Entropy Method) + evaluation utilities.
%   Metrics: realized conversion efficiency (capped sustainable), MPP tracking
%   efficiency, output CV, source health, control smoothness, settling time, return.
%   Efficiency / CV are measured over the post-warm-up window (first 8 % skipped).

methods (Static)

    function m = rollout(env, ctrlfn)
        s = env.reset(); done = false; t = 0; R = 0; Eel = 0;
        Pe = []; Pa = []; H = []; U = []; UO = []; ED = [];
        while ~done
            u = ctrlfn(env, s, t);
            [s, r, done, info] = env.step(u);
            R = R + r; t = t + 1; Eel = Eel + info.P_elec;
            Pe(end+1)=info.P_elec; Pa(end+1)=info.P_avail; %#ok<AGROW>
            H(end+1)=info.health;  U(end+1)=info.u; UO(end+1)=info.u_opt; %#ok<AGROW>
            ED(end+1)=info.eta_dev; %#ok<AGROW>
        end
        m = sair_train.metrics(Pe,Pa,H,U,UO,Eel,R,ED);
    end

    function m = rollout_oracle(env)
        s = env.reset(); done = false; uo = 0.45; R = 0; Eel = 0; %#ok<NASGU>
        Pe = []; Pa = []; H = []; U = []; UO = []; ED = [];
        while ~done
            [s, r, done, info] = env.step(uo); %#ok<ASGLU>
            uo = info.u_opt; R = R + r; Eel = Eel + info.P_elec;
            Pe(end+1)=info.P_elec; Pa(end+1)=info.P_avail; %#ok<AGROW>
            H(end+1)=info.health;  U(end+1)=info.u; UO(end+1)=info.u_opt; %#ok<AGROW>
            ED(end+1)=info.eta_dev; %#ok<AGROW>
        end
        m = sair_train.metrics(Pe,Pa,H,U,UO,Eel,R,ED);
    end

    function m = metrics(Pe,Pa,H,U,UO,Eel,R,ED)
        if nargin < 8, ED = ones(size(Pe)); end
        n = numel(Pe); k0 = floor(0.08*n); w = (k0+1):n;
        cv  = std(Pe(w))/max(mean(Pe(w)),1e-9);
        num = sum(min(Pe(w),Pa(w))); den = sum(Pa(w));
        m.eta_real  = num/max(den,1e-9);
        m.eta_track = min(sum(Pe(w))/max(den,1e-9), 1.0);
        m.Eelec = Eel; m.cv = cv; m.h_end = H(end); m.h_mean = mean(H);
        m.u_cv = std(U)/max(mean(U),1e-9); m.ret = R;
        m.Pe = Pe; m.Pa = Pa; m.H = H; m.U = U; m.UO = UO; m.ED = ED;
    end

    function [pol, curve] = cem_train(envfn, in_dim, o)
        % o: struct with fields iters,pop,elite,episodes,seed,init_theta,init_sigma,verbose
        if ~isfield(o,'iters'),     o.iters = 14;   end
        if ~isfield(o,'pop'),       o.pop = 24;     end
        if ~isfield(o,'elite'),     o.elite = 6;    end
        if ~isfield(o,'episodes'),  o.episodes = 3; end
        if ~isfield(o,'seed'),      o.seed = 0;     end
        if ~isfield(o,'init_sigma'),o.init_sigma = 0.5; end
        if ~isfield(o,'verbose'),   o.verbose = true;   end
        rs  = RandStream('mt19937ar','Seed',o.seed);
        pol = Policy(in_dim, 16, o.seed);
        if isfield(o,'init_theta') && ~isempty(o.init_theta)
            mu = o.init_theta(:);
        else
            mu = pol.theta;
        end
        sigma = o.init_sigma*ones(pol.n,1);
        curve = zeros(1, o.iters);
        best_eval = -inf; best_mu = mu;
        for it = 1:o.iters
            it0  = it - 1;
            cand = mu + sigma .* randn(rs, pol.n, o.pop);
            fit  = zeros(1, o.pop);
            for i = 1:o.pop
                p = pol.setTheta(cand(:,i)); c = ctrl.policy(p);
                rr = zeros(1, o.episodes);
                for e = 1:o.episodes
                    seed = 1000 + it0*o.pop + (i-1)*7 + (e-1);
                    rr(e) = sair_train.rollout(envfn(seed), c).ret;
                end
                fit(i) = mean(rr);
            end
            [~, ord] = sort(fit, 'descend'); el = ord(1:o.elite);
            mu    = mean(cand(:,el), 2);
            sigma = std(cand(:,el), 0, 2) + 1e-3;
            sigma = sigma*0.92;                              % annealing
            p = pol.setTheta(mu); c = ctrl.policy(p);
            ev = zeros(1,4);
            for e = 1:4, ev(e) = sair_train.rollout(envfn(50000 + it0*13 + (e-1)), c).ret; end
            curve(it) = mean(ev);
            if curve(it) > best_eval, best_eval = curve(it); best_mu = mu; end
            if o.verbose
                fprintf('  CEM it%02d  elite=%7.2f  eval=%7.2f  sig=%.3f\n', ...
                        it0, mean(fit(el)), curve(it), mean(sigma));
            end
        end
        pol = pol.setTheta(best_mu);                         % return best-evaluated policy
    end

    function st = settling_after_step(env, ctrlfn, thresh)
        if nargin < 3, thresh = 0.05; end
        m = sair_train.rollout(env, ctrlfn); Pe = m.Pe; Pa = m.Pa;
        dPa = abs(diff(Pa))./max(Pa(1:end-1),1e-6);
        edges = find(dPa > 0.18); sts = [];
        for q = 1:numel(edges)
            e = edges(q); seg = (e+1):min(e+40, numel(Pe));
            err = abs(Pe(seg)-Pa(seg))./max(Pa(seg),1e-6);
            w = find(err < thresh, 1, 'first');
            if ~isempty(w), sts(end+1) = w; end %#ok<AGROW>
        end
        if isempty(sts), st = NaN; else, st = mean(sts); end
    end

end
end

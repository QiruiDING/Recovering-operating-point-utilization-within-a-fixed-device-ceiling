function SAIR_main(cfg)
%SAIR_MAIN  End-to-end SAIR pipeline (data -> fit -> train -> transfer -> figures).
%
%   SAIR_main();                 % full run with default budgets
%   SAIR_main(struct('FAST',1)); % quick smoke test (small budgets)
%
%   Source-Adaptive Input-side Regulation: a context-conditioned residual control
%   policy is trained on the human-powered bench source and transferred (zero-/few-/
%   upper-shot) to wind, solar and micro-hydro adapters.  Produces the figure set in
%   ./figures and prints the results table.  Place Data.xlsx in the working folder.
%
%   NOTE.  This MATLAB code mirrors the validated reference pipeline one-to-one
%   (identical physics, state, reward, residual controller, CEM).  Absolute numbers
%   differ negligibly from the reference because MATLAB's RNG (mt19937ar) is not
%   bit-identical to the reference generator; the qualitative conclusions reproduce.

    if nargin < 1, cfg = struct; end
    if ~isfield(cfg,'FAST'),      cfg.FAST = false; end
    if ~isfield(cfg,'data'),      cfg.data = 'Data.xlsx'; end
    if ~isfield(cfg,'nseed'),     cfg.nseed = 8; end
    if ~isfield(cfg,'do_sample_eff'), cfg.do_sample_eff = true; end
    if ~isfield(cfg,'se_seeds'),  cfg.se_seeds = 3; end
    rng(7,'twister');
    P = set_nature_style();
    IN = 5 + sair_const.N_WIN + 3;                 % state(11) + context(3) = 14

    fprintf('\n=== SAIR pipeline ===\n');

    %% 1. data layer --------------------------------------------------------
    hd = HumanData(cfg.data);
    fprintf('Efficiency-map fit:  R^2 = %.3f   RMSE = %.4f   k = [%.3f %.2g %.3f]\n', ...
            hd.eff_R2, hd.eff_RMSE, hd.eff_k(1), hd.eff_k(2), hd.eff_k(3));
    fprintf('Fatigue model:       CP = %.1f W   W'' = %.0f J   Pmax = %.1f W\n', ...
            hd.CP, hd.Wprime, hd.Pmax_burst);

    %% 2. environment factories --------------------------------------------
    Th = 400; Texo = 400; Tsol = 300;
    if cfg.FAST, Th=160; Texo=160; Tsol=140; cfg.nseed=4; cfg.se_seeds=2; end
    humanfn = @(seed) HumanEnv(hd, Th, seed, 0.4, 0.08);
    EXO = struct('wind',  @(seed) WindEnv(Texo, seed), ...
                 'solar', @(seed) SolarEnv(Tsol, seed), ...
                 'hydro', @(seed) HydroEnv(Texo, seed));
    PNO_STEP = struct('wind',0.04,'solar',0.06,'hydro',0.04);

    %% 3. train the shared policy on the human source -----------------------
    fprintf('\n[train] human source (CEM)\n');
    oh = budget(cfg,'human');
    [pol_h, curve_h] = sair_train.cem_train(humanfn, IN, oh);
    th_h = pol_h.theta;

    %% 4. transfer training: upper-bound + few-shot per source --------------
    srcs = {'wind','solar','hydro'};
    pol_up = struct; pol_few = struct;
    for s = 1:3
        nm = srcs{s}; fn = EXO.(nm);
        fprintf('[train] %s upper-bound\n', nm);
        pol_up.(nm)  = sair_train.cem_train(fn, IN, budget(cfg,['upper_' nm]));
        fprintf('[train] %s few-shot (human-init)\n', nm);
        of = budget(cfg,['few_' nm]); of.init_theta = th_h; of.init_sigma = 0.25;
        pol_few.(nm) = sair_train.cem_train(fn, IN, of);
    end

    %% 5. evaluation matrix -------------------------------------------------
    KEYS = {'eta_real','eta_track','cv','h_end','h_mean','u_cv'};
    aggC = @(envfn,c) agg(envfn, c, cfg.nseed, KEYS, false);
    aggO = @(envfn)   agg(envfn, [], cfg.nseed, KEYS, true);

    human.trained = aggC(humanfn, ctrl.policy(pol_h));
    human.pno     = aggC(humanfn, ctrl.pno(0.04));
    human.inc     = aggC(humanfn, ctrl.inc(0.03));
    human.oracle  = aggO(humanfn);

    trans = struct;
    for s = 1:3
        nm = srcs{s}; fn = EXO.(nm);
        R.pno      = aggC(fn, ctrl.pno(PNO_STEP.(nm)));
        R.inc      = aggC(fn, ctrl.inc(0.03));
        R.zeroshot = aggC(fn, ctrl.policy(pol_h));
        R.fewshot  = aggC(fn, ctrl.policy(pol_few.(nm)));
        R.upper    = aggC(fn, ctrl.policy(pol_up.(nm)));
        R.oracle   = aggO(fn);
        trans.(nm) = R;
        fprintf('[eval] %-5s  P&O=%.3f zero=%.3f few=%.3f upper=%.3f oracle=%.3f\n', nm, ...
            R.pno.eta_track(1), R.zeroshot.eta_track(1), R.fewshot.eta_track(1), ...
            R.upper.eta_track(1), R.oracle.eta_track(1));
    end

    %% 6. inputs for the four composite figures ----------------------------
    human_sweep = working_point_sweep(humanfn);                  % Fig 1c
    cells    = participant_cells(hd);                            % Fig 1d
    td.solar = disturbance_trace(@(sd)SolarEnv(200,sd), pol_up.solar, PNO_STEP.solar);  % Fig 3a
    td.wind  = disturbance_trace(@(sd)WindEnv(220,sd),  pol_up.wind,  PNO_STEP.wind);    % Fig 3b
    td.human = disturbance_trace(@(sd)HumanEnv(hd,300,sd,0.4,0.08), pol_h, 0.04);        % Fig 3d
    decomp   = decompose(EXO, pol_up, PNO_STEP, srcs, cfg.nseed);  % Fig 4a
    se = struct();
    if cfg.do_sample_eff
        se.wind  = sample_curve(EXO.wind,  th_h, IN, cfg);
        se.solar = sample_curve(EXO.solar, th_h, IN, cfg);        % Fig 2d
    end

    % output-CV across sources (SAIR=trained/upper vs P&O)            Fig 3c
    cv.labels = {'human','wind','solar','hydro'};
    cv.pno  = [human.pno.cv(1),     trans.wind.pno.cv(1),   trans.solar.pno.cv(1),   trans.hydro.pno.cv(1)];
    cv.sair = [human.trained.cv(1), trans.wind.upper.cv(1), trans.solar.upper.cv(1), trans.hydro.upper.cv(1)];

    % multi-metric improvement summary                                Fig 4b
    heat.rows    = {'human','wind','solar','hydro'};
    heat.metrics = {'\Delta\eta_{track} (pp)','CV reduction (%)','health gain'};
    mObj = {human.trained, trans.wind.upper, trans.solar.upper, trans.hydro.upper};
    mRef = {human.pno,     trans.wind.pno,   trans.solar.pno,   trans.hydro.pno};
    V = zeros(4,3);
    for r = 1:4
        V(r,1) = 100*(mObj{r}.eta_track(1) - mRef{r}.eta_track(1));
        V(r,2) = 100*(mRef{r}.cv(1) - mObj{r}.cv(1))/max(mRef{r}.cv(1),1e-9);
        V(r,3) = mObj{r}.h_end(1) - mRef{r}.h_end(1);
    end
    heat.vals = V;
    heat.fmt  = {@(x)sprintf('%+.1f',x), @(x)sprintf('%.0f',x), @(x)sprintf('%+.2f',x)};

    %% 7. figures (4 composite, multi-panel) --------------------------------
    save('sair_results.mat','human','trans','hd','curve_h','decomp','se','td', ...
         'human_sweep','cells','cv','heat','-v7');
    fprintf('\n[figures] writing to ./figures\n');
    F = {@() figs.save_fig(figs.fig1_source(hd, human_sweep, cells, P), 'fig1_source',    18.0, 15.0), ...
         @() figs.save_fig(figs.fig2_transfer(trans, se, P),            'fig2_transfer',  18.0, 14.0), ...
         @() figs.save_fig(figs.fig3_dynamics(td, cv, P),               'fig3_dynamics',  18.0, 14.0), ...
         @() figs.save_fig(figs.fig4_mechanism(decomp, heat, P),        'fig4_mechanism', 18.0, 7.5)};
    for q = 1:numel(F)
        try, F{q}(); catch ME, warning('figure %d failed: %s', q, ME.message); end
    end

    %% 8. results table -----------------------------------------------------
    print_conclusions(human, trans, hd, curve_h);
    fprintf('\nSaved sair_results.mat.  Done.\n');
end

% ======================================================================== %
%  local helper functions                                                  %
% ======================================================================== %
function o = budget(cfg, tag)
    % CEM budgets per training job: [iters pop elite episodes]
    B = containers.Map();
    B('human')       = [14 24 6 3];
    B('upper_wind')  = [20 28 7 3];  B('upper_solar') = [16 24 5 3];  B('upper_hydro') = [22 28 7 4];
    B('few_wind')    = [4 16 4 2];   B('few_solar')   = [5 16 4 2];   B('few_hydro')   = [5 18 4 3];
    b = B(tag);
    if cfg.FAST, b = [max(4,round(b(1)/3)) max(8,round(b(2)/2)) max(2,round(b(3)/2)) b(4)]; end
    o = struct('iters',b(1),'pop',b(2),'elite',b(3),'episodes',b(4), ...
               'seed',1,'verbose',false);
end

function out = agg(envfn, ctrlfn, n, KEYS, isOracle)
    M = cell(1,n);
    for i = 1:n
        e = envfn(5000+i);
        if isOracle, M{i} = sair_train.rollout_oracle(e);
        else,        M{i} = sair_train.rollout(e, ctrlfn); end
    end
    out = struct;
    for k = 1:numel(KEYS)
        v = cellfun(@(m) m.(KEYS{k}), M);
        out.(KEYS{k}) = [mean(v), std(v)];
    end
    out.raw = cellfun(@(m) m.eta_track, M);    % per-seed tracking efficiency (dot overlay)
end

function W = working_point_sweep(humanfn)
    % instantaneous risk-discounted objective: J(u) = P_elec(u)*(1 - lam*Risk(u)),
    % Risk(u) = max(0, demand(u)-CP)/CP.  Greedy MPP = argmax P_elec; SAIR optimum = argmax J.
    e = humanfn(0); e.reset(); hd = e.hd; lam = 0.4; mot = 0.97;
    us = 0:0.005:1; Pe = zeros(size(us)); J = zeros(size(us));
    for q = 1:numel(us)
        u = us(q);
        demand = e.base*e.shape(u)*mot;
        rpm    = min(max((150-70*u)*mot*(0.7+0.3), 15), 170);
        omega  = 2*pi*rpm/60;
        torque = min(max((5+34*u)*sair_const.LEVER_R*30*mot, 0.2), 4.4);
        eta    = hd.eta_gen(omega, torque, demand*0.90);
        Pe(q)  = eta*demand;
        risk   = max(0, demand-e.CP)/e.CP;
        J(q)   = Pe(q)*(1 - lam*risk);
    end
    W.u = us; W.Pe = Pe; W.J = J ./ max(J);
end

function D = disturbance_trace(envfn, pol_up, pno_step)
    seed = 4242;
    mS = sair_train.rollout(envfn(seed), ctrl.policy(pol_up));
    mP = sair_train.rollout(envfn(seed), ctrl.pno(pno_step));
    mO = sair_train.rollout_oracle(envfn(seed));
    D.t = 1:numel(mS.Pe); D.SAIR = mS.Pe; D.PNO = mP.Pe; D.ORACLE = mO.Pe;
    D.H_SAIR = mS.H; D.H_PNO = mP.H;
    dP = [0 diff(mO.Pa)]./max(mO.Pa,1e-6);
    D.dist = dP < -0.10;                       % disturbance = sharp availability drop
    D.cvS = mS.cv; D.cvP = mP.cv;
end

function decomp = decompose(EXO, pol_up, PNO_STEP, srcs, n)
    dev = zeros(1,3); ctl = zeros(1,3);
    for s = 1:3
        nm = srcs{s}; fn = EXO.(nm);
        [dS,pS,ES] = mean_decomp(fn, ctrl.policy(pol_up.(nm)), n); %#ok<ASGLU>
        [dP,pP,EP] = mean_decomp(fn, ctrl.pno(PNO_STEP.(nm)), n);
        L = min(numel(dS), numel(dP));
        dS=dS(1:L); dP=dP(1:L); pP=pP(1:L);
        base = max(EP,1e-9);
        dev(s) = 100*sum((dS - dP).*pP)/base;          % higher device efficiency at same input
        ctl(s) = 100*(ES - EP)/base - dev(s);          % residual = control / capture contribution
    end
    decomp.srcs = srcs; decomp.dev = dev; decomp.ctrl = ctl;
end
function [etaDev_w, Pin_w, E] = mean_decomp(envfn, ctrlfn, n)
    EDs={}; PINs={}; Es=zeros(1,n);
    for i=1:n
        m = sair_train.rollout(envfn(5000+i), ctrlfn);
        k0=floor(0.08*numel(m.Pe)); w=(k0+1):numel(m.Pe);
        EDs{i}=m.ED(w); PINs{i}=m.Pe(w)./max(m.ED(w),1e-3); Es(i)=sum(min(m.Pe(w),m.Pa(w))); %#ok<AGROW>
    end
    L = min(cellfun(@numel,EDs));
    ED = mean(cell2mat(cellfun(@(x)x(1:L),EDs,'uni',0).'),1);
    PI = mean(cell2mat(cellfun(@(x)x(1:L),PINs,'uni',0).'),1);
    etaDev_w = ED; Pin_w = PI; E = mean(Es);
end

function cells = participant_cells(hd)
    T = hd.T; bs = T.('Battery set'); ld = T.('Load');
    Hp = T.('Human_Power_W'); Gp = T.('Gen_Power_W'); tn = T.('Testname');
    volts = unique(bs); cells = struct('label',{},'vals',{});
    for i = 1:numel(volts)
        vals = [];
        for p = unique(tn).'
            for l = unique(ld).'
                m = bs==volts(i) & tn==p & ld==l;
                if nnz(m) > 5
                    e = min(sum(Gp(m))/max(sum(Hp(m)),1e-6), 0.99);
                    vals(end+1) = e; %#ok<AGROW>
                end
            end
        end
        cells(i).label = num2str(volts(i)); cells(i).vals = vals;
    end
end

function D = sample_curve(envfn, th_h, IN, cfg)
    pop=16; ep=2; iters=14; if cfg.FAST, iters=6; end
    ns = cfg.se_seeds;
    Cs = zeros(ns,iters); Ch = zeros(ns,iters);
    for r = 1:ns
        os = struct('iters',iters,'pop',pop,'elite',4,'episodes',ep,'seed',6+r, ...
                    'init_sigma',0.5,'verbose',false);
        [~,Cs(r,:)] = sair_train.cem_train(envfn, IN, os);
        oh = os; oh.init_theta = th_h; oh.init_sigma = 0.25;
        [~,Ch(r,:)] = sair_train.cem_train(envfn, IN, oh);
    end
    D.eps = (1:iters)*pop*ep;
    D.scratch = mean(Cs,1); D.human = mean(Ch,1);
    D.scratch_lo = min(Cs,[],1); D.scratch_hi = max(Cs,[],1);
    D.human_lo   = min(Ch,[],1); D.human_hi   = max(Ch,[],1);
    asym = mean(D.scratch(end-min(2,iters-1):end)); tgt = 0.9*asym;
    fr = @(c) D.eps(find(c>=tgt,1,'first'));
    es = fr(D.scratch); eh = fr(D.human);
    if isempty(es), es = D.eps(end); end
    if isempty(eh), eh = D.eps(end); end
    D.reduction = max(0, 1 - eh/max(es,1));
end

function print_conclusions(human, trans, hd, curve_h)
    fprintf('\n================ SAIR results summary ================\n');
    fprintf('Device efficiency map fit              R^2 = %.3f (RMSE %.4f)\n', hd.eff_R2, hd.eff_RMSE);
    fprintf('Human source  | CV  SAIR %.2f vs P&O %.2f | health %.2f vs %.2f | eta %.3f vs %.3f\n', ...
        human.trained.cv(1), human.pno.cv(1), human.trained.h_end(1), human.pno.h_end(1), ...
        human.trained.eta_real(1), human.pno.eta_real(1));
    fprintf('CEM learning curve  %.1f -> %.1f\n', curve_h(1), curve_h(end));
    srcs = {'wind','solar','hydro'};
    fprintf('\nTransfer (MPP tracking efficiency, mean over held-out seeds):\n');
    fprintf('  source   P&O    zero   few    upper  oracle   SAIR-P&O\n');
    for s = 1:3
        R = trans.(srcs{s});
        fprintf('  %-6s  %.3f  %.3f  %.3f  %.3f  %.3f   %+.1f pp\n', srcs{s}, ...
            R.pno.eta_track(1), R.zeroshot.eta_track(1), R.fewshot.eta_track(1), ...
            R.upper.eta_track(1), R.oracle.eta_track(1), 100*(R.upper.eta_track(1)-R.pno.eta_track(1)));
    end
    fprintf('======================================================\n');
end

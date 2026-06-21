classdef HumanData < handle
%HUMANDATA  Data layer for the human bench dataset.
%   Loads the 7-participant x 4-voltage x 4-load rig data, window-smooths each
%   trial, fits the PMSG/converter efficiency map  eta(omega,T)=Pe/(Pe+k0+ki*w^2+kc*T^2),
%   and calibrates a critical-power / W'-balance fatigue model.
%
%   hd = HumanData('Data.xlsx');
%   e  = hd.eta_gen(omega, torque, Pe);

    properties
        T            % raw table
        omega; torque
        eff_k        % [k0 ki kc]
        eff_R2; eff_RMSE
        eff_bins     % struct array of binned means (for the surface figure)
        CP; Wprime; Pmax_burst
    end

    methods
        function obj = HumanData(path)
            opt = detectImportOptions(path);
            opt.VariableNamingRule = 'preserve';
            T = readtable(path, opt);
            T = T(~any(ismissing(T(:,{'Testname','Battery set','Load'})),2), :);
            obj.T = T;
            obj.omega  = 2*pi*T.('Speed_RPM')/60.0;
            obj.torque = T.('Pressure_N')*sair_const.LEVER_R;
            obj.fit_efficiency_map();
            obj.fit_fatigue();
        end

        function fit_efficiency_map(obj)
            T  = obj.T;
            Hp = T.('Human_Power_W'); Gp = T.('Gen_Power_W');
            w  = obj.omega; tq = obj.torque;
            % per-trial centred rolling mean (window 10) -------------------------
            [grp,~] = findgroups(T.('Testname'), T.('Battery set'), T.('Load'));
            sm = @(x) splitapply(@(v){movmean(v,10)}, x, grp);
            Hs = cell2mat(sm(Hp)); Gs = cell2mat(sm(Gp));
            ws = cell2mat(sm(w));  ts = cell2mat(sm(tq));
            ok = Hs > 1 & Gs > 0;
            Hs=Hs(ok); Gs=Gs(ok); ws=ws(ok); ts=ts(ok);
            eta = min(max(Gs./Hs, 0.10), 0.99);
            % 12 x 12 binning on (omega,torque) ---------------------------------
            ob = discretize(ws, 12); tb = discretize(ts, 12);
            key = ob*100 + tb; uk = unique(key);
            om=[]; tqm=[]; Pe=[]; em=[]; nn=[];
            for i = 1:numel(uk)
                m = key==uk(i);
                if nnz(m) >= 15
                    om(end+1)=mean(ws(m)); tqm(end+1)=mean(ts(m)); %#ok<AGROW>
                    Pe(end+1)=mean(Gs(m)); em(end+1)=mean(eta(m)); nn(end+1)=nnz(m); %#ok<AGROW>
                end
            end
            wt = sqrt(nn(:));
            S.om=om(:); S.tq=tqm(:); S.Pe=Pe(:); S.eta=em(:); S.n=nn(:);
            obj.eff_bins = S;
            % weighted nonlinear least squares (base-MATLAB fminsearch) ----------
            model = @(k,om,tq,Pe) Pe./(Pe + k(1) + k(2)*om.^2 + k(3)*tq.^2);
            cost  = @(k) sum(wt.*(model(abs(k),S.om,S.tq,S.Pe) - S.eta).^2);
            k0 = fminsearch(cost, [2, 0.02, 20], optimset('MaxFunEvals',2e4,'MaxIter',2e4));
            k0 = abs(k0);
            ef = model(k0, S.om, S.tq, S.Pe);
            obj.eff_k    = k0;
            ebar = sum(wt.*S.eta)/sum(wt);
            obj.eff_R2   = 1 - sum(wt.*(ef-S.eta).^2)/sum(wt.*(S.eta-ebar).^2);
            obj.eff_RMSE = sqrt(sum(wt.*(ef-S.eta).^2)/sum(wt));
        end

        function e = eta_gen(obj, omega, torque, Pe)
            k = obj.eff_k;
            e = min(max(Pe./(Pe + k(1) + k(2)*omega.^2 + k(3)*torque.^2), 0.05), 0.99);
        end

        function fit_fatigue(obj)
            T = obj.T; Hp = T.('Human_Power_W');
            [g,~] = findgroups(T.('Testname'), T.('Battery set'), T.('Load'));
            trialMean = splitapply(@mean, Hp, g);
            obj.CP         = pctl(trialMean, 55);   % critical (sustainable) power
            obj.Wprime     = 9.0e3;                    % J anaerobic capacity
            obj.Pmax_burst = pctl(Hp, 98);
        end
    end
end

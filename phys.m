classdef phys
%PHYS  Static physical-model helpers shared by the four source adapters.
%   All curves are the dossier-calibrated forms used in the paper.

methods (Static)

    % -------- wind: analytic Cp(lambda,beta) and PMSG efficiency ridge --------
    function cp = cp_curve(lam, beta)
        if nargin < 2, beta = 0.0; end
        lam = max(lam, 1e-3);
        li  = 1.0 ./ (1.0./(lam + 0.08*beta) - 0.035./(beta.^3 + 1));
        cp  = 0.5176*(116./li - 0.4*beta - 5).*exp(-21./li) + 0.0068*lam;
        cp  = min(max(cp, 0), sair_const.CP_MAX);
    end

    function e = pmsg_eff(load_frac, speed_frac)
        % Gaussian ridge: ~0.95 peak on the optimal-operating line -> ~0.82 corners
        ridge = exp(-((load_frac-0.65).^2)/(2*0.32^2)) .* ...
                exp(-((speed_frac-0.60).^2)/(2*0.45^2));
        e = 0.82 + 0.13*ridge;
    end

    % -------- micro-hydro: Francis best-efficiency-point curve --------
    function e = francis_eff(qf)
        e = min(max(0.90*exp(-((qf-1.0).^2)/(2*0.28^2)), 0.05), 0.90);
    end

    % -------- solar: lumped single-diode KC200GT --------
    function I = pv_current(V, G, Tc)
        % Vectorised current I(V) for a vector of operating voltages V.
        PV = sair_const.PV; qe = sair_const.Q_E; kb = sair_const.K_B;
        V  = V(:).';
        Tk = Tc + 273.15;
        Vt = PV.a*PV.Ns*kb*Tk/qe;
        Iph = (PV.Iph + PV.Ki*(Tc-25))*G/1000.0;
        I0  = PV.I0*(Tk/298.15)^3*exp(qe*1.12/(PV.a*kb)*(1/298.15 - 1/Tk));
        I   = Iph*ones(size(V));
        for k = 1:12                                   % vectorised Newton
            e  = exp(min(max((V + I*PV.Rs)/Vt, -40), 40));
            f  = Iph - I0*(e-1) - (V + I*PV.Rs)/PV.Rsh - I;
            df = -I0*PV.Rs/Vt.*e - PV.Rs/PV.Rsh - 1;
            I  = I - f./df;
        end
        I = max(I, 0);
    end

    function I = pv_iv(V, G, Tc)
        I = phys.pv_current(V, G, Tc); I = I(1);
    end

    function [Vmpp, Pmpp] = pv_mpp(G, Tc)
        PV  = sair_const.PV;
        Voc = PV.Voc*(1 + PV.Kv/PV.Voc*(Tc-25));
        Vs  = linspace(0.05, max(Voc,1.0), 48);
        P   = Vs.*phys.pv_current(Vs, G, Tc);
        [~,k] = max(P);
        lo = max(1,k-1); hi = min(numel(Vs),k+1);      % local refine
        Vr = linspace(Vs(lo), Vs(hi), 24);
        Pr = Vr.*phys.pv_current(Vr, G, Tc);
        [Pmpp,j] = max(Pr); Vmpp = Vr(j);
    end

    % -------- unified state helpers --------
    function [g1,g2] = grad(buf)
        if numel(buf) < 3, g1 = 0.0; g2 = 0.0; return; end
        g1 = buf(end) - buf(end-1);
        g2 = buf(end) - 2*buf(end-1) + buf(end-2);
    end

    function z = context(buf_hist)
        % g_phi: recent power window -> low-dim source context (rate, volatility, drift)
        a = buf_hist(max(1,end-sair_const.N_WIN+1):end);
        if numel(a) > 1, rate = mean(diff(a)); else, rate = 0.0; end
        z = [rate, std(a), a(end)-a(1)];
    end

    % -------- viridis colormap (matplotlib), 16 anchors interpolated to N --------
    function cm = viridis(N)
        if nargin < 1, N = 256; end
        anc = [ ...
            0.267004 0.004874 0.329415; 0.282623 0.140926 0.457517; ...
            0.253935 0.265254 0.529983; 0.206756 0.371758 0.553117; ...
            0.163625 0.471133 0.558148; 0.127568 0.566949 0.550556; ...
            0.134692 0.658636 0.517649; 0.266941 0.748751 0.440573; ...
            0.477504 0.821444 0.318195; 0.741388 0.873449 0.149561; ...
            0.993248 0.906157 0.143936; 0.993248 0.906157 0.143936; ...
            0.288921 0.758394 0.428426; 0.190631 0.407061 0.556089; ...
            0.282623 0.140926 0.457517; 0.267004 0.004874 0.329415];
        anc = anc(1:11,:);                              % monotone segment
        xi  = linspace(0,1,size(anc,1));
        xq  = linspace(0,1,N);
        cm  = [interp1(xi,anc(:,1),xq).' , interp1(xi,anc(:,2),xq).' , ...
               interp1(xi,anc(:,3),xq).'];
        cm  = min(max(cm,0),1);
    end

end
end

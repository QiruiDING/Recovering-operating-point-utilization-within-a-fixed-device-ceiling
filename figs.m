classdef figs
%FIGS  Four composite, top-journal-grade figures (Nature-family styling).
%   No bar charts anywhere; no panel titles and no figure titles (clean canvas,
%   panel letters + axis labels only).  Larger, readable fonts.  NPG palette,
%   viridis fields, left/bottom spines, ticks out, data points overlaid.
%
%   Figure forms:
%     - estimation / ladder plots (per-seed swarm + mean trajectory + reference bands)
%     - before/after dumbbell (connected-dot) plots
%     - a 2-D mechanism plane with iso-gain diagonals
%     - a balloon (bubble) matrix instead of a flat heatmap
%   plus filled efficiency fields, parity with error envelope, dual-axis working-point
%   curves and kernel-density violins.
%
%   The data interface is UNCHANGED from SAIR_main.m, so no other file needs editing.

methods (Static)

    % ============================ export ==================================
    function save_fig(fig, name, wcm, hcm)
        if nargin < 3, wcm = 18.0; end
        if nargin < 4, hcm = 15.0; end
        outdir = fullfile(pwd,'figures');
        if ~isfolder(outdir), mkdir(outdir); end
        set(fig,'Units','centimeters','Position',[2 2 wcm hcm], ...
                'PaperUnits','centimeters','PaperPosition',[0 0 wcm hcm], ...
                'PaperSize',[wcm hcm],'Color','w','Renderer','painters');
        try, set(fig,'DefaultTextFontName','Arial','DefaultAxesFontName','Arial'); end %#ok<TRYNC>
        png = fullfile(outdir,[name '.png']); pdf = fullfile(outdir,[name '.pdf']);
        try
            exportgraphics(fig, png, 'Resolution', 600, 'BackgroundColor','white');
            exportgraphics(fig, pdf, 'ContentType','vector','BackgroundColor','white');
        catch
            print(fig, png, '-dpng', '-r600'); print(fig, pdf, '-dpdf', '-painters');
        end
        fprintf('  wrote %s (+ .pdf)\n', png);
    end

    % ============================ shared chrome ===========================
    function panel_label(ax, s)
        text(ax, -0.16, 1.06, s, 'Units','normalized', 'FontWeight','bold', ...
             'FontSize',11, 'FontName','Arial', 'VerticalAlignment','bottom', ...
             'HorizontalAlignment','left');
    end

    function polish(ax)
        set(ax,'LineWidth',0.7,'TickDir','out','TickLength',[0.02 0.02], ...
               'Box','off','Layer','top','FontSize',8, ...
               'XColor',[0.20 0.20 0.20],'YColor',[0.20 0.20 0.20]);
    end

    function srclabel(ax, s)                       % small in-panel identity (not a title)
        text(ax, 0.035, 0.96, s, 'Units','normalized', 'FontSize',8.5, ...
             'FontWeight','bold', 'Color',[0.40 0.40 0.40], ...
             'HorizontalAlignment','left', 'VerticalAlignment','top');
    end

    % ============== FIG 1 : source & device characterization ==============
    function fig = fig1_source(hd, hw, cells, P)
        fig = figure;
        t = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

        % ---- (a) efficiency field eta(omega,tau) -------------------------
        ax = nexttile(t); hold(ax,'on');
        S = hd.eff_bins; k = hd.eff_k;
        wq = linspace(min(S.om),max(S.om),140); tq = linspace(min(S.tq),max(S.tq),140);
        [Wg,Tg] = meshgrid(wq,tq);
        Pn = griddata(S.om,S.tq,S.Pe,Wg,Tg,'natural');
        Pf = griddata(S.om,S.tq,S.Pe,Wg,Tg,'nearest'); Pn(isnan(Pn)) = Pf(isnan(Pn));
        Zg = min(max(Pn./(Pn + k(1) + k(2)*Wg.^2 + k(3)*Tg.^2),0),1);
        contourf(ax, Wg, Tg, Zg, 18, 'LineColor','none');
        colormap(ax, phys.viridis(256));
        contour(ax, Wg, Tg, Zg, 8, 'LineColor',[1 1 1], 'LineWidth',0.3);
        [~,ir] = max(Zg,[],1);
        plot(ax, wq, tq(ir), '-', 'Color',P.SAIR, 'LineWidth',2.0);
        [~,lin] = max(Zg(:)); [rp,cp] = ind2sub(size(Zg),lin);
        plot(ax, Wg(rp,cp), Tg(rp,cp), 'p', 'MarkerFaceColor',P.SAIR, ...
             'MarkerEdgeColor','w','MarkerSize',13,'LineWidth',0.6);
        sn = 9 + 34*(S.n - min(S.n))/max(max(S.n)-min(S.n),1);
        scatter(ax, S.om, S.tq, sn, [1 1 1], 'filled', 'MarkerEdgeColor',[0 0 0], ...
                'LineWidth',0.2, 'MarkerFaceAlpha',0.55);
        text(ax, wq(round(0.62*end)), tq(ir(round(0.62*end)))+0.14, 'optimal ridge', ...
             'Color',P.SAIR,'FontSize',7.5,'FontAngle','italic');
        cb = colorbar(ax); cb.Label.String = '\eta_{gen} (-)'; cb.LineWidth = 0.5;
        cb.Label.FontSize = 8.5; cb.FontSize = 8;
        cb.Ticks = round(linspace(min(Zg(:)),max(Zg(:)),4),2);
        axis(ax,'tight');
        xlabel(ax,'angular speed  \omega (rad s^{-1})'); ylabel(ax,'torque  \tau (N m)');
        figs.polish(ax); figs.panel_label(ax,'a');

        % ---- (b) parity plot with RMSE envelope --------------------------
        ax = nexttile(t); hold(ax,'on');
        pred = S.Pe ./ (S.Pe + k(1) + k(2)*S.om.^2 + k(3)*S.tq.^2);
        L = [min([pred;S.eta])-0.03, max([pred;S.eta])+0.03];
        xb = linspace(L(1),L(2),60);
        patch(ax, [xb fliplr(xb)], [xb-hd.eff_RMSE fliplr(xb+hd.eff_RMSE)], P.PNO, ...
              'FaceAlpha',0.12, 'EdgeColor','none');
        plot(ax, L, L, '--', 'Color',[0.5 0.5 0.5], 'LineWidth',0.9);
        sn = 16 + 52*(S.n - min(S.n))/max(max(S.n)-min(S.n),1);
        scatter(ax, S.eta, pred, sn, P.PNO, 'filled', 'MarkerFaceAlpha',0.6, ...
                'MarkerEdgeColor','w','LineWidth',0.3);
        xlim(ax,L); ylim(ax,L); axis(ax,'square');
        xlabel(ax,'measured  \eta (-)'); ylabel(ax,'predicted  \eta (-)');
        text(ax, 0.05, 0.95, sprintf('R^2 = %.3f\nRMSE = %.3f', hd.eff_R2, hd.eff_RMSE), ...
             'Units','normalized','FontSize',8.5,'VerticalAlignment','top');
        text(ax, 0.97, 0.05, 'marker area \propto bin count', 'Units','normalized', ...
             'FontSize',7,'Color',[0.45 0.45 0.45],'HorizontalAlignment','right');
        figs.polish(ax); figs.panel_label(ax,'b');

        % ---- (c) greedy MPP vs risk-discounted sustainable optimum -------
        ax = nexttile(t); hold(ax,'on');
        [~,imp]  = max(hw.Pe); [~,iopt] = max(hw.J);
        yyaxis(ax,'left');
        plot(ax, hw.u, hw.Pe, '-', 'Color',P.PNO, 'LineWidth',2.0);
        plot(ax, hw.u(imp), hw.Pe(imp), 'o', 'MarkerFaceColor',P.PNO, ...
             'MarkerEdgeColor','w','MarkerSize',6.5);
        ylp = ylim(ax);
        plot(ax, [hw.u(imp) hw.u(imp)], [ylp(1) hw.Pe(imp)], ':', 'Color',P.PNO, 'LineWidth',0.9);
        text(ax, hw.u(imp)+0.03, hw.Pe(imp)+0.06*(ylp(2)-ylp(1)), 'greedy MPP', ...
             'Color',P.PNO,'FontSize',8,'HorizontalAlignment','left');
        ylabel(ax,'electrical power  P_{elec} (W)'); ax.YColor = P.PNO;
        yyaxis(ax,'right');
        hr = patch(ax, [hw.u(iopt) 1 1 hw.u(iopt)], [0 0 1.08 1.08], P.SAIR, ...
                   'FaceAlpha',0.08, 'EdgeColor','none'); uistack(hr,'bottom');
        area(ax, hw.u, hw.J, 'FaceColor',P.SAIR, 'FaceAlpha',0.12, 'EdgeColor','none');
        plot(ax, hw.u, hw.J, '-', 'Color',P.SAIR, 'LineWidth',2.0);
        plot(ax, hw.u(iopt), hw.J(iopt), 'o', 'MarkerFaceColor',P.SAIR, ...
             'MarkerEdgeColor','w','MarkerSize',6.5);
        plot(ax, [hw.u(iopt) hw.u(iopt)], [0 hw.J(iopt)], ':', 'Color',P.SAIR, 'LineWidth',0.9);
        text(ax, hw.u(iopt)-0.03, hw.J(iopt)+0.05, 'SAIR optimum', ...
             'Color',P.SAIR,'FontSize',8,'HorizontalAlignment','right');
        plot(ax, [hw.u(iopt) hw.u(imp)], [0.10 0.10], '-', 'Color',[0.35 0.35 0.35], 'LineWidth',1.0);
        text(ax, mean([hw.u(iopt) hw.u(imp)]), 0.155, '\Deltau pacing', ...
             'Color',[0.35 0.35 0.35],'FontSize',7.5,'HorizontalAlignment','center');
        ylabel(ax,'risk-discounted objective  J (norm.)'); ax.YColor = P.SAIR; ylim(ax,[0 1.08]);
        yyaxis(ax,'left'); xlabel(ax,'load fraction  u (-)'); xlim(ax,[0 1]);
        figs.polish(ax); figs.panel_label(ax,'c');

        % ---- (d) realized efficiency across conditions (violins) ---------
        ax = nexttile(t); hold(ax,'on');
        nC = numel(cells);
        vmap = phys.viridis(256); vidx = round(linspace(38,224,nC));
        allv = []; meds = nan(1,nC);
        for i = 1:nC
            v = cells(i).vals(:); allv = [allv; v]; %#ok<AGROW>
            if numel(v)>=2, meds(i) = median(v); end
        end
        ylo = max(0, min(allv)-0.05); yhi = min(1.02, max(allv)+0.04);
        hpad = 0.14*(yhi-ylo); ytop = yhi + hpad;
        plot(ax, 1:nC, meds, '-', 'Color',[0.7 0.7 0.7], 'LineWidth',1.1);
        for i = 1:nC, figs.violin(ax, i, cells(i).vals, vmap(vidx(i),:)); end
        ylim(ax,[ylo ytop]); xlim(ax,[0.45 nC+0.55]);
        for i = 1:nC
            text(ax, i, ytop, sprintf('n = %d',numel(cells(i).vals)), 'FontSize',7.5, ...
                 'Color',[0.4 0.4 0.4],'HorizontalAlignment','center','VerticalAlignment','top');
        end
        set(ax,'XTick',1:nC,'XTickLabel',{cells.label});
        ylabel(ax,'realized  \eta_{sys} (-)'); xlabel(ax,'battery-bank voltage (V)');
        figs.polish(ax); figs.panel_label(ax,'d');
    end

    % ================= FIG 2 : cross-source transfer ======================
    function fig = fig2_transfer(trans, se, P)
        fig = figure;
        t = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
        srcs = {'wind','solar','hydro'}; labs = {'a','b','c'};
        conds = {'zeroshot','fewshot','upper'}; cshade = [0.5 0.72 1.0];

        for s = 1:3
            ax = nexttile(t); hold(ax,'on'); R = trans.(srcs{s});
            mu = zeros(1,3); sd = zeros(1,3);
            for c = 1:3, mu(c)=R.(conds{c}).eta_track(1); sd(c)=R.(conds{c}).eta_track(2); end
            po  = R.pno.eta_track(1);  pos = R.pno.eta_track(2);
            orc = R.oracle.eta_track(1);

            patch(ax, [0.5 3.5 3.5 0.5], [po-pos po-pos po+pos po+pos], P.PNO, ...
                  'FaceAlpha',0.10, 'EdgeColor','none');
            hPO = plot(ax, [0.5 3.5], [po po],  '--', 'Color',P.PNO,    'LineWidth',1.1);
            hOR = plot(ax, [0.5 3.5], [orc orc], ':',  'Color',P.ORACLE,'LineWidth',1.1);

            for c = 1:3
                if isfield(R.(conds{c}),'raw') && ~isempty(R.(conds{c}).raw)
                    v = R.(conds{c}).raw(:); xj = c + figs.jitterx(numel(v),0.12);
                    scatter(ax, xj, v, 9, [0.45 0.45 0.45], 'filled', ...
                            'MarkerFaceAlpha',0.55, 'MarkerEdgeColor','none');
                end
            end
            plot(ax, 1:3, mu, '-', 'Color',P.SAIR, 'LineWidth',2.0);
            for c = 1:3
                plot(ax, [c c], [mu(c)-sd(c) mu(c)+sd(c)], '-', 'Color',P.SAIR, 'LineWidth',1.1);
                plot(ax, c, mu(c), 'o', 'MarkerFaceColor',figs.cblend(P.SAIR,cshade(c)), ...
                     'MarkerEdgeColor','w','MarkerSize',7.5,'LineWidth',0.7);
            end
            dpp = 100*(mu(3)-po); xb = 3.34;
            plot(ax, [xb xb], [po mu(3)], '-', 'Color',[0.3 0.3 0.3], 'LineWidth',0.7);
            plot(ax, [3 xb], [mu(3) mu(3)], '-', 'Color',[0.3 0.3 0.3], 'LineWidth',0.5);
            plot(ax, [3 xb], [po po],       '-', 'Color',[0.3 0.3 0.3], 'LineWidth',0.5);
            text(ax, xb+0.07, mean([po mu(3)]), sprintf('%+.0f pp',dpp), 'Rotation',90, ...
                 'FontSize',7,'Color',[0.2 0.2 0.2],'HorizontalAlignment','center', ...
                 'VerticalAlignment','bottom');

            lo = max(0, min([mu-sd, po-pos, orc])-0.04);
            ylim(ax,[lo 1.05]); xlim(ax,[0.5 3.78]);
            set(ax,'XTick',1:3,'XTickLabel',{'zero','few','upper'});
            if s==1, ylabel(ax,'MPP tracking efficiency  \eta_{track} (-)'); end
            figs.srclabel(ax, srcs{s});
            if s==1
                legend([hPO hOR], {'P&O baseline','full-information'}, 'Location','south', ...
                       'Box','off','FontSize',7.5);
            end
            figs.polish(ax); figs.panel_label(ax, labs{s});
        end

        % ---- (d) sample efficiency, normalised, wind + solar -------------
        ax = nexttile(t); hold(ax,'on');
        if isfield(se,'wind') && isfield(se,'solar')
            pairs = {se.wind, P.WIND, 'wind'; se.solar, P.SOLAR, 'solar'};
            h = []; lab = {};
            for j = 1:size(pairs,1)
                D = pairs{j,1}; col = pairs{j,2};
                a = mean(D.scratch(max(1,end-2):end));
                figs.shaded(ax, D.eps, D.scratch_lo/a, D.scratch_hi/a, col);
                figs.shaded(ax, D.eps, D.human_lo/a,   D.human_hi/a,   col);
                plot(ax, D.eps, D.scratch/a, '--', 'Color',col, 'LineWidth',1.2);
                hh = plot(ax, D.eps, D.human/a, '-', 'Color',col, 'LineWidth',1.8);
                ci = find(D.human/a >= 0.9, 1, 'first');
                if ~isempty(ci)
                    plot(ax, [D.eps(ci) D.eps(ci)], [0 0.9], ':', 'Color',col, 'LineWidth',0.7);
                    plot(ax, D.eps(ci), 0.9, 'v', 'MarkerFaceColor',col, ...
                         'MarkerEdgeColor','w','MarkerSize',7,'LineWidth',0.5);
                end
                h(end+1)=hh; lab{end+1}=sprintf('%s  (-%.0f%% data)',pairs{j,3},100*D.reduction); %#ok<AGROW>
            end
            yline(ax, 0.9, ':', 'Color',[0.5 0.5 0.5], 'LineWidth',0.8);
            text(ax, 0.99, 0.85, '90% of asymptote', 'Units','normalized','FontSize',7, ...
                 'Color',[0.45 0.45 0.45],'HorizontalAlignment','right');
            xlabel(ax,'target-domain episodes (-)'); ylabel(ax,'normalised return (-)');
            ylim(ax,[0 1.08]);
            legend(h, lab, 'Location','southeast', 'Box','off', 'FontSize',7.5);
            text(ax, 0.02, 0.10, 'dashed: from scratch    solid: human-init', ...
                 'Units','normalized','FontSize',7,'Color',[0.35 0.35 0.35]);
        end
        figs.polish(ax); figs.panel_label(ax,'d');
    end

    % ================= FIG 3 : closed-loop dynamics =======================
    function fig = fig3_dynamics(td, cv, P)
        fig = figure;
        t = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

        nm = {'solar','wind'}; labs = {'a','b'};
        for q = 1:2
            ax = nexttile(t); hold(ax,'on'); D = td.(nm{q});
            yl = [0, max([D.SAIR D.PNO D.ORACLE])*1.15];
            on = find(diff([0 D.dist])==1); off = find(diff([D.dist 0])==-1);
            hPa = [];
            for j = 1:min(numel(on),numel(off))
                hPa = patch(ax, [D.t(on(j)) D.t(off(j)) D.t(off(j)) D.t(on(j))], ...
                            [yl(1) yl(1) yl(2) yl(2)], P.amber, 'FaceAlpha',0.22, 'EdgeColor','none');
            end
            figs.shaded(ax, D.t, min(D.SAIR,D.ORACLE), max(D.SAIR,D.ORACLE), P.SAIR);
            hO = plot(ax, D.t, D.ORACLE, '-', 'Color',P.ORACLE, 'LineWidth',0.8);
            hP = plot(ax, D.t, D.PNO,    '-', 'Color',P.PNO,    'LineWidth',1.1);
            hS = plot(ax, D.t, D.SAIR,   '-', 'Color',P.SAIR,   'LineWidth',1.6);
            xlim(ax,[D.t(1) D.t(end)]); ylim(ax, yl);
            ylabel(ax,'power (W)'); xlabel(ax,'time (s)');
            figs.srclabel(ax, nm{q});
            if q==1
                items = [hS hP hO]; names = {'SAIR','P&O','full-info'};
                if ~isempty(hPa), items = [hPa items]; names = ['disturbance' names]; end
                legend(items, names, 'Location','southeast','Box','off','FontSize',7.5);
            end
            figs.polish(ax); figs.panel_label(ax, labs{q});
        end

        % ---- (c) output CV across sources : before/after dumbbell --------
        ax = nexttile(t); hold(ax,'on');
        ns = numel(cv.labels); X = 1:ns;
        ymax = max([cv.pno cv.sair]); yl = [0, ymax*1.25];
        patch(ax, [0.4 ns+1.0 ns+1.0 0.4], [0 0 0.15 0.15], P.HYDRO, ...
              'FaceAlpha',0.09, 'EdgeColor','none');
        yline(ax, 0.15, '--', 'Color',[0.4 0.4 0.4], 'LineWidth',0.9);
        for i = 1:ns
            figs.dumbbell(ax, X(i), cv.pno(i), cv.sair(i), P.PNO, P.SAIR);
            red = 100*(cv.pno(i)-cv.sair(i))/max(cv.pno(i),1e-9);
            text(ax, X(i)+0.18, cv.sair(i), sprintf('-%.0f%%',red), ...
                 'FontSize',7.5,'Color',[0.25 0.25 0.25], ...
                 'HorizontalAlignment','left','VerticalAlignment','middle');
        end
        set(ax,'XTick',X,'XTickLabel',cv.labels); xlim(ax,[0.5 ns+1.05]); ylim(ax, yl);
        ylabel(ax,'output CV (-)');
        text(ax, ns+1.0, 0.15, 'target', 'FontSize',7.5,'Color',[0.4 0.4 0.4], ...
             'HorizontalAlignment','right','VerticalAlignment','bottom');
        hPd = plot(ax, nan, nan, 'o', 'MarkerFaceColor',P.PNO, 'MarkerEdgeColor','w','MarkerSize',7);
        hSd = plot(ax, nan, nan, 'o', 'MarkerFaceColor',P.SAIR,'MarkerEdgeColor','w','MarkerSize',7);
        legend([hPd hSd], {'P&O','SAIR'}, 'Location','northeast','Box','off','FontSize',7.5);
        figs.polish(ax); figs.panel_label(ax,'c');

        % ---- (d) human anaerobic-reserve trajectory ----------------------
        ax = nexttile(t); hold(ax,'on'); H = td.human;
        patch(ax, [H.t(1) H.t(end) H.t(end) H.t(1)], [0 0 0.10 0.10], P.SAIR, ...
              'FaceAlpha',0.07, 'EdgeColor','none');
        plot(ax, H.t, H.H_PNO,  '-', 'Color',P.PNO,  'LineWidth',1.4);
        plot(ax, H.t, H.H_SAIR, '-', 'Color',P.SAIR, 'LineWidth',1.7);
        di = find(H.H_PNO <= 0.1, 1, 'first');
        if ~isempty(di)
            plot(ax, H.t(di), H.H_PNO(di), 'o', 'MarkerFaceColor',P.PNO, ...
                 'MarkerEdgeColor','w','MarkerSize',6);
        end
        ylim(ax,[0 1.05]); xlim(ax,[H.t(1) H.t(end)]);
        xlabel(ax,'time (s)'); ylabel(ax,'source health  W''/W''_{max} (-)');
        text(ax, 0.96, 0.92, 'SAIR sustains', 'Units','normalized','FontSize',8, ...
             'Color',P.SAIR,'HorizontalAlignment','right');
        text(ax, 0.96, 0.16, 'P&O depletes (bonk)', 'Units','normalized','FontSize',8, ...
             'Color',P.PNO,'HorizontalAlignment','right');
        text(ax, 0.035, 0.06, 'human', 'Units','normalized', 'FontSize',8.5, ...
             'FontWeight','bold', 'Color',[0.40 0.40 0.40], ...
             'HorizontalAlignment','left', 'VerticalAlignment','bottom');
        figs.polish(ax); figs.panel_label(ax,'d');
    end

    % ================= FIG 4 : mechanism + summary ========================
    function fig = fig4_mechanism(decomp, H, P)
        fig = figure;
        t = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

        % ---- (a) device-efficiency vs control contribution : 2-D plane ---
        ax = nexttile(t); hold(ax,'on');
        srcs = decomp.srcs; dev = decomp.dev(:); ctl = decomp.ctrl(:); tot = dev+ctl;
        cols = [P.WIND; P.SOLAR; P.HYDRO];
        allx = [dev;0]; ally = [ctl;0];
        dx = max(max(allx)-min(allx), 1); dy = max(max(ally)-min(ally), 1);
        xr = [min(allx)-0.22*dx, max(allx)+0.50*dx];
        yr = [min(ally)-0.28*dy, max(ally)+0.30*dy];
        dxr = xr(2)-xr(1); dyr = yr(2)-yr(1);
        tlo = floor(min([tot;0])-1); thi = ceil(max([tot;0])+1);
        for c = unique(round(linspace(tlo,thi,7)))
            plot(ax, xr, [c-xr(1) c-xr(2)], ':', 'Color',[0.85 0.85 0.85], 'LineWidth',0.6);
        end
        plot(ax, xr, xr, ':', 'Color',[0.9 0.9 0.9], 'LineWidth',0.6);
        xline(ax,0,'-','Color',[0.55 0.55 0.55],'LineWidth',0.6);
        yline(ax,0,'-','Color',[0.55 0.55 0.55],'LineWidth',0.6);
        for s = 1:numel(srcs)
            plot(ax, [dev(s) dev(s)], [yr(1) ctl(s)], ':', 'Color',cols(s,:), 'LineWidth',0.5);
            plot(ax, [xr(1) dev(s)], [ctl(s) ctl(s)], ':', 'Color',cols(s,:), 'LineWidth',0.5);
            plot(ax, dev(s), ctl(s), 'o', 'MarkerFaceColor',cols(s,:), ...
                 'MarkerEdgeColor','w','MarkerSize',12,'LineWidth',0.8);
            dyoff = 0.055*dyr; if ctl(s) > yr(2)-0.20*dyr, dyoff = -0.075*dyr; end
            text(ax, dev(s)+0.05*dxr, ctl(s)+dyoff, sprintf('%s  %+.1f pp',upper(srcs{s}),tot(s)), ...
                 'Color',cols(s,:),'FontSize',8.5,'HorizontalAlignment','left','FontWeight','bold');
        end
        text(ax, xr(1)+0.04*dxr, yr(2)-0.04*dyr, 'control-limited', 'FontSize',7.5, ...
             'Color',[0.6 0.6 0.6],'FontAngle','italic','HorizontalAlignment','left','VerticalAlignment','top');
        text(ax, xr(2)-0.04*dxr, yr(1)+0.05*dyr, 'device-limited', 'FontSize',7.5, ...
             'Color',[0.6 0.6 0.6],'FontAngle','italic','HorizontalAlignment','right','VerticalAlignment','bottom');
        text(ax, xr(1)+0.04*dxr, yr(1)+0.05*dyr, 'dotted: equal total gain', 'FontSize',7, ...
             'Color',[0.65 0.65 0.65],'HorizontalAlignment','left','VerticalAlignment','bottom');
        xlim(ax,xr); ylim(ax,yr);
        xlabel(ax,'device-efficiency contribution (%)');
        ylabel(ax,'control / capture contribution (%)');
        figs.polish(ax); figs.panel_label(ax,'a');

        % ---- (b) multi-metric improvement : balloon (bubble) matrix ------
        ax = nexttile(t); hold(ax,'on');
        Z = H.vals; [nr,nc] = size(Z);
        Zc = (Z - min(Z,[],1)) ./ max(max(Z,[],1)-min(Z,[],1), 1e-9);
        cm = phys.viridis(256);
        for gx = 1:nc
            plot(ax, [gx gx], [0.4 nr+0.6], '-', 'Color',[0.93 0.93 0.93], 'LineWidth',0.5);
        end
        for r = 1:nr
            for c = 1:nc
                z = Zc(r,c); val = Z(r,c);
                ci = min(max(round(z*255)+1,1),256); col = cm(ci,:);
                ms = 22 + 18*sqrt(max(z,0.02));
                plot(ax, c, r, 'o', 'MarkerFaceColor',col, 'MarkerEdgeColor',[0.3 0.3 0.3], ...
                     'MarkerSize',ms,'LineWidth',0.4);
                tc = [1 1 1]; if z>0.55, tc = [0 0 0]; end
                text(ax, c, r, H.fmt{c}(val), 'HorizontalAlignment','center', ...
                     'VerticalAlignment','middle','FontSize',7.5,'Color',tc);
            end
        end
        set(ax,'XTick',1:nc,'XTickLabel',H.metrics,'YTick',1:nr,'YTickLabel',H.rows, ...
               'YDir','reverse','TickLength',[0 0],'Box','off');
        ax.XAxis.FontSize = 8; ax.YAxis.FontSize = 8.5;
        xlim(ax,[0.4 nc+0.6]); ylim(ax,[0.4 nr+0.6]);
        set(ax,'LineWidth',0.7,'XColor',[0.20 0.20 0.20],'YColor',[0.20 0.20 0.20]);
        figs.panel_label(ax,'b');
    end

    % ============================ primitives ==============================
    function c = cblend(col, f)
        c = (1-f)*[1 1 1] + f*col(:).'; c = min(max(c,0),1);
    end

    function xo = jitterx(n, w)
        if n <= 1, xo = 0; return; end
        rs = RandStream('mt19937ar','Seed', 7000 + n);
        xo = (rand(rs, n, 1) - 0.5) * 2 * w;
    end

    function dumbbell(ax, x, yhi, ylo, chi, clo)
        plot(ax, [x x], [ylo yhi], '-', 'Color',[0.6 0.6 0.6], 'LineWidth',1.6);
        plot(ax, x, yhi, 'o', 'MarkerFaceColor',chi, 'MarkerEdgeColor','w', 'MarkerSize',7.5, 'LineWidth',0.7);
        plot(ax, x, ylo, 'o', 'MarkerFaceColor',clo, 'MarkerEdgeColor','w', 'MarkerSize',7.5, 'LineWidth',0.7);
    end

    function shaded(ax, x, lo, hi, col)
        x = x(:).'; lo = lo(:).'; hi = hi(:).';
        patch(ax, [x fliplr(x)], [lo fliplr(hi)], col, 'FaceAlpha',0.16, 'EdgeColor','none');
    end

    function violin(ax, xc, v, col)
        v = v(:); v = v(~isnan(v)); if numel(v) < 2, return; end
        lo = min(v); hi = max(v); yy = linspace(lo-0.02, hi+0.02, 80);
        bw = 0.9*std(v)*numel(v)^(-1/5) + 1e-3;
        d = zeros(size(yy));
        for i = 1:numel(v), d = d + exp(-0.5*((yy-v(i))/bw).^2); end
        d = d/(numel(v)*bw*sqrt(2*pi)); d = d/max(d)*0.34;
        patch(ax, [xc+d, fliplr(xc-d)], [yy, fliplr(yy)], col, ...
              'FaceAlpha',0.42, 'EdgeColor',col, 'LineWidth',0.7);
        scatter(ax, xc + 0.05*(rand(numel(v),1)-0.5), v, 8, [0.15 0.15 0.15], ...
                'filled', 'MarkerFaceAlpha',0.4);
        plot(ax, [xc xc], [pctl(v,25) pctl(v,75)], '-', 'Color',[0 0 0], 'LineWidth',2.4);
        plot(ax, xc, median(v), 'o', 'MarkerFaceColor','w', 'MarkerEdgeColor','k', 'MarkerSize',3.6);
    end

end
end
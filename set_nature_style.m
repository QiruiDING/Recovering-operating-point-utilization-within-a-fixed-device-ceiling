function P = set_nature_style()
%SET_NATURE_STYLE  Publication (Nature-family) figure defaults + palette.
%
%   P = SET_NATURE_STYLE() sets graphics-root defaults and returns a struct P of
%   named RGB colours plus helper sizes.  The palette is the Nature Publishing Group
%   (NPG) qualitative scheme popularised by ggsci::pal_npg("nrc") and widely used in
%   Nature-family figures; surfaces use viridis.  Fonts are Arial/Helvetica, sized for
%   on-screen and print readability, with bold lower-case panel letters, ticks out,
%   no grid lines and thin axes.  Column widths follow the 89 mm / 183 mm rule.
%
%   Use figs.save_fig(fig,name,w,h) to export a 600-dpi RGB PNG + a vector PDF with
%   embedded TrueType fonts.

    % --- Nature Publishing Group (NPG) qualitative palette ---
    P.npg_red    = [230  75  53]/255;   % E64B35
    P.npg_cyan   = [ 77 187 213]/255;   % 4DBBD5
    P.npg_green  = [  0 160 135]/255;   % 00A087
    P.npg_dblue  = [ 60  84 136]/255;   % 3C5488
    P.npg_salmon = [243 155 127]/255;   % F39B7F
    P.npg_slate  = [132 145 180]/255;   % 8491B4
    P.npg_ltteal = [145 209 194]/255;   % 91D1C2
    P.npg_crimson= [220   0   0]/255;   % DC0000
    P.npg_brown  = [126  97  72]/255;   % 7E6148
    P.npg_taupe  = [176 156 133]/255;   % B09C85

    % neutral helpers
    P.black  = [0 0 0];
    P.grey   = [115 115 115]/255;
    P.ink    = [0.20 0.20 0.20];        % axis & near-black text
    P.cloud  = [0.45 0.45 0.45];        % secondary reference lines / annotation
    P.faint  = [0.86 0.86 0.86];        % iso-lines / guides
    P.amber  = [247 200  74]/255;       % soft disturbance-window shading

    % keep the previous generic colour names mapped onto the NPG palette so any
    % residual references stay valid (backward compatible)
    P.blue    = P.npg_dblue;
    P.skyblue = P.npg_cyan;
    P.green   = P.npg_green;
    P.orange  = P.npg_salmon;
    P.vermill = P.npg_red;
    P.purple  = P.npg_brown;
    P.yellow  = P.amber;

    % role assignment used consistently across every panel of the paper
    P.SAIR   = P.npg_red;               % proposed method (hero colour)
    P.PNO    = P.npg_dblue;             % perturb & observe baseline
    P.INC    = P.npg_cyan;              % incremental-conductance baseline
    P.ORACLE = [0.30 0.30 0.30];        % full-information reference (neutral)
    P.HUMAN  = P.npg_brown;
    P.WIND   = P.npg_dblue;
    P.SOLAR  = P.npg_salmon;
    P.HYDRO  = P.npg_green;

    % column widths (centimetres)
    P.col1 = 8.9;   P.col15 = 12.0;   P.col2 = 18.3;

    fname = 'Arial';
    co = [P.npg_red; P.npg_dblue; P.npg_green; P.npg_salmon; P.npg_cyan; P.npg_slate; P.npg_brown];
    set(groot, ...
        'DefaultAxesFontName',        fname, ...
        'DefaultAxesFontSize',        8, ...
        'DefaultAxesLabelFontSizeMultiplier', 1.15, ...
        'DefaultAxesTitleFontSizeMultiplier', 1.0, ...
        'DefaultAxesTitleFontWeight', 'normal', ...
        'DefaultAxesColorOrder',      co, ...
        'DefaultTextFontName',        fname, ...
        'DefaultTextFontSize',        8, ...
        'DefaultLegendFontSize',      7.5, ...
        'DefaultColorbarFontSize',    7.5, ...
        'DefaultAxesBox',             'off', ...
        'DefaultAxesTickDir',         'out', ...
        'DefaultAxesTickLength',      [0.018 0.018], ...
        'DefaultAxesXMinorTick',      'off', ...
        'DefaultAxesYMinorTick',      'off', ...
        'DefaultAxesXGrid',           'off', ...
        'DefaultAxesYGrid',           'off', ...
        'DefaultAxesZGrid',           'off', ...
        'DefaultAxesLineWidth',       0.7, ...
        'DefaultAxesColor',           'none', ...
        'DefaultLineLineWidth',       1.1, ...
        'DefaultFigureColor',         'w', ...
        'DefaultFigureRenderer',      'painters');
end
function y = pctl(x, p)
%PCTL  Percentile(s) of x without the Statistics Toolbox.
%   y = PCTL(x,p) returns the p-th percentile(s) of vector x (p in [0,100]),
%   using linear interpolation on the [0.5/n .. (n-0.5)/n] grid (MATLAB's
%   'linear' / Excel PERCENTILE.INC convention as used by prctile).
    x = sort(x(~isnan(x)));
    x = x(:); n = numel(x);
    if n == 0, y = nan(size(p)); return; end
    if n == 1, y = repmat(x, size(p)); return; end
    q  = ((1:n) - 0.5)/n;                 % plotting positions
    y  = interp1(q, x, p/100, 'linear');
    y(p/100 < q(1))   = x(1);             % clamp tails
    y(p/100 > q(end)) = x(end);
    y = reshape(y, size(p));
end

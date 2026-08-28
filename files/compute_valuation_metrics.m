function val = compute_valuation_metrics(data, bm)
%COMPUTE_VALUATION_METRICS Jämför nuvarande multiplar mot riktvärden och
%   skattar trend (multipel-expansion/kompression) via linjär regression
%   över de historiska perioderna i datan.

val = struct();
n = numel(data.PeriodLabels);
xChron = 1:n; % 1 = äldst, n = Current (kronologisk ordning)

metricsToTrend = {'TrailingPE','ForwardPE','EV_EBITDA','PriceToSales','PriceToBook','PEGRatio'};
val.Trends = struct();
for i = 1:numel(metricsToTrend)
    name = metricsToTrend{i};
    if isfield(data,name)
        y = data.(name);
        m = min(numel(xChron), numel(y));
        xi = xChron(1:m);
        yi = fliplr(y(1:m)); % data lagras med "Current" först -> vänd till kronologisk ordning

        valid = ~isnan(yi);
        trend = struct('slope',NaN,'r2',NaN,'direction','otillräcklig data');
        if sum(valid) >= 3
            p = polyfit(xi(valid), yi(valid), 1);
            yFit = polyval(p, xi(valid));
            ssRes = sum((yi(valid)-yFit).^2);
            ssTot = sum((yi(valid)-mean(yi(valid))).^2);
            if ssTot > 0
                r2 = 1 - ssRes/ssTot;
            else
                r2 = NaN;
            end
            trend.slope = p(1);
            trend.r2 = r2;
            if p(1) < -1e-6
                trend.direction = 'fallande (multipeln krymper - minskad optimism ELLER förbättrad intjäning)';
            elseif p(1) > 1e-6
                trend.direction = 'stigande (multipeln expanderar - ökad optimism ELLER försämrad intjäning)';
            else
                trend.direction = 'i stort sett stabil';
            end
        end
        val.Trends.(name) = trend;
    end
end

val.Comparison = struct();
val.Comparison.TrailingPE   = compareToBenchmark(data.TrailingPE(1), bm.TrailingPE);
val.Comparison.ForwardPE    = compareToBenchmark(data.ForwardPE(1), bm.ForwardPE);
val.Comparison.PEG          = compareToBenchmark(data.PEGRatio(1), bm.PEG);
val.Comparison.PriceToSales = compareToBenchmark(data.PriceToSales(1), bm.PriceToSales);
val.Comparison.PriceToBook  = compareToBenchmark(data.PriceToBook(1), bm.PriceToBook);
val.Comparison.EV_EBITDA    = compareToBenchmark(data.EV_EBITDA(1), bm.EV_EBITDA);

fields = fieldnames(val.Comparison);
scores = nan(numel(fields),1);
for i = 1:numel(fields)
    scores(i) = val.Comparison.(fields{i}).score;
end
val.ValuationScore = mean(scores(~isnan(scores)));

end


function c = compareToBenchmark(value, benchmark)
c = struct('value',value,'benchmark',benchmark,'pctDiff',NaN,'score',NaN);
if isnan(value) || isnan(benchmark) || benchmark == 0
    return;
end
pctDiff = (value - benchmark)/benchmark * 100; % positivt = dyrare än riktvärdet
c.pctDiff = pctDiff;
% Poäng 0-100: 50 = i linje med riktvärdet, >50 = billigare, <50 = dyrare.
score = 50 - pctDiff*0.4;
c.score = min(100, max(0, score));
end

function health = compute_financial_health(data, bm)
%COMPUTE_FINANCIAL_HEALTH Piotroski-inspirerad delpoäng baserad på ett
%   enskilt datasnapshot. Detta är EJ den fullständiga 9-punkters
%   Piotroski F-Score (som kräver tvaåriga bokslutsdata för att mäta
%   förändring i skuldsättning, aktieantal och marginaler) - se
%   README.md för referens och begränsningar.

c = {};
c{end+1} = makeCheck('Positiv nettovinstmarginal', data.ProfitMargin > 0, sprintf('%.2f%%', data.ProfitMargin));
c{end+1} = makeCheck('Positiv avkastning på tillgångar (ROA)', data.ReturnOnAssets > 0, sprintf('%.2f%%', data.ReturnOnAssets));
c{end+1} = makeCheck('Positivt operativt kassaflöde', data.OperatingCashFlow > 0, formatMoneyLocal(data.OperatingCashFlow));
c{end+1} = makeCheck('Kassaflöde > Nettovinst (hög vinstkvalitet)', ...
    data.OperatingCashFlow > data.NetIncome, ...
    sprintf('OCF %.0fM vs NI %.0fM', data.OperatingCashFlow/1e6, data.NetIncome/1e6));
c{end+1} = makeCheck('Positiv omsättningstillväxt (YoY)', data.QuarterlyRevenueGrowth > 0, sprintf('%.2f%%', data.QuarterlyRevenueGrowth));
c{end+1} = makeCheck('Positiv vinsttillväxt (YoY)', data.QuarterlyEarningsGrowth > 0, sprintf('%.2f%%', data.QuarterlyEarningsGrowth));
c{end+1} = makeCheck('Sund kortfristig likviditet (Current Ratio > 1)', data.CurrentRatio > 1, sprintf('%.2f', data.CurrentRatio));
c{end+1} = makeCheck('Måttlig skuldsättning (Debt/Equity < riktvärde)', data.DebtToEquity < bm.DebtToEquity, sprintf('%.1f%%', data.DebtToEquity));

health = struct();
health.Checks = c;
passed = 0;
for i = 1:numel(c)
    if c{i}.pass
        passed = passed + 1;
    end
end
health.PassedCount = passed;
health.TotalCount = numel(c);
health.Score = passed / numel(c) * 100;

end


function chk = makeCheck(desc, cond, note)
chk = struct('desc',desc,'pass',logical(cond),'note',note);
end


function s = formatMoneyLocal(v)
if isnan(v)
    s = 'N/A';
elseif abs(v) >= 1e9
    s = sprintf('%.2fB', v/1e9);
elseif abs(v) >= 1e6
    s = sprintf('%.2fM', v/1e6);
else
    s = sprintf('%.2f', v);
end
end

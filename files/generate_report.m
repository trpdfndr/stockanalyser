function generate_report(ticker, data, derived, val, health, risk, result)
%GENERATE_REPORT Skriver ut en fullständig textrapport i konsollen samt
%   ritar upp värderingstrend- och poängdiagram.

fprintf('\n=====================================================\n');
fprintf('   AKTIEANALYS: %s\n', ticker);
fprintf('=====================================================\n\n');

fprintf('--- 1. HÄRLEDDA GRUNDDATA ---\n');
fprintf('Härlett aktiepris (Market Cap / Aktier):  %.2f\n', derived.ImpliedPrice);
fprintf('Härledda totala tillgångar (NI / ROA):     %s\n', formatMoneyR(derived.ImpliedTotalAssets));
if ~isnan(derived.GrahamNumber)
    if derived.ImpliedPrice > derived.GrahamNumber
        grahamNote = 'PRIS ÖVER Grahamtalet (konservativt "dyrt")';
    else
        grahamNote = 'Pris under Grahamtalet (konservativt "billigt")';
    end
    fprintf('Grahamtal (Graham, "The Intelligent Investor"): %.2f -> %s\n', derived.GrahamNumber, grahamNote);
else
    fprintf('Grahamtal: kan ej beräknas (kräver positiv EPS och bokfört värde)\n');
end
fprintf('Implicit förväntad EPS-tillväxt (Trailing/Forward P/E-kvot): %.1f%%\n', derived.ImpliedEPSGrowthPct);
fprintf('Nettoskuld (Enterprise Value - Market Cap): %s\n', formatMoneyR(derived.NetDebt));
fprintf('Skuldsättningsmultiplikator (Assets/Equity, DuPont): %.2fx\n', derived.EquityMultiplier);
fprintf('Kapitalomsättningshastighet (Revenue/Assets, DuPont): %.2fx\n', derived.AssetTurnover);
fprintf('Utdelningstäckning - fritt kassaflöde: %.2fx  |  vinstbaserad: %.2fx\n', ...
    derived.DividendCoverageFCF, derived.DividendCoverageNI);

fprintf('\n--- 2. VÄRDERING ---\n');
fields = fieldnames(val.Comparison);
for i = 1:numel(fields)
    c = val.Comparison.(fields{i});
    fprintf('%-14s: %8.2f  (riktvärde %6.2f, avvikelse %+6.1f%%, poäng %5.1f/100)\n', ...
        fields{i}, c.value, c.benchmark, c.pctDiff, c.score);
end
fprintf('Sammanvägd värderingspoäng: %.1f/100  (100 = billig, 0 = dyr, mot generiska riktvärden)\n', val.ValuationScore);

fprintf('\nTrend över tid (multipel-expansion/kompression, %d perioder):\n', numel(data.PeriodLabels));
tfNames = fieldnames(val.Trends);
for i = 1:numel(tfNames)
    t = val.Trends.(tfNames{i});
    fprintf('  %-14s: %s (R^2=%.2f)\n', tfNames{i}, t.direction, t.r2);
end

fprintf('\n--- 3. FINANSIELL HÄLSA (Piotroski-inspirerad delpoäng) ---\n');
for i = 1:numel(health.Checks)
    chk = health.Checks{i};
    if chk.pass
        mark = '[OK]     ';
    else
        mark = '[VARNING]';
    end
    fprintf('%s %-52s (%s)\n', mark, chk.desc, chk.note);
end
fprintf('Poäng: %d av %d kriterier uppfyllda (%.0f%%)\n', health.PassedCount, health.TotalCount, health.Score);

fprintf('\n--- 4. RISK ---\n');
fprintf('Beta (5 år, månadsvis): %.2f\n', risk.Beta);
fprintf('CAPM förväntad avkastning: %.1f%%  |  Faktisk 52v-avkastning: %.1f%%  |  Alpha-gap: %+.1f%%\n', ...
    risk.CAPM_ExpectedReturn, risk.ActualReturn, risk.CAPM_Alpha);
if ~isnan(risk.PositionIn52wRange)
    fprintf('Position i 52-veckorsintervall: %.1f%%  (0%%=årslägsta, 100%%=årshögsta)\n', risk.PositionIn52wRange);
end
if ~isnan(risk.PctFromMA50)
    fprintf('Avvikelse fran MA50: %+.1f%%   MA200: %+.1f%%\n', risk.PctFromMA50, risk.PctFromMA200);
end
fprintf('Likviditetsrisk (Current Ratio %.2f): %s\n', risk.CurrentRatio, flagText(risk.LiquidityFlag,'FÖRHÖJD','normal'));
fprintf('Skuldsättningsrisk (Debt/Equity %.1f%%): %s\n', risk.DebtToEquity, flagText(risk.LeverageFlag,'FÖRHÖJD','normal'));
fprintf('Utdelningsrisk (Payout Ratio %.1f%% av vinst): %s\n', risk.PayoutRatioEarnings, flagText(risk.DividendRiskFlag,'EJ TÄCKT AV VINST','täckt av vinst'));
fprintf('  -> Täckningsgrad via fritt kassaflöde istället: %.2fx\n', risk.DividendCoverageFCF);
fprintf('Blankningsintresse (%.1f%% av floaten, short ratio %.1f dagar): %s\n', ...
    risk.ShortPctFloat, risk.ShortRatio, flagText(risk.ShortInterestFlag,'FÖRHÖJT','normalt'));
fprintf('Sammanvägd riskpoäng: %.1f/100  ->  Risknivå: %s\n', risk.RiskScore, result.RiskLevel);

fprintf('\n--- 5. SAMMANFATTANDE BEDÖMNING ---\n');
fprintf('Värderingspoäng (vikt %.0f%%): %5.1f/100\n', result.Weights.valuation*100, val.ValuationScore);
fprintf('Hälsopoäng      (vikt %.0f%%): %5.1f/100\n', result.Weights.health*100, health.Score);
fprintf('Säkerhetspoäng  (vikt %.0f%%): %5.1f/100\n', result.Weights.safety*100, 100-risk.RiskScore);
fprintf('Momentumpoäng   (vikt %.0f%%): %5.1f/100\n', result.Weights.momentum*100, result.MomentumScore);
fprintf('-----------------------------------------------\n');
fprintf('TOTAL POÄNG: %.1f/100\n', result.CompositeScore);
fprintf('REKOMMENDATION (heuristisk modell): %s\n', result.Recommendation);
fprintf('RISKNIVÅ: %s\n', result.RiskLevel);
fprintf('=====================================================\n');
fprintf('OBS: Detta är en kvantitativ heuristik byggd på vedertagna\n');
fprintf('tumregler (Graham, Lynch, Piotroski, CAPM/Sharpe, Damodaran-\n');
fprintf('multiplar). Det är INTE finansiell rådgivning och bör INTE\n');
fprintf('ensamt ligga till grund for investeringsbeslut. Modellen saknar\n');
fprintf('kontext om bransch, konkurrens, ledning, makroekonomi m.m.\n');
fprintf('=====================================================\n\n');

plotValuationTrends(data);
plotScoreBreakdown(val, health, risk, result);

end


function plotValuationTrends(data)
figure('Name','Värderingstrend över tid');
metrics = {'TrailingPE','ForwardPE','EV_EBITDA'};
n = numel(data.PeriodLabels);
xChron = 1:n;
labelsChron = fliplr(data.PeriodLabels);
for i = 1:numel(metrics)
    subplot(numel(metrics),1,i);
    y = data.(metrics{i});
    yChron = fliplr(y);
    plot(xChron, yChron, '-o', 'LineWidth',1.5);
    set(gca,'XTick',xChron,'XTickLabel',labelsChron);
    xtickangle(45);
    title(strrep(metrics{i},'_','/'));
    grid on;
end
sgtitle('Utveckling av värderingsmultiplar över tid (äldst -> nuvarande)');
end


function plotScoreBreakdown(val, health, risk, result)
figure('Name','Poängsammanfattning');
cats = {'Värdering','Hälsa','Säkerhet','Momentum'};
scoreVals = [val.ValuationScore, health.Score, 100-risk.RiskScore, result.MomentumScore];
bar(scoreVals);
set(gca,'XTickLabel',cats);
ylim([0 100]);
yline(50,'--','Neutral');
ylabel('Poäng (0-100)');
title(sprintf('Total poäng: %.1f/100 - %s', result.CompositeScore, result.Recommendation));
grid on;
end


function s = formatMoneyR(v)
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


function s = flagText(flag, ifTrue, ifFalse)
if flag
    s = ifTrue;
else
    s = ifFalse;
end
end

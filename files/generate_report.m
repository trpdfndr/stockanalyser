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

fprintf('\n--- 2. VÄRDERING (dynamisk, fundamentalt justerad) ---\n');
fprintf('Sektortyp: %s   (styr vikten för P/B och EV/EBITDA - se config_benchmarks.m)\n', val.SectorType);
if val.PeerDataUsed
    fprintf('Peer-/konkurrentdata: användes i blandningen där tillgängligt.\n');
else
    fprintf('Peer-/konkurrentdata: ej tillhandahållet (lägg till data.PeerMedian.<mått> för att aktivera).\n');
end
fprintf('\n');

names = {'TrailingPE','ForwardPE','PEGRatio','PriceToSales','PriceToBook','EV_EBITDA'};
for i = 1:numel(names)
    d = val.Details.(names{i});
    if ~d.meaningful
        fprintf('%-14s: %8.2f   [EJ MENINGSFULLT - %s]\n', names{i}, d.value, d.reason);
        continue;
    end
    fprintf('%-14s: %8.2f  ->  dynamiskt riktvärde %7.2f  (avvikelse %+6.1f%%, poäng %5.1f/100)\n', ...
        names{i}, d.value, d.blendedBenchmark, d.pctDiffVsBlended, d.score);
    fprintf('%16s justeringar: tillväxt x%.2f | kvalitet(ROE) x%.2f | skuldsättning x%.2f | marginal x%.2f | historiskt median: %s | peer-median: %s\n', ...
        ' ', d.adjustments.growth, d.adjustments.quality, d.adjustments.leverage, d.adjustments.margin, ...
        formatNaNOrNum(d.historicalMedian), formatNaNOrNum(d.peerMedian));
end

fprintf('\nGruppoäng (relaterade mått vägs ihop för att undvika dubbelräkning):\n');
fprintf('  Vinstvärdering   (P/E-familjen, vikt %4.1f%%): %s/100  %s\n', ...
    val.Groups.Weights.Earnings*100, formatNaNOrNum(val.Groups.Earnings), val.Groups.EarningsNote);
fprintf('  Omsättningsvärd. (P/S,         vikt %4.1f%%): %s/100\n', val.Groups.Weights.Sales*100, formatNaNOrNum(val.Groups.Sales));
fprintf('  Tillgångsvärd.   (P/B,         vikt %4.1f%%): %s/100\n', val.Groups.Weights.Asset*100, formatNaNOrNum(val.Groups.Asset));
fprintf('  Företagsvärd.    (EV/EBITDA,   vikt %4.1f%%): %s/100\n', val.Groups.Weights.Enterprise*100, formatNaNOrNum(val.Groups.Enterprise));
fprintf('Sammanvägd värderingspoäng: %.1f/100  (100 = billig, 0 = dyr, relativt dynamiskt riktvärde)\n', val.ValuationScore);

fprintf('\nTrend över tid (regression) samt pris- vs fundamentaldriven tolkning:\n');
tfNames = fieldnames(val.Trends);
for i = 1:numel(tfNames)
    t = val.Trends.(tfNames{i});
    fprintf('  %-14s: %s (R^2=%.2f)\n', tfNames{i}, t.direction, t.r2);
    fprintf('  %14s  -> %s\n', '', t.driverNote);
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
fprintf('tumregler och en dynamisk, fundamentalt justerad värderings-\n');
fprintf('modell (Graham, Lynch, Piotroski, CAPM/Sharpe, Damodaran).\n');
fprintf('Det är INTE finansiell rådgivning och bör INTE ensamt ligga\n');
fprintf('till grund for investeringsbeslut. Modellen saknar kontext om\n');
fprintf('konkurrenter (om ej manuellt tillagt), ledning, makroekonomi m.m.\n');
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


function s = formatNaNOrNum(v)
if isnan(v)
    s = 'N/A';
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

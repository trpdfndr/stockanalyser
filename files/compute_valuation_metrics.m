function val = compute_valuation_metrics(data, bm)
%COMPUTE_VALUATION_METRICS Dynamisk värderingsanalys.
%
%   Istället för att bara jämföra en multipel mot ett fast generiskt tal
%   gör denna version följande för varje mått (P/E, Forward P/E, PEG,
%   P/S, P/B, EV/EBITDA):
%     1) Kontrollerar om måttet ens är meningsfullt (negativ/extrem vinst
%        flaggas istället för att tvingas in i en poäng).
%     2) Räknar ut ett fundamentalt justerat riktvärde utifrån bolagets
%        egen tillväxt, lönsamhet (ROE) och skuldsättning, med mjukt
%        dämpade (icke-linjära) justeringsfaktorer.
%     3) Blandar detta med bolagets egen historiska median och ett
%        valfritt peer-/konkurrentmedianvärde (data.PeerMedian.<mått>).
%     4) Omvandlar avvikelsen fran det blandade riktvärdet till en
%        icke-linjär (logistisk) poäng som mättar istället för att
%        träffa hårt 0/100.
%   Slutligen grupperas relaterade mått (P/E-familjen) ihop innan de
%   vägs samman, för att undvika dubbelräkning.
%
%   Se README.md för fullständig metodbeskrivning och källor.

val = struct();
n = numel(data.PeriodLabels);
xChron = 1:n; % 1 = äldst, n = Current (kronologisk ordning)

% --- Utvärdera varje mått individuellt ---------------------------------
val.Details = struct();
val.Details.TrailingPE   = evaluateMetric('TrailingPE',   data, bm, 'earnings');
val.Details.ForwardPE    = evaluateMetric('ForwardPE',    data, bm, 'earnings');
val.Details.PEGRatio     = evaluateMetric('PEGRatio',     data, bm, 'peg');
val.Details.PriceToSales = evaluateMetric('PriceToSales', data, bm, 'sales');
val.Details.PriceToBook  = evaluateMetric('PriceToBook',  data, bm, 'asset');
val.Details.EV_EBITDA    = evaluateMetric('EV_EBITDA',    data, bm, 'enterprise');

val.PeerDataUsed = false;
dn = fieldnames(val.Details);
for i = 1:numel(dn)
    if ~isnan(val.Details.(dn{i}).peerMedian)
        val.PeerDataUsed = true;
    end
end
val.SectorType = bm.SectorType;

% --- Gruppera relaterade mått (undvik dubbelräkning) --------------------
fwd   = val.Details.ForwardPE;
peg   = val.Details.PEGRatio;
trail = val.Details.TrailingPE;

earningsScore = weightedMeanIgnoringNaN([fwd.score, peg.score], [0.5 0.5]);
earningsNote = '';
if isnan(earningsScore) && trail.meaningful
    earningsScore = trail.score;
    earningsNote = '(baserat på Trailing P/E - Forward P/E/PEG saknades eller var ej meningsfulla)';
end

sales = val.Details.PriceToSales;
asset = val.Details.PriceToBook;
ent   = val.Details.EV_EBITDA;

gw = applySectorWeights(bm);

val.Groups = struct();
val.Groups.Earnings = earningsScore;
val.Groups.Sales = sales.score;
val.Groups.Asset = asset.score;
val.Groups.Enterprise = ent.score;
val.Groups.Weights = gw;
val.Groups.EarningsNote = earningsNote;

groupScores  = [val.Groups.Earnings, val.Groups.Sales, val.Groups.Asset, val.Groups.Enterprise];
groupWeights = [gw.Earnings, gw.Sales, gw.Asset, gw.Enterprise];
val.ValuationScore = weightedMeanIgnoringNaN(groupScores, groupWeights);

% --- Trend över tid + pris- vs fundamentaldriven tolkning ---------------
metricsToTrend = {'TrailingPE','ForwardPE','EV_EBITDA','PriceToSales','PriceToBook','PEGRatio'};
driverField = containers.Map(metricsToTrend, ...
    {'MarketCap','MarketCap','EnterpriseValue','MarketCap','MarketCap','MarketCap'});

val.Trends = struct();
for i = 1:numel(metricsToTrend)
    name = metricsToTrend{i};
    if ~isfield(data,name)
        continue;
    end
    y = data.(name);
    m = min(numel(xChron), numel(y));
    xi = xChron(1:m);
    yi = fliplr(y(1:m)); % "Current" lagras först -> vänd till kronologisk ordning

    valid = ~isnan(yi);
    trend = struct('slope',NaN,'r2',NaN,'direction','otillräcklig data', ...
                    'driverName','','driverChangePct',NaN,'driverNote','');
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
            trend.direction = 'fallande multipel';
        elseif p(1) > 1e-6
            trend.direction = 'stigande multipel';
        else
            trend.direction = 'stabil multipel';
        end
    end

    multipleChangePct = totalPctChange(y);
    driverName = driverField(name);
    if isfield(data, driverName)
        driverChangePct = totalPctChange(data.(driverName));
    else
        driverChangePct = NaN;
    end
    trend.driverName = driverName;
    trend.driverChangePct = driverChangePct;
    trend.driverNote = classifyDriver(multipleChangePct, driverChangePct);

    val.Trends.(name) = trend;
end

end


% =========================================================================
% Lokala hjälpfunktioner
% =========================================================================

function detail = evaluateMetric(name, data, bm, kind)
detail = struct();
value = getCurrentValue(data, name);
detail.value = value;
detail.meaningful = true;
detail.reason = '';

switch name
    case 'TrailingPE'
        if isnan(value) || value <= 0
            detail.meaningful = false; detail.reason = 'Negativ eller saknad vinst (P/E ej meningsfullt)';
        elseif value > bm.NotMeaningful.MaxPE
            detail.meaningful = false; detail.reason = sprintf('Extremt högt P/E (>%.0f), troligen kraftigt tillfälligt deprimerad vinst', bm.NotMeaningful.MaxPE);
        end
    case 'ForwardPE'
        if isnan(value) || value <= 0
            detail.meaningful = false; detail.reason = 'Negativ eller saknad förväntad vinst';
        elseif value > bm.NotMeaningful.MaxPE
            detail.meaningful = false; detail.reason = sprintf('Extremt högt Forward P/E (>%.0f)', bm.NotMeaningful.MaxPE);
        end
    case 'EV_EBITDA'
        if isnan(value) || value <= 0 || (hasNum(data,'EBITDA') && data.EBITDA <= 0)
            detail.meaningful = false; detail.reason = 'Negativ eller saknad EBITDA';
        end
    case 'PriceToBook'
        if isnan(value) || value <= 0
            detail.meaningful = false; detail.reason = 'Negativt eller saknat bokfört värde (eget kapital)';
        end
    case 'PriceToSales'
        if isnan(value) || value <= 0
            detail.meaningful = false; detail.reason = 'Saknat värde';
        end
    case 'PEGRatio'
        if isnan(value) || value <= 0
            detail.meaningful = false; detail.reason = 'Saknat eller negativt PEG-tal';
        end
end

% Egen historik (perioder 2:end = tidigare kvartal, exkl. "Current")
hist = [];
if isfield(data,name)
    v = data.(name);
    if numel(v) >= 2
        hist = v(2:end);
    end
end
hist = hist(~isnan(hist));
if numel(hist) >= 2
    detail.historicalMedian = median(hist);
else
    detail.historicalMedian = NaN;
end

% Peer-/konkurrentmedian (valfritt, manuellt tillagt av användaren)
detail.peerMedian = NaN;
if isfield(data,'PeerMedian') && isfield(data.PeerMedian, name)
    pm = data.PeerMedian.(name);
    if ~isnan(pm) && pm > 0
        detail.peerMedian = pm;
    end
end

% Fundamental justering av det generiska basvärdet
generic = bm.Generic.(name);
adj = struct('growth',1,'quality',1,'leverage',1,'margin',1);
switch kind
    case 'earnings'
        g = safeGet(data,'QuarterlyEarningsGrowth');
        adj.growth = smoothAdj(g, bm.Adjust.GrowthCenter, bm.Adjust.GrowthSpread, bm.Adjust.GrowthK);
        roe = safeGet(data,'ReturnOnEquity');
        adj.quality = smoothAdj(roe, bm.Adjust.QualityCenterROE, bm.Adjust.QualitySpread, bm.Adjust.QualityK);
        de = safeGet(data,'DebtToEquity');
        adj.leverage = smoothAdjInverse(de, bm.Adjust.LeverageCenterDE, bm.Adjust.LeverageSpread, bm.Adjust.LeverageK);
    case 'enterprise'
        g = safeGet(data,'QuarterlyEarningsGrowth');
        adj.growth = smoothAdj(g, bm.Adjust.GrowthCenter, bm.Adjust.GrowthSpread, bm.Adjust.GrowthK);
        roe = safeGet(data,'ReturnOnEquity');
        adj.quality = smoothAdj(roe, bm.Adjust.QualityCenterROE, bm.Adjust.QualitySpread, bm.Adjust.QualityK);
        de = safeGet(data,'DebtToEquity');
        adj.leverage = smoothAdjInverse(de, bm.Adjust.LeverageCenterDE, bm.Adjust.LeverageSpread, bm.Adjust.LeverageK);
    case 'sales'
        mgn = safeGet(data,'ProfitMargin');
        adj.margin = smoothAdj(mgn, bm.Adjust.MarginCenter, bm.Adjust.MarginSpread, bm.Adjust.MarginK);
        g = safeGet(data,'QuarterlyRevenueGrowth');
        adj.growth = smoothAdj(g, bm.Adjust.GrowthCenter, bm.Adjust.GrowthSpread, bm.Adjust.GrowthK);
    case 'asset'
        roe = safeGet(data,'ReturnOnEquity');
        adj.quality = smoothAdj(roe, bm.Adjust.QualityCenterROE, bm.Adjust.QualitySpread, bm.Adjust.QualityK);
    case 'peg'
        % Ingen justering - PEG är redan tillväxtnormaliserat per definition.
end
detail.adjustments = adj;
detail.fundamentalBenchmark = generic * adj.growth * adj.quality * adj.leverage * adj.margin;

% Blanda generiskt(fundamentalt justerat) / historiskt / peer
w = bm.BlendWeights;
useHist = ~isnan(detail.historicalMedian);
usePeer = ~isnan(detail.peerMedian);
wG = w.Generic;
wH = 0; if useHist, wH = w.Historical; end
wP = 0; if usePeer, wP = w.Peer; end
wSum = wG + wH + wP;

histTerm = 0; if useHist, histTerm = detail.historicalMedian; end
peerTerm = 0; if usePeer, peerTerm = detail.peerMedian; end
detail.blendedBenchmark = (wG*detail.fundamentalBenchmark + wH*histTerm + wP*peerTerm) / wSum;

% Poäng
if ~detail.meaningful || isnan(value)
    detail.score = NaN;
    detail.pctDiffVsBlended = NaN;
else
    detail.pctDiffVsBlended = (value/detail.blendedBenchmark - 1) * 100;
    if strcmp(name,'PEGRatio')
        detail.score = pegBandScore(value);
    else
        detail.score = logisticScore(value, detail.blendedBenchmark);
    end
end

end


function gw = applySectorWeights(bm)
gw = bm.GroupWeights;
switch bm.SectorType
    case 'asset_light'
        gw.Asset = gw.Asset * 0.4;
    case 'asset_heavy'
        gw.Asset = gw.Asset * 1.8;
        gw.Enterprise = gw.Enterprise * 0.8;
    case 'financial'
        gw.Asset = gw.Asset * 2.2;
        gw.Enterprise = gw.Enterprise * 0.3;
        gw.Sales = gw.Sales * 0.5;
end
total = gw.Earnings + gw.Sales + gw.Asset + gw.Enterprise;
gw.Earnings   = gw.Earnings/total;
gw.Sales      = gw.Sales/total;
gw.Asset      = gw.Asset/total;
gw.Enterprise = gw.Enterprise/total;
end


function y = smoothAdj(x, center, spread, k)
% Mjuk, mättande justeringsfaktor: exp(k*atan((x-center)/spread)).
% Bunden (aldrig extrem) - dämpar effekten av ovanligt hög/låg tillväxt
% eller lönsamhet istället för att linjärt trissa upp riktvärdet.
if isnan(x)
    x = center;
end
y = exp(k * atan((x-center)/spread));
end


function y = smoothAdjInverse(x, center, spread, k)
% Som smoothAdj men med omvänt tecken - används där ett HÖGRE x-värde
% (t.ex. skuldsättning) bör SÄNKA det rimliga riktvärdet.
if isnan(x)
    x = center;
end
y = exp(-k * atan((x-center)/spread));
end


function s = logisticScore(value, benchmark)
% Icke-linjär poäng baserad på log-avvikelsen fran det blandade
% riktvärdet. Mättar mot ~10 respektive ~90 istället för att träffa
% hårt 0/100 vid stora avvikelser.
if isnan(value) || isnan(benchmark) || value <= 0 || benchmark <= 0
    s = NaN;
    return;
end
r = log(value/benchmark) / log(2);
s = 50 - 40*tanh(r);
end


function s = pegBandScore(peg)
% PEG bedöms via ett bandat, tumregelsbaserat intervall (Lynch-inspirerat)
% snarare än den generella logistiska funktionen, eftersom PEG redan är
% tillväxtnormaliserat.
if isnan(peg) || peg <= 0
    s = NaN;
    return;
end
xs = [0.5 1.0 1.3 1.7 2.2 3.0];
ys = [90  80  65  45  25  10];
if peg <= xs(1)
    s = ys(1);
elseif peg >= xs(end)
    s = ys(end);
else
    s = interp1(xs, ys, peg, 'linear');
end
end


function pct = totalPctChange(v)
v = v(~isnan(v));
if numel(v) < 2
    pct = NaN;
    return;
end
vChron = fliplr(v);
first = vChron(1);
last = vChron(end);
if first == 0
    pct = NaN;
    return;
end
pct = (last-first)/abs(first) * 100;
end


function note = classifyDriver(multipleChangePct, driverChangePct)
% Grov heuristik för att skilja prisdriven fran fundamentalt driven
% multipelförändring, genom att jämföra multipelns totala förändring med
% förändringen i dess "pris-drivare" (Market Cap eller Enterprise Value).
if isnan(multipleChangePct) || isnan(driverChangePct)
    note = 'otillräcklig data för att skilja pris- fran fundamentaldriven förändring';
    return;
end
sameDirection = (sign(multipleChangePct) == sign(driverChangePct)) && abs(driverChangePct) > 2;
if sameDirection
    note = sprintf('sannolikt prisdrivet (Market Cap/EV förändrades %+.0f%% i samma riktning som multipeln)', driverChangePct);
elseif abs(driverChangePct) <= 2
    note = sprintf('sannolikt fundamentalt drivet (Market Cap/EV i stort sett oförändrat, %+.0f%%) - nämnaren (vinst/EBITDA) har sannolikt förändrats', driverChangePct);
else
    note = sprintf('blandad bild: Market Cap/EV förändrades %+.0f%% i motsatt riktning mot multipeln - nämnaren har sannolikt förändrats mer', driverChangePct);
end
end


function v = getCurrentValue(data, name)
if isfield(data,name) && ~isempty(data.(name))
    v = data.(name)(1);
else
    v = NaN;
end
end


function v = safeGet(data, name)
if isfield(data,name) && ~isempty(data.(name)) && ~isnan(data.(name)(1))
    v = data.(name)(1);
else
    v = NaN;
end
end


function tf = hasNum(data, name)
tf = isfield(data,name) && ~isempty(data.(name)) && ~isnan(data.(name)(1));
end


function s = weightedMeanIgnoringNaN(scores, weights)
valid = ~isnan(scores);
if ~any(valid)
    s = NaN;
    return;
end
s = sum(scores(valid).*weights(valid)) / sum(weights(valid));
end

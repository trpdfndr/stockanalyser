function derived = compute_derived_fundamentals(data)
%COMPUTE_DERIVED_FUNDAMENTALS Räknar fram nyckeltal som inte finns direkt
%   i Yahoo-datan men som kan härledas algebraiskt fran rapporterade mått.

derived = struct();

% --- Härlett aktiepris: Pris = Market Cap / Utestående aktier -----------
if hasNumericField(data,'MarketCap') && hasNumericField(data,'SharesOutstanding') && data.SharesOutstanding ~= 0
    derived.ImpliedPrice = data.MarketCap(1) / data.SharesOutstanding;
else
    derived.ImpliedPrice = NaN;
end

% --- Härledda totala tillgångar via ROA = NettoVinst / TotalaTillgångar -
if hasNumericField(data,'NetIncome') && hasNumericField(data,'ReturnOnAssets') && data.ReturnOnAssets ~= 0
    derived.ImpliedTotalAssets = data.NetIncome / (data.ReturnOnAssets/100);
else
    derived.ImpliedTotalAssets = NaN;
end

% --- DuPont-identitet: ROE = Nettomarginal x Omsättningshastighet x -----
%     Skuldsättningsmultiplikator (Assets/Equity)
if hasNumericField(data,'ReturnOnEquity') && hasNumericField(data,'ReturnOnAssets') && data.ReturnOnAssets ~= 0
    derived.EquityMultiplier = data.ReturnOnEquity / data.ReturnOnAssets;
else
    derived.EquityMultiplier = NaN;
end
if hasNumericField(data,'ReturnOnAssets') && hasNumericField(data,'ProfitMargin') && data.ProfitMargin ~= 0
    derived.AssetTurnover = (data.ReturnOnAssets/100) / (data.ProfitMargin/100);
else
    derived.AssetTurnover = NaN;
end

% --- Grahamtal (Benjamin Graham): sqrt(22.5 x EPS x Bokfört värde/aktie)
if hasNumericField(data,'DilutedEPS') && hasNumericField(data,'BookValuePerShare') ...
        && data.DilutedEPS > 0 && data.BookValuePerShare > 0
    derived.GrahamNumber = sqrt(22.5 * data.DilutedEPS * data.BookValuePerShare);
else
    derived.GrahamNumber = NaN;
end

% --- Implicit förväntad EPS-tillväxt via P/E-kvoterna -------------------
% ForwardPE = Pris/ForwardEPS, TrailingPE = Pris/TrailingEPS
% => ForwardEPS/TrailingEPS = TrailingPE/ForwardPE
if hasNumericField(data,'TrailingPE') && hasNumericField(data,'ForwardPE') && data.ForwardPE(1) ~= 0
    derived.ImpliedEPSGrowthRatio = data.TrailingPE(1) / data.ForwardPE(1);
    derived.ImpliedEPSGrowthPct   = (derived.ImpliedEPSGrowthRatio - 1) * 100;
else
    derived.ImpliedEPSGrowthRatio = NaN;
    derived.ImpliedEPSGrowthPct   = NaN;
end

% --- Nettoskuld: Enterprise Value - Market Cap --------------------------
if hasNumericField(data,'EnterpriseValue') && hasNumericField(data,'MarketCap')
    derived.NetDebt = data.EnterpriseValue(1) - data.MarketCap(1);
else
    derived.NetDebt = NaN;
end

% --- Utdelningens täckningsgrad ------------------------------------------
if hasNumericField(data,'ForwardDividendRate') && hasNumericField(data,'SharesOutstanding')
    derived.TotalDividendObligation = data.ForwardDividendRate * data.SharesOutstanding;
else
    derived.TotalDividendObligation = NaN;
end

if ~isnan(derived.TotalDividendObligation) && derived.TotalDividendObligation ~= 0 && hasNumericField(data,'LeveredFCF')
    derived.DividendCoverageFCF = data.LeveredFCF / derived.TotalDividendObligation;
else
    derived.DividendCoverageFCF = NaN;
end

if ~isnan(derived.TotalDividendObligation) && derived.TotalDividendObligation ~= 0 && hasNumericField(data,'NetIncome')
    derived.DividendCoverageNI = data.NetIncome / derived.TotalDividendObligation;
else
    derived.DividendCoverageNI = NaN;
end

end


function tf = hasNumericField(s, name)
tf = isfield(s,name) && ~isempty(s.(name)) && any(~isnan(s.(name)));
end

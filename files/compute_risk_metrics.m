function risk = compute_risk_metrics(data, derived, bm)
%COMPUTE_RISK_METRICS Marknads-, likviditets-, skuldsättnings-,
%   utdelnings- och sentimentrisk, samt en enkel CAPM-baserad
%   avkastningsjämförelse.

risk = struct();

% --- Marknadsrisk (Beta + CAPM) ------------------------------------------
risk.Beta = data.Beta;
Rf = bm.RiskFreeRate;
if hasField(data,'SP500Change52Week') && ~isnan(data.SP500Change52Week)
    Rm = data.SP500Change52Week;
else
    Rm = bm.MarketReturnDefault;
end
risk.CAPM_ExpectedReturn = Rf + data.Beta * (Rm - Rf);
risk.ActualReturn = data.Change52Week;
risk.CAPM_Alpha = risk.ActualReturn - risk.CAPM_ExpectedReturn;

% --- Prisposition i 52-veckorsintervallet (förinitierat till NaN) --------
price = derived.ImpliedPrice;
risk.ImpliedPrice = price;
risk.PositionIn52wRange = NaN;
risk.PctFromHigh = NaN;
risk.PctFromLow  = NaN;
risk.PctFromMA50 = NaN;
risk.PctFromMA200 = NaN;

if ~isnan(price) && hasField(data,'High52Week') && hasField(data,'Low52Week') ...
        && (data.High52Week - data.Low52Week) ~= 0
    risk.PositionIn52wRange = (price - data.Low52Week) / (data.High52Week - data.Low52Week) * 100;
    risk.PctFromHigh = (price/data.High52Week - 1) * 100;
    risk.PctFromLow  = (price/data.Low52Week  - 1) * 100;
end
if ~isnan(price) && hasField(data,'MA50') && data.MA50 ~= 0
    risk.PctFromMA50 = (price/data.MA50 - 1) * 100;
end
if ~isnan(price) && hasField(data,'MA200') && data.MA200 ~= 0
    risk.PctFromMA200 = (price/data.MA200 - 1) * 100;
end

% --- Likviditetsrisk -------------------------------------------------------
risk.CurrentRatio = data.CurrentRatio;
risk.LiquidityFlag = data.CurrentRatio < 1;

% --- Skuldsättningsrisk -----------------------------------------------------
risk.DebtToEquity = data.DebtToEquity;
risk.NetDebt = derived.NetDebt;
risk.LeverageFlag = data.DebtToEquity > bm.DebtToEquity;

% --- Utdelningshållbarhet ----------------------------------------------------
risk.PayoutRatioEarnings = data.PayoutRatio;
risk.DividendCoverageFCF = derived.DividendCoverageFCF;
risk.DividendCoverageNI  = derived.DividendCoverageNI;
risk.DividendRiskFlag = data.PayoutRatio > 100;

% --- Blankningsstatistik (sentimentindikator) ---------------------------------
risk.ShortPctFloat = data.ShortPctFloat;
risk.ShortRatio = data.ShortRatio;
risk.ShortInterestFlag = data.ShortPctFloat > 10;

% --- Sammanvägd riskpoäng 0-100 (100 = mycket hög risk) -----------------------
flags = [risk.LiquidityFlag, risk.LeverageFlag, risk.DividendRiskFlag, risk.ShortInterestFlag, (data.Beta > 1.3)];
baseRisk = mean(double(flags)) * 100;
alphaAdj = max(0, -risk.CAPM_Alpha) * 0.3;
risk.RiskScore = min(100, baseRisk*0.7 + alphaAdj);

end


function tf = hasField(s, name)
tf = isfield(s,name) && ~isempty(s.(name));
end

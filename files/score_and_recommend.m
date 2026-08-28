function result = score_and_recommend(val, health, risk, derived)
%SCORE_AND_RECOMMEND Väger samman värdering, hälsa, risk och momentum till
%   en samlad poäng (0-100) och en heuristisk köp/sälj-rekommendation.

result = struct();
safety = 100 - risk.RiskScore;

if isfield(risk,'PctFromMA200') && ~isnan(risk.PctFromMA200)
    momentum = 50 + max(-50, min(50, risk.PctFromMA200 * 2));
else
    momentum = 50;
end
result.MomentumScore = momentum;

weights = struct('valuation',0.30, 'health',0.25, 'safety',0.25, 'momentum',0.20);
result.Weights = weights;

composite = weights.valuation * val.ValuationScore + ...
            weights.health    * health.Score + ...
            weights.safety    * safety + ...
            weights.momentum  * momentum;
result.CompositeScore = composite;

if composite >= 70
    rec = 'KÖP (Buy)';
elseif composite >= 55
    rec = 'SVAGT KÖP / BEVAKA (Hold-Buy)';
elseif composite >= 40
    rec = 'HÅLL (Hold)';
elseif composite >= 25
    rec = 'SVAGT SÄLJ / MINSKA (Reduce)';
else
    rec = 'SÄLJ (Sell)';
end
result.Recommendation = rec;

if risk.RiskScore >= 70
    riskLevel = 'MYCKET HÖG';
elseif risk.RiskScore >= 50
    riskLevel = 'HÖG';
elseif risk.RiskScore >= 30
    riskLevel = 'MÅTTLIG';
else
    riskLevel = 'LÅG';
end
result.RiskLevel = riskLevel;

end

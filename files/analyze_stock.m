function [result, val, health, risk, derived] = analyze_stock(data, ticker)
%ANALYZE_STOCK Kör hela analyskedjan pa en akties data och skriver ut en
%   fullständig rapport.
%
%   RESULT = ANALYZE_STOCK(DATA) där DATA kommer fran PARSE_YAHOO_TEXT
%   eller STOCK_DATA_TEMPLATE.
%   RESULT = ANALYZE_STOCK(DATA, TICKER) namnger aktien i rapporten.
%
%   [RESULT, VAL, HEALTH, RISK, DERIVED] = ANALYZE_STOCK(...) ger även
%   tillgang till alla delberäkningar for vidare eget bruk.

if nargin < 2
    ticker = 'OKÄND AKTIE';
end

bm = config_benchmarks();
derived = compute_derived_fundamentals(data);
val = compute_valuation_metrics(data, bm);
health = compute_financial_health(data, bm);
risk = compute_risk_metrics(data, derived, bm);
result = score_and_recommend(val, health, risk, derived);

generate_report(ticker, data, derived, val, health, risk, result);

end

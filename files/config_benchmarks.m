function bm = config_benchmarks()
%CONFIG_BENCHMARKS Generiska värderings- och riskriktvärden
%   Dessa är breda tumregler fran etablerad värderingslitteratur, INTE
%   branschspecifika snitt. Justera vid behov (t.ex. bank- och
%   fastighetsbolag kräver egna P/B- och skuldsättningsriktvärden).
%
%   Källor (se README.md för fullständig lista):
%   - Damodaran (NYU Stern): historiska multipelsnitt
%   - Lynch, "One Up On Wall Street": PEG ~ 1 tumregel
%   - Klassisk kreditanalys: Current Ratio, Debt/Equity, Payout Ratio

bm = struct();
bm.TrailingPE          = 20;
bm.ForwardPE           = 18;
bm.PEG                 = 1.0;
bm.PriceToSales        = 3;
bm.PriceToBook         = 3;
bm.EV_EBITDA           = 11;
bm.CurrentRatio        = 1.5;
bm.DebtToEquity        = 100;
bm.PayoutRatio         = 75;
bm.RiskFreeRate        = 4.5;
bm.MarketReturnDefault = 9;

end

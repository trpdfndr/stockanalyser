function data = stock_data_template()
%STOCK_DATA_TEMPLATE Exempel-/malldata i samma format som PARSE_YAHOO_TEXT
%   returnerar. Kopiera denna fil, byt namn (t.ex. stock_data_XYZ.m) och
%   ersätt värdena med en ny akties siffror om du hellre matar in data
%   direkt i MATLAB istället för att klistra in text och köra
%   PARSE_YAHOO_TEXT.
%
%   OBS: alla "%"-fält lagras som rena tal, t.ex. 10.63 betyder 10.63 %.
%   Belopp lagras i sin helhet (B = x1e9, M = x1e6).

data = struct();

data.PeriodLabels = {'Current','6/30/2026','3/31/2026','12/31/2025','9/30/2025','6/30/2025'};

% --- Valuation Measures (vektorer: [Current, sedan historik]) ----------
data.MarketCap       = [32.19 25.10 24.60 35.87 35.23 38.00] * 1e9;
data.EnterpriseValue = [46.68 39.27 38.83 48.56 48.63 51.01] * 1e9;
data.TrailingPE      = [64.22 51.29 63.80 68.20 90.85 101.29];
data.ForwardPE       = [23.53 18.21 16.67 24.88 25.51 35.46];
data.PEGRatio        = [1.32 0.91 0.83 1.17 NaN NaN];
data.PriceToSales    = [5.21 4.16 4.23 6.42 6.89 8.21];
data.PriceToBook     = [12.59 9.78 8.74 11.91 12.14 12.69];
data.EV_Revenue      = [7.69 6.65 6.93 9.07 10.07 10.81];
data.EV_EBITDA       = [20.09 17.64 16.90 21.04 24.18 24.21];

% --- Financial Highlights (skalärer, "Current"/ttm/mrq) -----------------
data.ProfitMargin            = 10.63;
data.OperatingMargin         = 19.38;
data.ReturnOnAssets          = 2.59;
data.ReturnOnEquity          = 14.94;
data.Revenue                 = 5.99e9;
data.RevenuePerShare         = 26.87;
data.QuarterlyRevenueGrowth  = 5.80;
data.GrossProfit             = 2.24e9;
data.EBITDA                  = 1.43e9;
data.NetIncome               = 572.57e6;
data.DilutedEPS              = 2.18;
data.QuarterlyEarningsGrowth = 9.90;
data.TotalCash               = 1.85e9;
data.TotalCashPerShare       = 8.14;
data.TotalDebt               = 14.87e9;
data.DebtToEquity            = 172.38;
data.CurrentRatio            = 0.54;
data.BookValuePerShare       = 11.03;
data.OperatingCashFlow       = 912.12e6;
data.LeveredFCF              = 2.16e9;

% --- Trading Information (skalärer) -------------------------------------
data.Beta                     = 1.51;
data.Change52Week             = -20.47;
data.SP500Change52Week        = 18.45;
data.High52Week               = 186.85;
data.Low52Week                = 95.80;
data.MA50                     = 128.48;
data.MA200                    = 133.60;
data.AvgVol3M                 = 2.39e6;
data.AvgVol10D                = 2.07e6;
data.SharesOutstanding        = 222.03e6;
data.ImpliedSharesOutstanding = 329.85e6;
data.Float                    = 217.84e6;
data.InsiderPct               = 11.16;
data.InstitutionPct           = 93.56;
data.SharesShort               = 14.27e6;
data.SharesShortPriorMonth     = 16.59e6;
data.ShortRatio                = 6.13;
data.ShortPctFloat             = 13.56;
data.ShortPctOutstanding       = 6.33;
data.ForwardDividendRate       = 5.4;
data.ForwardDividendYield      = 3.78;
data.TrailingDividendRate      = 4.94;
data.TrailingDividendYield     = 3.46;
data.AvgDividendYield5Y        = 2.72;
data.PayoutRatio               = 226.61;

% --- (Valfritt) Peer-/konkurrentmedian ----------------------------------
% Om du har jämförbara bolags multiplar kan du mata in medianen här -
% då vägs den in i det dynamiska riktvärdet i COMPUTE_VALUATION_METRICS.
% Avkommentera och fyll i de mått du har data för (övriga behöver inte
% anges - vikten omfördelas automatiskt om ett fält saknas):
%
% data.PeerMedian.TrailingPE   = 35;
% data.PeerMedian.ForwardPE    = 22;
% data.PeerMedian.PEGRatio     = 1.1;
% data.PeerMedian.PriceToSales = 6;
% data.PeerMedian.PriceToBook  = 10;
% data.PeerMedian.EV_EBITDA    = 18;

end

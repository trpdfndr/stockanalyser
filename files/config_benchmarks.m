function bm = config_benchmarks()
%CONFIG_BENCHMARKS Riktvärden, blandningsvikter och justeringsparametrar
%   för den dynamiska värderingsmodellen.
%
%   Modellen jämför INTE längre en akties multiplar mot bara ett fast
%   generiskt tal. Istället beräknas ett "dynamiskt riktvärde" per mått
%   genom att blanda:
%     1) ett generiskt basvärde (bm.Generic.*),
%     2) en fundamental justering för tillväxt/lönsamhet/skuldsättning,
%     3) företagets egen historiska median (fran de perioder som finns i
%        datan),
%     4) ett valfritt peer-/konkurrentmedianvärde om du matar in det
%        (se data.PeerMedian.<mått> i STOCK_DATA_TEMPLATE).
%
%   Se README.md för full motivering och källor.

bm = struct();

% --- Generiska basvärden (samma roll som tidigare, men nu bara EN av
%     flera referenspunkter, inte facit) ------------------------------
bm.Generic.TrailingPE   = 20;
bm.Generic.ForwardPE    = 18;
bm.Generic.PEGRatio     = 1.0;
bm.Generic.PriceToSales = 3;
bm.Generic.PriceToBook  = 3;
bm.Generic.EV_EBITDA    = 11;

% --- Fundamentala justeringsparametrar --------------------------------
% Justeringarna använder en dämpad, mättande funktion
%   exp(k * atan((x - center) / spread))
% som ger en mjuk, begränsad multiplikator (aldrig extrem) istället för
% att extrem tillväxt/lönsamhet linjärt trissar upp "rimligt" P/E hur
% mycket som helst.
bm.Adjust.GrowthCenter    = 8;   % % - antagen långsiktig "normal" vinst/omsättningstillväxt
bm.Adjust.GrowthSpread    = 50;
bm.Adjust.GrowthK         = 0.5;

bm.Adjust.QualityCenterROE = 12; % % - "normal" avkastning på eget kapital
bm.Adjust.QualitySpread    = 15;
bm.Adjust.QualityK         = 0.3;

bm.Adjust.LeverageCenterDE = 80; % % - "normal" skuldsättningsgrad (Debt/Equity)
bm.Adjust.LeverageSpread   = 60;
bm.Adjust.LeverageK        = 0.2;

bm.Adjust.MarginCenter    = 10;  % % - "normal" nettomarginal (för P/S-justering)
bm.Adjust.MarginSpread    = 15;
bm.Adjust.MarginK         = 0.4;

% --- Blandningsvikter: generiskt vs egen historik vs peer -------------
% Om historik eller peer-data saknas för ett mått omfördelas vikten
% automatiskt till de källor som faktiskt finns tillgängliga.
bm.BlendWeights.Generic    = 0.3;
bm.BlendWeights.Historical = 0.5;
bm.BlendWeights.Peer       = 0.2;

% --- Gruppvikter: undviker dubbelräkning mellan starkt relaterade mått
% (Trailing P/E, Forward P/E och PEG mäter i grunden samma sak) genom
% att slå ihop dem till en "Vinstvärdering"-grupp innan de vägs mot
% Omsättnings-, Tillgångs- och Företagsvärdering.
bm.GroupWeights.Earnings   = 0.35;
bm.GroupWeights.Sales      = 0.20;
bm.GroupWeights.Asset      = 0.15;
bm.GroupWeights.Enterprise = 0.30;

% --- Sektortyp: styr hur relevanta P/B och EV/EBITDA är ---------------
% 'generic'     - inga justeringar (standard)
% 'asset_light' - mjukvara/tjänster: P/B väger mindre (ofta ointressant
%                 för bolag med stora immateriella/inga bokförda tillgångar)
% 'asset_heavy' - kapitalintensiv industri: P/B väger mer
% 'financial'   - banker/försäkring: P/B väger klart mer, EV/EBITDA och
%                 P/S är mindre meningsfulla mått för denna sektor
bm.SectorType = 'generic';

% --- Gränser för "ej meningsfullt" (datakvalitetsflaggor) -------------
bm.NotMeaningful.MaxPE = 200; % P/E över detta -> troligen kraftigt tillfälligt deprimerad vinst

% --- Övrigt (används av hälso-/riskmodulerna, oförändrat) -------------
bm.CurrentRatio        = 1.5;
bm.DebtToEquity        = 100;
bm.PayoutRatio         = 75;
bm.RiskFreeRate        = 4.5;
bm.MarketReturnDefault = 9;

end

function data = parse_yahoo_text(filepath)
%PARSE_YAHOO_TEXT Läs in en textfil med Yahoo Finance "Statistics"-data
%   DATA = PARSE_YAHOO_TEXT(FILEPATH) läser en textfil som du skapat genom
%   att klistra in tabellerna "Valuation Measures", "Financial Highlights"
%   och "Trading Information" från Yahoo Finance statistiksida, och
%   returnerar en struct med numeriska fält. Saknade värden ("--") blir NaN.
%
%   Filen kan använda antingen tab eller minst tva mellanslag som
%   kolumnavskiljare (kopiera-och-klistra fran webbläsaren fungerar oftast
%   direkt).
%
%   Se även: ANALYZE_STOCK, STOCK_DATA_TEMPLATE

raw = fileread(filepath);
lines = regexp(raw, '\r\n|\r|\n', 'split');
lines = lines(~cellfun(@(s) isempty(strtrim(s)), lines));

data = struct();
data.PeriodLabels = {};
section = '';

valuationFields = {
    'MarketCap',       {'^market cap'}
    'EnterpriseValue', {'^enterprise value$'}
    'TrailingPE',      {'trailing p\/e'}
    'ForwardPE',       {'forward p\/e'}
    'PEGRatio',        {'peg ratio'}
    'PriceToSales',    {'price\/sales'}
    'PriceToBook',     {'price\/book'}
    'EV_Revenue',      {'enterprise value\/revenue'}
    'EV_EBITDA',       {'enterprise value\/ebitda'}
    };

financialFields = {
    'ProfitMargin',            {'profit margin'}
    'OperatingMargin',         {'operating margin'}
    'ReturnOnAssets',          {'return on assets'}
    'ReturnOnEquity',          {'return on equity'}
    'Revenue',                 {'^revenue \(ttm\)'}
    'RevenuePerShare',         {'revenue per share'}
    'QuarterlyRevenueGrowth',  {'quarterly revenue growth'}
    'GrossProfit',             {'gross profit'}
    'EBITDA',                  {'^ebitda$'}
    'NetIncome',               {'net income avi'}
    'DilutedEPS',              {'diluted eps'}
    'QuarterlyEarningsGrowth', {'quarterly earnings growth'}
    'TotalCash',               {'total cash \(mrq\)'}
    'TotalCashPerShare',       {'total cash per share'}
    'TotalDebt',               {'total debt \(mrq\)'}
    'DebtToEquity',            {'total debt\/equity'}
    'CurrentRatio',            {'current ratio'}
    'BookValuePerShare',       {'book value per share'}
    'OperatingCashFlow',       {'operating cash flow'}
    'LeveredFCF',              {'levered free cash flow'}
    };

tradingFields = {
    'Beta',                     {'beta \(5y'}
    'Change52Week',             {'52 week change'}
    'SP500Change52Week',        {'s&p 500 52-week change'}
    'High52Week',               {'52 week high'}
    'Low52Week',                {'52 week low'}
    'MA50',                     {'50-day moving average'}
    'MA200',                    {'200-day moving average'}
    'AvgVol3M',                 {'avg vol \(3 month\)'}
    'AvgVol10D',                {'avg vol \(10 day\)'}
    'SharesOutstanding',        {'^shares outstanding'}
    'ImpliedSharesOutstanding', {'implied shares outstanding'}
    'Float',                    {'^float'}
    'InsiderPct',               {'held by insiders'}
    'InstitutionPct',           {'held by institutions'}
    'SharesShort',              {'^shares short \((?!prior month)'}
    'SharesShortPriorMonth',    {'shares short \(prior month'}
    'ShortRatio',               {'short ratio'}
    'ShortPctFloat',            {'short % of float'}
    'ShortPctOutstanding',      {'short % of shares outstanding'}
    'ForwardDividendRate',      {'forward annual dividend rate'}
    'ForwardDividendYield',     {'forward annual dividend yield'}
    'TrailingDividendRate',     {'trailing annual dividend rate'}
    'TrailingDividendYield',    {'trailing annual dividend yield'}
    'AvgDividendYield5Y',       {'5 year average dividend yield'}
    'PayoutRatio',              {'payout ratio'}
    };

for i = 1:numel(lines)
    line = lines{i};
    lowLine = lower(strtrim(line));

    if contains(lowLine, 'valuation measures')
        section = 'valuation';
        continue;
    elseif contains(lowLine, 'financial highlights')
        section = 'financial';
        continue;
    elseif contains(lowLine, 'trading information')
        section = 'trading';
        continue;
    end

    tokens = regexp(line, '\t+', 'split');
    if numel(tokens) < 2
        tokens = regexp(strtrim(line), '\s{2,}', 'split');
    end
    if numel(tokens) < 2
        continue;
    end

    label = strtrim(tokens{1});
    values = tokens(2:end);

    if strcmp(section,'valuation') && strcmpi(label,'Current') && isempty(data.PeriodLabels)
        data.PeriodLabels = [{'Current'}, values];
        continue;
    end

    switch section
        case 'valuation'
            data = matchAndStore(data, label, values, valuationFields, true);
        case 'financial'
            data = matchAndStore(data, label, values, financialFields, false);
        case 'trading'
            data = matchAndStore(data, label, values, tradingFields, false);
        otherwise
            % ingen sektion identifierad ännu - hoppa över raden
    end
end

if isempty(data.PeriodLabels)
    data.PeriodLabels = {'Current'};
end

end


function data = matchAndStore(data, label, values, fieldDefs, multiPeriod)
lowLabel = lower(label);
for k = 1:size(fieldDefs,1)
    name = fieldDefs{k,1};
    patterns = fieldDefs{k,2};
    for p = 1:numel(patterns)
        if ~isempty(regexpi(lowLabel, patterns{p}, 'once'))
            if multiPeriod
                data.(name) = cellfun(@parseYahooValue, values);
            else
                data.(name) = parseYahooValue(values{1});
            end
            return;
        end
    end
end
end


function v = parseYahooValue(s)
s = strtrim(s);
if isempty(s) || strcmp(s,'--') || strcmpi(s,'N/A')
    v = NaN;
    return;
end
isPercent = endsWith(s,'%');
if isPercent
    s = s(1:end-1);
end
mult = 1;
if ~isempty(s)
    lastChar = upper(s(end));
    if lastChar == 'B'
        mult = 1e9;
        s = s(1:end-1);
    elseif lastChar == 'M'
        mult = 1e6;
        s = s(1:end-1);
    elseif lastChar == 'K'
        mult = 1e3;
        s = s(1:end-1);
    end
end
s = strrep(s, ',', '');
v = str2double(s) * mult;
end

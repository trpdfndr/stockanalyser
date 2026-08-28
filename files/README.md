# MATLAB Aktieanalysverktyg

Ett litet paket av MATLAB-program som tar Yahoo Finance-statistik
("Valuation Measures", "Financial Highlights", "Trading Information")
och räknar fram en kvantitativ risk-, hälso- och värderingsanalys, samt
en heuristisk köp/håll/sälj-rekommendation.

## Snabbstart

1. Gå till en aktie på Yahoo Finance -> fliken **Statistics**.
2. Markera och kopiera tabellerna (Valuation Measures, Financial
   Highlights, Trading Information) och klistra in dem i en textfil,
   t.ex. `min_aktie.txt` (samma format som `example_data.txt`).
3. Kör i MATLAB:

```matlab
data = parse_yahoo_text('min_aktie.txt');
analyze_stock(data, 'TICKER');
```

Det ger en fullständig textrapport i Command Window plus två figurer
(värderingstrend över tid, och en poängsammanfattning).

Vill du hellre skriva in siffrorna manuellt (utan textfil)? Kopiera
`stock_data_template.m`, döp om den och ändra värdena, kör sedan:

```matlab
data = min_aktie_data(); % din kopia av mallen
analyze_stock(data, 'TICKER');
```

Kör `run_example.m` för att se hela flödet på det bifogade
exempeldatasetet.

## Filer

| Fil | Vad den gör |
|---|---|
| `parse_yahoo_text.m` | Läser in en klistrad textfil -> struct med numeriska fält |
| `stock_data_template.m` | Samma struct hardkodad, för manuell inmatning |
| `config_benchmarks.m` | Alla riktvärden/tumregler samlade på ett ställe (redigerbara) |
| `compute_derived_fundamentals.m` | Härledda nyckeltal (se nedan) |
| `compute_valuation_metrics.m` | Jämförelse mot riktvärden + trendregression |
| `compute_financial_health.m` | Piotroski-inspirerad hälsopoäng |
| `compute_risk_metrics.m` | CAPM, likviditet, skuldsättning, utdelning, blankning |
| `score_and_recommend.m` | Väger ihop allt till en total poäng + rekommendation |
| `generate_report.m` | Skriver ut rapport + ritar diagram |
| `analyze_stock.m` | Kör alla steg ovan i rätt ordning |
| `run_example.m` | Exempelskript |
| `example_data.txt` | Den data du klistrade in, som körbart exempel |

## Vad räknas fram, och varifrån kommer metoderna?

**Härledda nyckeltal** (`compute_derived_fundamentals.m`)
- *Härlett aktiepris* = Market Cap / Utestående aktier (Yahoo ger inte
  priset direkt i denna tabell, så det backas ut).
- *Härledda totala tillgångar* = Nettovinst / ROA (algebraisk omskrivning
  av ROA-definitionen).
- *DuPont-identiteten* (DuPont Corp / Donaldson Brown, ca 1920):
  ROE = Nettomarginal × Kapitalomsättningshastighet ×
  Skuldsättningsmultiplikator. Vi har ROE, ROA och nettomarginal givna,
  så Skuldsättningsmultiplikator = ROE/ROA och
  Kapitalomsättningshastighet = ROA/Nettomarginal kan räknas fram direkt.
- *Grahamtalet* (Benjamin Graham, *The Intelligent Investor*):
  sqrt(22.5 × EPS × Bokfört värde/aktie) - ett konservativt,
  tillgångs-/vinstbaserat "fair value"-golv. Fungerar sämre för
  tillväxt-/immateriellt tunga bolag - använd med försiktighet.
- *Implicit förväntad EPS-tillväxt* = Trailing P/E ÷ Forward P/E - 1.
  Visar hur mycket vinsttillväxt marknaden prisar in mellan innevarande
  och nästa räkenskapsår.
- *Nettoskuld* = Enterprise Value - Market Cap.
- *Utdelningstäckning* jämförs bade mot nettovinst (traditionell Payout
  Ratio) och mot fritt kassaflöde - dessa kan ge helt olika bilder (se
  exempeldatan: vinstbaserad payout kan vara >100 % samtidigt som
  kassaflödet fortfarande täcker utdelningen bekvämt).

**Värdering - dynamisk modell** (`compute_valuation_metrics.m`)

Modellen jämför INTE längre en multipel mot bara ett fast generiskt tal.
För varje mått (Trailing P/E, Forward P/E, PEG, P/S, P/B, EV/EBITDA)
görs istället:

1. **Datakvalitetskontroll.** Negativ/saknad vinst eller EBITDA, eller
   ett orimligt högt P/E (> `bm.NotMeaningful.MaxPE`, default 200),
   flaggas som "ej meningsfullt" istället för att tvingas in i en poäng
   - sannolikt en engångseffekt/tillfälligt deprimerad vinst, inte ett
   äkta värderingssignal.
2. **Fundamental justering av det generiska riktvärdet.** Riktvärdet
   skalas med tre mjukt dämpade (icke-linjära) faktorer:
   `exp(k * atan((x - center) / spread))`
   - *Tillväxt* (vinst- resp. omsättningstillväxt YoY) höjer/sänker
     riktvärdet, men atan-funktionen mättar så att en extrem
     enskild-kvartal-tillväxt inte får trissa upp "rimligt" P/E
     obegränsat.
   - *Kvalitet* (ROE) - lönsammare bolag tillåts en högre multipel.
   - *Skuldsättning* (Debt/Equity) - högre skuldsättning sänker
     riktvärdet (mer risk).
   - *Marginal* (nettomarginal) - används specifikt för P/S, eftersom
     samma omsättning är olika mycket värd beroende på lönsamhet.
3. **Blandning med egen historik och (valfritt) peers.** Det
   fundamentalt justerade riktvärdet blandas med bolagets egen
   historiska median (fran de kvartal som finns i datan) och, om du
   matar in det, en peer-/konkurrentmedian
   (`data.PeerMedian.<mått>` - se `stock_data_template.m`).
   Vikterna sätts i `bm.BlendWeights` och omfördelas automatiskt om en
   källa saknas.
4. **Icke-linjär poängsättning.** Avvikelsen fran det blandade
   riktvärdet omvandlas till en poäng via en logistisk funktion på
   log-avvikelsen (`50 - 40*tanh(log2(värde/riktvärde))`), som mättar
   mot ~10/~90 istället för att träffa hårt 0/100 vid stora avvikelser.
   PEG bedöms istället via ett bandat intervall (<1 attraktivt,
   1,7-2,2 dyrt, osv. - Lynch-inspirerat), eftersom PEG redan är
   tillväxtnormaliserat.
5. **Gruppering (undviker dubbelräkning).** Trailing P/E, Forward P/E
   och PEG mäter i grunden samma sak (vinstmultipeln), så de slås ihop
   till en "Vinstvärdering"-grupp (Forward P/E + PEG, med Trailing P/E
   som reserv om de saknas) innan gruppen vägs mot Omsättnings-,
   Tillgångs- och Företagsvärdering. Vikterna sätts i
   `bm.GroupWeights` och justeras dessutom efter `bm.SectorType`
   ('generic' / 'asset_light' / 'asset_heavy' / 'financial') - t.ex.
   väger P/B mindre för tillgångslätta bolag (mjukvara) och mer för
   banker/fastighetsbolag.
6. **Trend + pris- vs fundamentaldriven tolkning.** Linjär regression
   (`polyfit`) på de historiska kolumnerna skattar om multipeln
   expanderar eller krymper över tid (med R² som styrkemått). Detta
   kompletteras med en grov heuristik som jämför multipelns totala
   förändring med förändringen i dess "pris-drivare" (Market Cap för
   P/E-familjen, Enterprise Value för EV/EBITDA) för att gissa om en
   förändring är prisdriven eller beror på att vinsten/EBITDA:n
   förändrats.

De ursprungliga generiska riktvärdena (`bm.Generic.*`) finns kvar men är
nu bara EN av flera referenspunkter (vikt `bm.BlendWeights.Generic`,
default 30 %) - inte facit.

**Finansiell hälsa** (`compute_financial_health.m`)
- Inspirerad av Joseph Piotroskis F-Score (Piotroski, 2000, *Value
  Investing: The Use of Historical Financial Statement Information to
  Separate Winners from Losers*, Journal of Accounting Research).
  OBS: den fullständiga F-Score är 9 punkter och kräver TVA ars data
  (förändring i skuldsättning, aktieantal, marginal). Med ett enda
  Yahoo-snapshot kan vi bara testa nivåkriterier (lönsamhet,
  kassaflödeskvalitet, likviditet, skuldsättning, tillväxt) - därför
  kallas det "Piotroski-inspirerat", inte en riktig F-Score.

**Risk** (`compute_risk_metrics.m`)
- *CAPM* (Sharpe, 1964): Förväntad avkastning = Riskfri ränta +
  Beta × (Marknadsavkastning - Riskfri ränta). Jämförs mot faktisk
  52-veckorsavkastning för att se om aktien presterat bättre/sämre än
  vad dess systematiska risk (beta) motiverar.
- Likviditetsrisk: Current Ratio < 1 är en klassisk varningssignal för
  kortsiktig betalningsförmåga.
- Skuldsättningsrisk: Debt/Equity över riktvärdet.
- Utdelningsrisk: Payout Ratio > 100 % av vinsten (men se
  kassaflödesbaserad täckning ovan för en mer nyanserad bild).
- Blankningsstatistik: hög Short % of Float / Short Ratio tolkas som
  förhöjt sentiment-relaterat risk (kan vara bearish signal ELLER
  "short squeeze"-potential - modellen avgör inte vilket).

**Sammanvägning** (`score_and_recommend.m`)
- Total poäng = 35 % Värdering + 30 % Hälsa + 25 % Säkerhet (100 -
  Riskpoäng) + 10 % Momentum (pris vs 200-dagars glidande medelvärde).
  Momentum väger medvetet lägre eftersom det säger relativt lite om ett
  bolags långsiktiga fundamentala värde och kan se bra ut precis innan
  marknaden vänder.
- Vikterna är fritt valda avvägningar, inte hämtade fran nagon specifik
  studie - ändra dem i `score_and_recommend.m` om du vill vikta om.

## Om ROIC

Modellen använder ROE (och indirekt ROA, via DuPont-nedbrytningen i
`compute_derived_fundamentals.m`) som kvalitetsmått i den fundamentala
justeringen, inte ROIC. En korrekt ROIC-beräkning kräver EBIT,
skattesats och investerat kapital, vilket Yahoos statistiksida inte ger
direkt (bara EBITDA, inte EBIT/D&A-uppdelningen). Om du har dessa
uppgifter fran annan källa kan du lägga till dem i din data-struct och
utöka `evaluateMetric` i `compute_valuation_metrics.m` för att använda
en riktig ROIC istället för ROE - strukturen (smoothAdj med
center/spread/k) är densamma.

## Begränsningar (läs detta!)

- Detta är en **kvantitativ heuristik**, inte finansiell radgivning och
  inte en fullständig fundamental analys. Den saknar helt kontext om
  bransch, konkurrenssituation, ledning, regulatorisk risk, makroekonomi
  och kvalitativa faktorer.
- Riktvärdena i `config_benchmarks.m` är generiska/breda marknadssnitt -
  inte branschjusterade. En SaaS-aktie och ett bankaktie ska INTE
  bedömas mot samma P/B- eller skuldsättningsriktvärde.
- Ingen full Altman Z-Score beräknas, eftersom Yahoos statistiksida inte
  ger Totala Skulder, EBIT eller Balanserade Vinstmedel direkt (bara en
  delmängd kan härledas). Lägg till dessa fält själv i strukten om du
  vill bygga ut det.
- Modellen är känslig för engångsposter (t.ex. om vinsten just nu är
  onormalt låg/hög pafverkar den bade P/E-multiplarna och flera
  hälsokriterier kraftigt).
- Testa och validera alltid resultaten mot din egen bedömning - läs
  siffrorna, dra egna slutsatser, och använd modellen som ett
  startverktyg, inte facit.

## Källor

- Damodaran, A. - Valuation multiples data, NYU Stern
  (pages.stern.nyu.edu/~adamodar)
- Graham, B. - *The Intelligent Investor* (Grahamtalet)
- Lynch, P. - *One Up On Wall Street* (PEG-heuristiken)
- Piotroski, J. (2000) - *Value Investing: The Use of Historical
  Financial Statement Information to Separate Winners from Losers*,
  Journal of Accounting Research
- Sharpe, W. (1964) - Capital Asset Pricing Model
- DuPont Corporation / Donaldson Brown - DuPont-identiteten för ROE

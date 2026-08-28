%% Exempel: kör hela aktieanalysen
% Detta skript visar tva sätt att mata in data:
%  1) Klistra in text fran Yahoo Finance -> spara som .txt -> PARSE_YAHOO_TEXT
%  2) Skriv/kopiera in siffrorna direkt i en MATLAB-struct, se STOCK_DATA_TEMPLATE

clear; clc; close all;

%% Alternativ 1: läs fran textfil (rekommenderas för nya aktier)
data = parse_yahoo_text('example_data.txt');
analyze_stock(data, 'EXEMPELAKTIE (fran example_data.txt)');

%% Alternativ 2: använd inbyggd malldata direkt (avkommentera för att testa)
% data2 = stock_data_template();
% analyze_stock(data2, 'MALL-AKTIE');

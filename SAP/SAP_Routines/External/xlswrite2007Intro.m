function [Excel, ExcelWorkbook] = xlswrite2007Intro(File)

% NB: File should contain the whole path to .xls file

%%% Preliminary code for xlswrite2007 (2.0zd):
Excel = actxserver('Excel.Application');
if ~exist(File,'file')
    ExcelWorkbook = Excel.workbooks.Add;
    ExcelWorkbook.SaveAs(File)
    ExcelWorkbook.Close(false);
end
ExcelWorkbook = Excel.workbooks.Open(File);


%% History

% 05/08/2010: creation
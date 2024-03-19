function [log_file] = caap_scan_logfile(arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   caap_scan_logfile(arg)
%
%   Scant das Logfile der letzten Berechnung auf Ereignisse
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

% Log-File einlesen und aufbereiten
log_file_content = fileread(arg.info.log_file);
log_file_content = strsplit(log_file_content,'\r');

% Vorbelegung für Fehler
log_file.n_error = 0;

% Vorbelegung für Warnungen
log_file.n_warning = 0;

%% Schleife über alle Zeilen
for i_line = 1:1:size(log_file_content,2)
    
    % Fehler suchen
    if ~isempty(strfind(log_file_content{1,i_line},' * * * E R R O R * * *'))
        % Wenn es entspr. "ERROR"-Eintragungen im Log-File gibt,
        % ausschließen, dass es sich um den (irrelevanten) Fehler handelt,
        % die (komischerweise gelöschte) Y08-Datei zu öffnen, wenn man "Elastic"
        % als Hysteresemodell für Beton ausgewählt hat
        if isempty(strfind(log_file_content{1,i_line},'(WHILE GETTING BASE REACTION RESPONSE)')) && isempty(strfind(log_file_content{1,i_line+1},'FILE OPEN ERROR #   -2,'))
            % Ansonsten handelt es sich um einen wirklichen
            % (schwerwiegenden) Fehler!
            lok_error = char();
            log_file.n_error = log_file.n_error + 1;
            for j_line = i_line+1:1:size(log_file_content,2)
                if strcmp(log_file_content{j_line},newline)
                    break
                else
                    text = strsplit(log_file_content{j_line},'\n');
                    lok_error = [lok_error text{end} '\n'];
                end
            end
            log_file.errors.(['error_' num2str(log_file.n_error)]) = lok_error;
        end
    end
    
    % Warnungen suchen
    if ~isempty(strfind(log_file_content{1,i_line},' * * * W A R N I N G * * *'))
        
        lok_warning = char();
        log_file.n_warning = log_file.n_warning + 1;
        
        for j_line = i_line+1:1:size(log_file_content,2)
            if strcmp(log_file_content{j_line},newline)
                break
            else
                text = strsplit(log_file_content{j_line},'\n');
                lok_warning = [lok_warning text{end} '\n'];
            end
        end
        log_file.warnings.(['warning_' num2str(log_file.n_warning)]) = lok_warning;
    end
end
end
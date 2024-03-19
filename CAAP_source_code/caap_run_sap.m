function caap_run_sap(modell,arg,option)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   caap_run_sap(sap_path,sap_file,optionen)
%
%   Funktion fürs Ausführen von SAP2000 und Berechnung des Modells.
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

switch option
    case 'o'
        sap_file = [arg.info.sap_file(1:end-3) 'sdb'];
        
        % Befehl ans System schicken und NICHT warten (&-Zeichen)
%         system(sprintf('"%s" "%s" &',arg.info.sap_path, sap_file));
        command_string = sprintf('"%s" "%s" &',arg.info.sap_path, sap_file);
        
    case 'or'
        % Logfile löschen, falls vorhanden
        if isfile(arg.info.log_file)
            delete(arg.info.log_file);
        end
        
        % Modell-Datei schreiben
        caap_write_sap_file(modell,arg);
        
        % Befehl ans System schicken und NICHT warten (&-Zeichen)
%         system(sprintf('"%s" "%s" /R &',arg.info.sap_path,arg.info.sap_file));
        command_string = sprintf('"%s" "%s" /R &',arg.info.sap_path,arg.info.sap_file);
        
    case 'orc'
        % Logfile löschen, falls vorhanden
        if isfile(arg.info.log_file)
            delete(arg.info.log_file);
        end
        % Modell-Datei schreiben
        caap_write_sap_file(modell,arg);
        
        % Befehl ans System schicken und warten
%         system(sprintf('"%s" "%s" /R /C',arg.info.sap_path,arg.info.sap_file));
        command_string = sprintf('"%s" "%s" /R /C',arg.info.sap_path,arg.info.sap_file);
end

system(command_string);


%% Ausgabe von Warnungen und Fehlern
% Dürfte beim AMI-Verfahren an dieser Stelle nicht erforderlich sein,
% denn beim AMI-Verfahren wird ohnehin in jedem Adaptionsschritt
% "caap_check_calc_success" aufgerufen!
% Ggf. bei Auftreten mal anpassen.

if arg.info.finish == 0 && ~strcmp(option,'o')
    log_file = caap_scan_logfile(arg);
    
    %% Wurden Fehler gefunden?
    if log_file.n_error > 0
        error('There must have been serious errors in the log file. Please check!')
    end
    
end
end
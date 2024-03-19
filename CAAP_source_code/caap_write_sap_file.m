function caap_write_sap_file(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   caap_write_sap_file(modell,arg)
%   
%   Funktion zum Schreiben der Modell-Datei (.$2k)
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% Vorgeschaltet: Berechnungsschritte der nichtlinearen Berechnungen schreiben
% Erstmal ganz normal die "Standard"-Werte der nl-steps vorgeben für alle
% Lastfälle
n_cases = size(modell.Case0x2DStatic40x2DNonlinearParameters.Case,1);
[i_dead, ~, ~] = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),arg.info.name_vert));
ATTRIBUTE = {...
    'MinNumState',num2str(arg.comp.nl_steps(1));...
    'MaxNumState',num2str(arg.comp.nl_steps(2));...
    'PosIncOnly','YES';...
    'ResultsSave','Multiple States'};

for i_attribut = 1:1:size(ATTRIBUTE,1)
    if isfield(modell.Case0x2DStatic40x2DNonlinearParameters.Case,ATTRIBUTE{i_attribut,1})
        modell.Case0x2DStatic40x2DNonlinearParameters.Case = rmfield(modell.Case0x2DStatic40x2DNonlinearParameters.Case,ATTRIBUTE{i_attribut,1});
    end
    values = cell(n_cases,1);
    values(:) = ATTRIBUTE(i_attribut,2);
    
    if strcmp(ATTRIBUTE{i_attribut,1},'ResultsSave')
        values(i_dead) = {'Final State'};
    end
    modell.Case0x2DStatic40x2DNonlinearParameters.(ATTRIBUTE{i_attribut,1}) = values;
end
% Anschließend die nl-steps bestimmter LFe anpassen:
% -> "Vertikallsten" immer in nur 5 Schritten rechnen
% a) "MinNumState" korrigieren
modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState(strcmp(modell.Case0x2DStatic40x2DNonlinearParameters.Case,arg.info.name_vert)) = {'5'};
% b) "MaxNumState" korrigieren
modell.Case0x2DStatic40x2DNonlinearParameters.MaxNumState(strcmp(modell.Case0x2DStatic40x2DNonlinearParameters.Case,arg.info.name_vert)) = {'5'};
% -> Beim Pushover-LF im Rahmen des "ami_o"-Verfahrens:
if strcmp(arg.info.procedure,'ami_o') && isfield(arg.comp,'min_num_state_stepwise') % letztere Bedingung ist nur bei Initialberechnung noch nicht erfüllt (sprich: Berechnung der Vertikallasten)
    % Je nach Fall: MAX- oder Korrektur-Berechnung
    if ~isfield(arg.comp,'k') || length(arg.comp.k) < arg.info.nummer % 1. Bedingung bei MAX-Ber. im ersten AMI-Schritt erfüllt, 2. Bedingung bei MAX-Ber. in jedem weiteren AMI-Schritt
        % Fall: MAX-Berechnung
        % (Hier sind alle Lastfälle anzupassen)
        % a) "MinNumState" korrigieren
        modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState = arg.comp.min_num_state_stepwise;
        % b) "MaxNumState" korrigieren
        modell.Case0x2DStatic40x2DNonlinearParameters.MaxNumState = arg.comp.max_num_state_stepwise;
    else
        % Fall: Korrektur-Berechnung
        % Möglichkeit 1: "Normale" Korrekturberechnung (dann gibt es einen LF mehr als eigentl. in 
        % 'arg.comp.min/max_num_state_stepwise' betrachtet werden, sodass der letzte LF zu ignorieren ist; 
        % hierbei handelt es sich nur um den bereits für den nächsten AMI-Schritt angelegten Pushover-LF!)
        if size(modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState,1) > size(arg.comp.min_num_state_stepwise,1)
            % a) "MinNumState" korrigieren
            modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState(1:end-1,1) = arg.comp.min_num_state_stepwise;
            % b) "MaxNumState" korrigieren
            modell.Case0x2DStatic40x2DNonlinearParameters.MaxNumState(1:end-1,1) = arg.comp.max_num_state_stepwise;
        % Möglichkeit 2: Korrekturberechnung mit Konvergenzproblemen (hier
        % ist es zuletzt so gewesen, dass dann kein LF ignoriert werden musste,
        % auch wenn ich das nicht zu 100 % nachvollziehen konnte!)
        else
            % a) "MinNumState" korrigieren
            modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState(1:end,1) = arg.comp.min_num_state_stepwise;
            % b) "MaxNumState" korrigieren
            modell.Case0x2DStatic40x2DNonlinearParameters.MaxNumState(1:end,1) = arg.comp.max_num_state_stepwise;
        end
    end
end
% -> Ggf. die Schrittzahl gescheiterter Lastfälle reduzieren
if isfield(arg.comp,'nl_steps_lc_failed')
    % In Schleife über alle zu korrigierenden Lastfälle entsprechende Korrekur vornehmen
    for i_LC_failed = 1:size(arg.comp.nl_steps_lc_failed,1)
        % Korrektur für den aktuellen Load Case
        % a) "MinNumState" korrigieren
        modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState(strcmp(modell.Case0x2DStatic40x2DNonlinearParameters.Case(:),arg.comp.nl_steps_lc_failed(i_LC_failed,2))) = {num2str(arg.comp.nl_steps_lc_failed{i_LC_failed,1}(1))};
        % b) "MaxNumState" korrigieren
        modell.Case0x2DStatic40x2DNonlinearParameters.MaxNumState(strcmp(modell.Case0x2DStatic40x2DNonlinearParameters.Case(:),arg.comp.nl_steps_lc_failed(i_LC_failed,2))) = {num2str(arg.comp.nl_steps_lc_failed{i_LC_failed,1}(2))};
    end
end

%% Kontrollknoten reinschreiben
modell.Case0x2DStatic20x2DNonlinearLoadApplication.MonitorJt = repmat({arg.comp.kk},size(modell.Case0x2DStatic20x2DNonlinearLoadApplication.MonitorJt,1),1);

%% Solver: Advanced
modell.AnalysisOptions.Solver = {'Advanced'};

%% Case für System-Matrizen angeben
modell.AnalysisOptions.StiffCase = {arg.info.name_modal_old};

%% File löschen, falls schon vorhanden
if isfile(arg.info.sap_file)
    delete(arg.info.sap_file)
end

%% Tabellen schreiben

% File öffnen
fid = fopen(arg.info.sap_file,'w');

% Kopfzeile schreiben
fprintf(fid,'File %s was saved on m/d/yy at h:mm:ss\n',arg.info.sap_file);

% Alle Tabellennamen ermitteln
TABELLEN = fieldnames(modell);

% Schleife über alle Tabellen
for i_tabelle = 1:1:size(TABELLEN,1)
    
    % Tabellenname abgreifen
    tabelle = TABELLEN{i_tabelle};
    
    % Kopfzeile der Tabelle schreiben
    fprintf(fid,'\nTABLE:  "%s"\n',modell.(tabelle).name);
    
    % Alle Attribute der Tabelle ermitteln
    ATTRIBUTE = fieldnames(modell.(tabelle));
    
    % Schleife über alle Einträge des ersten Attributes
    for i_zeile = 1:1:size(modell.(tabelle).(ATTRIBUTE{1}),1)
        
        % Schleife über alle Attribute der Tabelle
        for i_attribut = 1:1:size(ATTRIBUTE,1)
            
            % Attribut abgreifen
            attribut = ATTRIBUTE{i_attribut};
            
            % Attribut schreiben, wenn Feldname nicht 'name' ist
            if ~strcmp(attribut,'name')
                
                % Wert prüfen
                % Mind. ein Komma vorhanden?
                
                % WARUM TRITT HIER JETZT EIN VERDAMMTER FEHLER AUF?!
                if ~isempty(strfind(modell.(tabelle).(attribut){i_zeile},','))
                    
                    value = strsplit(modell.(tabelle).(attribut){i_zeile},',');
                    
                    if size(value,2) == 2
                        if ~(isnan(str2double(value{1})) && isnan(str2double(value{2})))
                            type = 'ZAHL';
                        else
                            type = 'WORT';
                        end
                    else
                        type = 'WORT';
                    end
                    
                    % Lässt sich der Ausdruck in einen double konvertieren, ist
                    % es ein Integer-Wert
                elseif ~isnan(str2double(modell.(tabelle).(attribut){i_zeile}))
                    type = 'ZAHL';
                    
                % Sonst ist es ein Wort
                else
                    type = 'WORT';
                end
                
                % Je nach Typ Zeile schreiben
                switch type
                    case 'KOMMA'
                        fprintf(fid,'   %s=%s',attribut,modell.(tabelle).(attribut){i_zeile}); 
                    case 'ZAHL'
                        fprintf(fid,'   %s=%s',attribut,modell.(tabelle).(attribut){i_zeile}); 
                    case 'WORT'
                        fprintf(fid,'   %s="%s"',attribut,modell.(tabelle).(attribut){i_zeile}); 
                end            
            end
        end
        % Zeilenumbruch
        fprintf(fid,'\n');
    end
end
% End of File
fprintf(fid,'\nEND TABLE DATA');

% File schließen
fclose(fid);
end
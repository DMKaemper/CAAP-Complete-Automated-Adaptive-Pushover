function struktur = caap_sort_field(struktur,feld,spalte)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Entwicklung                                                             %
%                                                                         %
% Erstelldatum:         23.07.2019                                        %
% Autor:                Max                                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Letzte Änderungen:    23.07.2019: Dominik                               %
%                       05.08.2019: Max                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% function struktur = caap_sort_field(struktur,feld,spalte)
%
% Diese Funktion sortiert die Ergebnisse, die in der entspr. Input-Struktur
% unter "feld" abgespeichert sind. Jenachdem um welches Feld es sich dabei
% handelt, ist die Spalte, nach der sortiert wird, vorgegeben. 
% Dies liegt darin begründet, dass es in der Regel nur eine sinnvolle
% Spalte gibt, nach der sortiert werden kann. Weiter unten ist dies aber
% näher erläutert.
%
%
% Input:
%
% struktur  - Die Struktur, deren Feld "feld" sortiert werden soll.
%
% feld      - Das Feld der Input-Struktur, in dem die
%             Ergebnisse, die sortiert werden sollen, abgespeichert sind.
%             Eingabe hat als String zu erfolgen.
%
% spalte    - Spalte, nach der sortiert werden soll.
%             Eingabe hat als String zu erfolgen.
%
%
%
% Output:
%
% struktur  - Input-Struktur wie aus der Eingabe, erweitert um das Feld
%             "feld"_sortiert, welches die sortierten Werte enthält.
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Eingaben prüfen

% Prüfen, welche Eingabeargumente vorhanden sind
if nargin < 1
    error('Die Input-Struktur fehlt!');
elseif nargin < 2
    error('Die Angabe des Feldes fehlt!');
elseif nargin < 3
    error('Die Angabe der Spalte fehlt!');
end


%% Weitere Prüfungen der Eingaben

% Prüfen, ob struktur eine Struktur ist
if ~ist_typ(struktur,'struct')
    error('Bei der Angabe von "struktur" muss es sich um eine Struktur handeln!')
end

% Prüfen, ob feld ein String ist
if ~ist_typ(feld,'string')
    error('Bei der Angaben von "feld" muss es sich um einen String handeln!');
end

% Prüfen, ob "feld" in "struktur" vorhanden
if ~isfield(struktur,feld)
    error('Das Feld %s existiert nicht in der Input-Struktur!',feld);
end

% Prüfen, ob spalte ein String ist
if ~ist_typ(feld,'string')
    error('Bei der Angabe von "spalte" muss es sich um einen String handeln!');
end


%% MAIN sortieren

% Gibt es die Spalte überhaupt?
spalten_nr = sub_get_row(struktur,feld,spalte);

if isnan(spalten_nr)
    fprintf(2,'The column %s does not exist in the field %s! Sorting is canceled.\n',spalte,feld)
    return
end

% Unique Names in der zu sortierenden Spalte finden
sortnames = sub_get_unique_names(struktur,feld,spalten_nr);

% Schleife über alle Unique-Names
for i_name = 1:1:size(sortnames,1)
    name = sortnames{i_name};
    
    % Gültigen Feld-Namen generieren
    temp_name = sub_gen_feld_name(name);
    
    % Vorbelegung als Cell-Array
    n_zeilen = sum(strcmp(struktur.(feld).Werte(:,1),name));
    struktur_temp.(temp_name) = cell(n_zeilen,size(struktur.(feld).Inhalt,2));
    
    % Line-Counter erstellen
    line_counter.(temp_name) = 1;
end

% Schleife über alle Zeilen
for i_Zeile = 1:1:size(struktur.(feld).Werte,1)
    
    % aktuellen LoadCase
    name = struktur.(feld).Werte{i_Zeile,spalten_nr};
    
    % Gültigen Feld-Namen generieren
    temp_name = sub_gen_feld_name(name);
    
    % Daten in den entsprechenden Case umspeichern
    struktur_temp.(temp_name)(line_counter.(temp_name),:) = ...
        struktur.(feld).Werte(i_Zeile,:);
    
    % entsprechenden Counter hochzählen
    line_counter.(temp_name) = line_counter.(temp_name) + 1;
end

% struktur um das neue Feld erweitern
struktur.(feld).Werte = struktur_temp;
end

%% Sub-Funktionen

% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Spaltennummer finden
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function spalten_nr = sub_get_row(struktur,feld,spalte)
inhalt = struktur.(feld).Inhalt;
row = strcmp(inhalt,spalte);

[row_max,spalten_nr] = max(row);

if row_max == 0
    spalten_nr = NaN;
end
end

% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Unique Names in der zu sortierenden Spalte finden
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function unique_names = sub_get_unique_names(struktur,feld,row)

% Versuch das mal
try    
    % entweder es sind strings
    unique_names = unique(struktur.(feld).Werte(:,row));
    
catch
    % oder Zahlen
    unique_names = unique(cell2mat(struktur.(feld).Werte(:,row)));
    unique_names = num2cell(unique_names);
end % Ende versuch das mal
end

% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Gültigen Feldnamen generieren
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function temp_name = sub_gen_feld_name(name)
if ist_typ(name,'int')
    temp_name = [spalte '_' num2str(name)];
elseif ~isnan(str2double(name(1)))
    temp_name = [spalte '_' num2str(name)];
else
    temp_name = name;
end

temp_name = strrep(temp_name,' ','_');
temp_name = strrep(temp_name,'-','_');
end
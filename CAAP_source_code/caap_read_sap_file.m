function sheetData = caap_read_sap_file(datei,console)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   sheetData = caap_read_sap_file(datei,console)
%   
%   Funktion zum Einlesen von SAP-Files
%   Mögliche Dateitypen:
%   - xml
%   - s2k
%   - $2k
%   - txt
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%%
if nargin < 1
    error('No SAP2000 file was defined!');
elseif nargin < 2
    console = 0;
end

if ~ist_typ(console,'int') || (console ~= 0 && console ~= 1)
    console = 0;
end

sheets = cell(1,0);
[pathstr, name, ext] = fileparts(datei);

% Einlesen
switch ext
    
    case '.xml'
        % Kleine Zwischenkorrektur zu langer Tags (und zwar an der Quelle,
        % sprich UNMITTELBAR INNERHALB des xml-Files)
        content = fileread(datei);
        replaces = {'Program_x0020_Control','Program_Control';...
                    'Joint_x0020_Coordinates','Joint_Coordinates';...
                    'Connectivity_x0020_-_x0020_Frame','ConnectivityFrame';...
                    'Joint_x0020_Displacements','JointDisplacements';...
                    'Joint_x0020_Accelerations_x0020_-_x0020_Absolute','JointAccelerationsAbsolute';...
                    'Joint_x0020_Reactions','JointReactions';...
                    'Assembled_x0020_Joint_x0020_Masses','AssembledJointMasses';...
                    'Base_x0020_Reactions','BaseReactions';...
                    'Modal_x0020_Participation_x0020_Factors','ModalParticipationFactors';...
                    'Modal_x0020_Participating_x0020_Mass_x0020_Ratios','ModalParticipatingMassRatios';...
                    'Frame_x0020_Hinge_x0020_States','Frame_Hinge_States';...
                    'Frame_x0020_Fiber_x0020_Hinge_x0020_States_x0020_01_x0020_-_x0020_Overall_x0020_Hinge','Frame_Fiber_Hinge_States_01_Overall_Hinge';...
                    'Frame_x0020_Fiber_x0020_Hinge_x0020_States_x0020_02_x0020_-_x0020_Individual_x0020_Fibers','Frame_Fiber_Hinge_States_02_Individual_Fibers';...
                    'Element_x0020_Forces_x0020_-_x0020_Frames','Element_Forces_Frames'};
        % flag notwendiger "stringreplaces" setzen
        flag_replace = 0; % erstmal Annahme: Exportdatei wurde schonmal von dieser Routine eingelesen und hat die enspr. Korrekturen bereits vorgenommen; dann ist eine erneute Anpassung nicht notwendig
        for i_replace = 1:size(replaces,1)
            if any(strfind(content,replaces{i_replace,1})) % für den "strrep"-Befehl gar nicht notwendig, aber für das Setzen der flag!
                content = strrep(content,replaces{i_replace,1},replaces{i_replace,2});
                flag_replace = 1;
            end
        end
        % xml-Datei anpassen, nur wenn nötig
        if flag_replace
            fid = fopen(datei,'wt');
            fprintf(fid,content);
            fclose(fid);
        end
        
        if console; disp(' - Lese ".xml" ein!'); end
        data = caap_xml2struct(datei);
        sheetData = struct;
        SHEETS = fieldnames(data.NewDataSet);
        % Schleife über alle Subfelder von "data.NewDataSet"
        for i_sheet = 1:1:size(SHEETS,1)
            % Mit allen Subfeldern außer "xs_colon_schema" etwas tun!
            if ~strcmp(SHEETS{i_sheet},'xs_colon_schema')
                % Prüfen, ob aktuelles Subfeld seinerseits eine Struktur ist
                if ist_typ(data.NewDataSet.(SHEETS{i_sheet}),'struct')
                    % FALL: Aktuelles Subfeld ist eine STRUKTUR
                    % Dessen Attribute auslesen
                    ATTRIBUTE = fieldnames(data.NewDataSet.(SHEETS{i_sheet}));
                    % Dimensionen bestimmen
                    dimensionen = [size(data.NewDataSet.(SHEETS{i_sheet}),2) length(ATTRIBUTE)];
                    % Vorbelegen
                    sheetData.(SHEETS{i_sheet}).Werte = cell(dimensionen);
                    sheetData.(SHEETS{i_sheet}).Inhalt = cell(dimensionen);
                    % Schleife über alle Attribute
                    for i_attribut = 1:1:size(ATTRIBUTE,1)
                        sheetData.(SHEETS{i_sheet}).Inhalt(1,i_attribut) = {ATTRIBUTE{i_attribut,1}};
                    end
                    % Schleife über alle Zeilen
                    for i_zeile = 1:1:size(data.NewDataSet.(SHEETS{i_sheet}),2)
                        % Schleife über alle Attribute
                        for i_attribut = 1:1:size(ATTRIBUTE,1)
                            sheetData.(SHEETS{i_sheet}).Werte(i_zeile,i_attribut) = {data.NewDataSet.(SHEETS{i_sheet}).(ATTRIBUTE{i_attribut}).Text};
                        end
                    end
                else
                    % FALL: Aktuelles Subfeld ist ein Cell-Array
                    % Dessen Attribute auslesen
                    ATTRIBUTE = fieldnames(data.NewDataSet.(SHEETS{i_sheet}){1,1});
                    % Dimensionen bestimmen
                    dimensionen = [size(data.NewDataSet.(SHEETS{i_sheet}),2) length(ATTRIBUTE)];
                    % Vorbelegen
                    sheetData.(SHEETS{i_sheet}).Werte = cell(dimensionen);
                    sheetData.(SHEETS{i_sheet}).Inhalt = cell(1,dimensionen(2));
                    % Schleife über alle Attribute
                    for i_attribut = 1:1:size(ATTRIBUTE,1)
                        sheetData.(SHEETS{i_sheet}).Inhalt(1,i_attribut) = {ATTRIBUTE{i_attribut,1}};
                    end
                    % Schleife über alle Zeilen
                    for i_zeile = 1:1:size(data.NewDataSet.(SHEETS{i_sheet}),2)
                        % Sub-Struktur auslesen
                        sub_struct = data.NewDataSet.(SHEETS{i_sheet}){1,i_zeile};
                        % Schleife über alle Attribute
                        for i_attribut = 1:1:size(ATTRIBUTE,1)
                            try
                                sheetData.(SHEETS{i_sheet}).Werte(i_zeile,i_attribut) = {sub_struct.(ATTRIBUTE{i_attribut}).Text};
                            catch
                                % Informative Ausgabe
                                fprintf(2,'\n Unfortunately, the xml export seems to have been carried out incorrectly: The data is incomplete!!!')
                                fprintf(2,'\n Concrete problem (at least i.a.):')
                                fprintf(2,'\n Sheet %s -> Data block no. %s contains no %s information!\n',SHEETS{i_sheet},num2str(i_zeile),ATTRIBUTE{i_attribut})
                                % Kontrollierter Abbruch
                                error('The import must therefore unfortunately be aborted!')
                            end
                        end
                    end
                end
            end
        end
        

    case {'.s2k','.$2k','.txt'}
        if console; disp([' - Lese "' ext '" ein!']); end
        fid = fopen(datei,'r');
        if fid == -1
            error('File not found!');
        end
        % Auf diese Weise nochmal 12% schneller als fgetl
        fData = textscan(fid,'%s','Delimiter','\n');fData = fData{1};aktZeile = 1;
        fclose(fid);
        % Tabellen einlesen
        while 1
            [tline,aktZeile] = subZeile(fData,aktZeile);
            if ~ischar(tline)
                % Datei Ende
                break
            else
                k = strfind(tline,'TABLE:  ');
                if k
                    % Tabelle finden
                    tmp = tline(k+8:end);
                    table_name = tmp;
                    if strcmp(tmp(1),'"')
                        tmp = tmp(2:end-1);
                    end
                    % Tabellennamen Groß/Kleinschreibung
                    tmp(2:end) = lower(tmp(2:end));
                    for bb = 1:length(tmp)-1
                        if strcmp(tmp(bb),' ')
                            tmp(bb+1) = upper(tmp(bb+1));
                        end
                    end
                    sheetName = gentag(tmp);
                    
                    % Lange Namen abfangen
                    switch  sheetName
                        case 'HingesDef030x2DNoninteracting0x2DDeformControl0x2DForce0x2Ddeform'
                            sheetName = 'HingesDef03NoninteractingDeformControlForcedeform';
                    end
                    
                    sheets = [sheets,tmp];
                    
                    % Inhalt lesen
                    
                    % Position des Zeigers in der Datei behalten
                    stelle = aktZeile;
                    
                    % Schleife um die benötigte Feldgröße n vorab zu ermitteln
                    n = 0;
                    while 1
                        [zeile,aktZeile] = subZeile(fData,aktZeile);
                        if isnumeric(zeile)
                            break
                        elseif isempty(strtrim(zeile))
                            break
                        elseif strcmp(zeile(end),'_')
                            continue
                        else
                            n=n+1;
                        end
                    end
                    
                    % Zeiger zurücksetzen
                    aktZeile = stelle;
                    
                    % Einlesen
                    a = 1;
                    output = struct;
                    while 1
                        % ganze Datenzeile lesen
                        [tline,aktZeile] = lese_sap_zeile_cell(fData,aktZeile);
                        if isnumeric(zeile) || all(isspace(tline))
                            break
                        else
                            % Aufspalten und am Gleichheitszeichen aufteilen
                            tline = strtrim(tline);
                            k = strfind(tline,'=');
                            if isempty(k)
                                break
                            end
                            start = 1;
                            k = [k length(tline)+1];
                            ksprung = 0;
                            for b = 1:length(k)-1
                                abschnitt = tline(start:k(b+1)-1);
                                ueberschrift = genvarname_char(abschnitt(1:k(b-ksprung)-start));
                                if ~isfield(output,ueberschrift)
                                    output.(ueberschrift)=cell(n,1);
                                end
                                [st,e] = sap_wort(abschnitt,k(b-ksprung)-start+1);
                                if isnan(st)
                                    % Fehler bei der Interpretion, z.B.
                                    % Gleichheitszeichen im Text!
                                    ksprung = ksprung + 1;
                                    continue
                                else
                                    ksprung = 0;
                                    output.(ueberschrift){a,1} = abschnitt(st:e);
                                    if e > length(abschnitt)-1
                                        break
                                    end
                                    if strcmp(abschnitt(e+1),'"')
                                        e = e + 1;
                                    end
                                    while e < length(abschnitt) && isspace(abschnitt(e+1))
                                        e = e + 1;
                                    end
                                    start = e + start;
                                end
                            end
                        end
                        a = a+1;
                    end
                    
                    % Bis zu diesem Zeitpunkt alles durchgängiger Text!
                    % Postprocessing
                    % Prüfen auf gleiche Länge der einzelnen Cell-Vektoren
                    l = 0;
                    for ab = fieldnames(output)'
                        ab = ab{1};
                        l = max([l,length(output.(ab))]);
                    end
                    for ab = fieldnames(output)'
                        ab = ab{1};
                        if length(output.(ab)) < l
                            output.(ab)(end+1:l,1) = cell(l-length(output.(ab)),1);
                        end
                    end
                    % Speichern
                    output.name = table_name(2:end-1);
                    sheetData.(sheetName) = output;
                    if console; disp(['  Table sheet ''',sheetName,''' was read.']); end
                end
            end
        end
    case '' % Datenbank
        error('Not implemented! Use without cache!');
    otherwise
        error(['No info for files/databases of type ',ext,' available yet!']);
end
end

%% Sub-Funktionen

function [zeile,n] = subZeile(inh,n)
if n > length(inh)
    zeile = 0;
    return
end
zeile = inh{n};
n = n+1;
end

function [tline,n] = lese_sap_zeile_cell(inh,n)
tline = '';
while 1
    [zeile,n] = subZeile(inh,n);
    if isnumeric(zeile) || isempty(zeile)
        break
    end
    if strcmp(zeile(end),'_')
        tline = [tline zeile(1:end-1)];
        continue
    else
        tline = [tline zeile];
        break
    end
end
end

function tline = lese_sap_zeile(fid)
tline = '';
while 1
    zeile = fgetl(fid);
    if isnumeric(zeile) || isempty(zeile)
        break
    end
    if strcmp(zeile(end),'_')
        tline = [tline zeile(1:end-1)];
        continue
    else
        tline = [tline zeile];
        break
    end
end
end

function [st,e] = sap_wort(tline,k)
% Untersuchung nach dem Gleichhheitszeichen
if strcmp(tline(k+1),'"')
    e = strfind(tline,'"');
    if length(e) == 1
        % Sonderfall! Fehler
        st = NaN;
        e = NaN;
    else
        e = e(2)-1;
        st = 2 + k;
    end
else
    e = strfind(tline(k:end),' ');
    if isempty(e)
        e = length(tline);
    else
        e = e(1)+k-2;
    end
    st = 1 + k;
end
end
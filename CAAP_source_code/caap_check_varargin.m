function arg = caap_check_varargin(argin)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_check_varargin(argin)
%
%   Funktion zur Überprüfung der Eingabe Argumente
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% Verfahren vorbelegen
arg.info.procedure = 'standard';


%% varargin lesen
arg.info = sub_lese_varargin(argin.info,argin.info); % 1. Input-Argument: Eingabeparameter, 2. Input-Argument: Standardwerte (default-Parameter)
arg.comp = sub_lese_varargin(argin.ber); % 2. Input-Argument (Standardwerte) gibt es hier (noch) nicht


%% Prüfen, ob SAP2000-exe und Modell-File zur selben SAP2000-Versionsnummer korrespondieren
% Wird die 23er-Version zur Berechnung verwendet?
if contains(arg.info.sap_path,'23')
    % -> Fall: Die 23er-Version soll zum Rechnen verwendet werden.
    % Dann sollte die $2k-Datei auch mit der 23er-Version erstellt worden sein!
    % (erkennbar daran, dass unter TABLE:  "CASE - STATIC 4 - NONLINEAR PARAMETERS" der String "SolScheme" auftaucht)
    modell_tmp = caap_read_sap_file(arg.info.sap_file); % kurz das SAP-File einlesen und temporär zwischenspeichern
    if ~isfield(modell_tmp.Case0x2DStatic40x2DNonlinearParameters,'SolScheme') % Feld "SolScheme" suchen unter den nichtl. Parametern
        error('Obviously you want to calculate with the version 23 of SAP2000! Then the $2k file should also be created with version 23!')
    end
    clear modell_tmp % modell_tmp wieder löschen
else
    % -> Fall: Die 20er-Version soll zum Rechnen verwendet werden.
    % Dann sollte die $2k-Datei auch mit der 20er-Version erstellt worden sein!
    modell_tmp = caap_read_sap_file(arg.info.sap_file); % kurz das SAP-File einlesen und temporär zwischenspeichern
    if isfield(modell_tmp.Case0x2DStatic40x2DNonlinearParameters,'SolScheme') % Feld "SolScheme" suchen unter den nichtl. Parametern
        error('Obviously you want to calculate with the version 20 of SAP2000! Then the $2k file should also be created with version 20!')
    end
    clear modell_tmp % modell_tmp wieder löschen
end


%% Verfahren prüfen
if ~ist_typ(arg.info.procedure,'string')
    fprintf(2,'The "verf" argument is invalid!\n');
    arg.info.procedure = 'standard';
end
switch arg.info.procedure
    case {'standard','ami_c','ami_o'}
        % nichts zu tun
    otherwise
        fprintf(2,'The "%s" procedure is invalid!\n',arg.info.procedure);
        arg.info.procedure = 'standard';
end
name_temp = arg.info.procedure;


%% Vorbelegung allgemein
arg.info.export_file_name = 'Auto_Export';
arg.comp.nl_steps = [10 100];
arg.comp.d_tol = 0;
arg.comp.xi_0 = 5; % [%]
arg.info.console = 1;
arg.info.sound = 1;
arg.comp.push_load_ref = 'frames';


%% Vorbelegung in Abhängigkeit des Verfahrens
switch arg.info.procedure
    case 'standard'
        % Vorbelegung "standard":
        
        % Adaptive Berechnung: Nein
        arg.comp.adaptive = false;
        % Vollständig automatische Berechnung: Nein
        arg.comp.auto_run = false;
        
        % Lastverteilung
        arg.comp.load_pattern = 'mass';
        
        % Nachweisführung: Nein
        arg.comp.check = 0;

        % Ermittlung des Irregularitätsindizes "IRI": Nein
        arg.comp.iri = 0;
        
    case {'ami_c','ami_o'}
        % Vorbelegung "ami_c" bzw. "ami_o":
        
        % Adaptive Berechnung: Ja
        arg.comp.adaptive = true;
        % Vollständig automatische Berechnung: Ja
        arg.comp.auto_run = true;
        
        % Nachweisführung: Ja (Aber Frage stellt sich hier auch gar nicht!)
        arg.comp.check = 1;

        % Vorbelegung von Parametern, die NUR bei einer AMI-Berechnung
        % relevant sind
        arg.comp.k_loc = 0.9;
        arg.comp.k_glob = 0.9;
        arg.comp.algodec = false;
        arg.comp.dir_factor = [1 0.3 0.3];
end


%% varargin lesen
arg.comp = sub_lese_varargin(argin.ber,arg.comp);
arg.info.procedure = name_temp;
arg.info = sub_lese_varargin(argin.info,arg.info);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Erforderliche Argumente prüfen

% Strings zu Namen und Dateien prüfen
string_felder = {'sap_path','sap_file','name_vert','name_modal','name_pushover'};
for i_feld = 1:1:size(string_felder,2)
    if ~isfield(arg.info,string_felder{i_feld})
        error('Das Feld %s fehlt!', string_felder{i_feld})
    elseif ~ist_typ(arg.info.(string_felder{i_feld}),'string')
        error('The field "%s" does not contain a string!', string_felder{i_feld})
    end
end

% Dateien prüfen
file_felder = {'sap_path','sap_file'};
for i_feld = 1:1:size(file_felder,2)
    if ~isfile(arg.info.(string_felder{i_feld}))
        error('%s" is not a file!', arg.info.(string_felder{i_feld}))
    end
end

% "finish"-Status
if ~isfield(arg.info,'finish')
    arg.info.finish = 0;
end

% Instanz ggf. setzen
if ~isfield(arg.info,'instanz')
    arg.info.instanz = 1;
end

% Die Nummer der aktuellen Berechnung ermitteln
if ~isfield(arg.info,'nummer')
    arg.info.nummer = 1;
else
    arg.info.nummer = arg.info.nummer + 1;
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Optionale Argumente prüfen

% export_file_name
if ~ist_typ(arg.info.export_file_name,'string')
    fprintf(2,'The argument "export_file_name" is invalid!\n');
    arg.info.export_file_name = 'Auto_Export';
end
if arg.info.nummer == 1
    arg.info.export_file_name = strsplit(arg.info.export_file_name,'\');
    arg.info.export_file_name = arg.info.export_file_name{end};
    arg.info.export_file_name = strsplit(arg.info.export_file_name,'/');
    arg.info.export_file_name = arg.info.export_file_name{end};
    arg.info.export_file_name = [arg.info.export_file_name '.xml'];
    [folder, file_name, ~] = fileparts(arg.info.sap_file);
    arg.info.export_file = [folder '\' arg.info.export_file_name];
    
    % Pfad zum Logfile
    arg.info.log_file = [folder '\' file_name '.LOG'];
end

% Angaben zur optionalen Mailbenachrichtigung im Falle möglicher Fehler
% oder Eingabeaufforderungen
if isfield(arg.info,'mail')
    % Erstmal das Feld für den (immer gleichen) Betreff anlegen
    arg.info.mail.subject = 'CAAP-Tool: User input required';
    fieldnames_soll = {'mailadress','name','password','smtp_server'};
    for i_field = 1:length(fieldnames_soll)
        if ~isfield(arg.info.mail,fieldnames_soll{i_field})
            fprintf(2,['The specification of "',fieldnames_soll{i_field},'" for the automated mail notification is not available!\n',...
                       'As a result, there will be no e-mail notification!\n']);
            arg.info = rmfield(arg.info,'mail');
            break % for-Schleife abbrechen, denn arg.info.mail gibt es ja nun überhaupt nicht mehr
        end
    end
end

% nl_steps
if ~ist_typ(arg.comp.nl_steps,'array')
    fprintf(2,'The argument "nl_steps" is invalid!\n');
    arg.comp.nl_steps = [10 100];
else
    arg.comp.nl_steps = reshape(arg.comp.nl_steps,1,size(arg.comp.nl_steps,1)*size(arg.comp.nl_steps,2));
    arg.comp.nl_steps = abs(arg.comp.nl_steps);
    arg.comp.nl_steps = arg.comp.nl_steps(arg.comp.nl_steps ~= 0);
    if size(arg.comp.nl_steps,2) >= 2
        arg.comp.nl_steps = [min(arg.comp.nl_steps) max(arg.comp.nl_steps)];
    else
        arg.comp.nl_steps = [10 100];
    end
    
    if gleich(arg.comp.nl_steps(1),arg.comp.nl_steps(2))
        arg.comp.nl_steps = [10 100];
    end
end

% adaptive
switch arg.info.procedure
    case 'standard'
        if ~ist_typ(arg.comp.adaptive,'logical') && ~ist_typ(arg.comp.adaptive,'int')
            fprintf(2,'The argument "adaptive" is invalid! The following calculation will not be adaptive!\n');
            arg.comp.adaptive = false;
        elseif ist_typ(arg.comp.adaptive,'int') && arg.comp.adaptive ~= 0 && arg.comp.adaptive ~= 1
            fprintf(2,'The argument "adaptive" is invalid! The following calculation will not be adaptive!\n');
            arg.comp.adaptive = false;
        end
        
    case {'ami_c','ami_o'}
        if ist_typ(arg.comp.adaptive,'logical') && arg.comp.adaptive == false || ist_typ(arg.comp.adaptive,'int') && arg.comp.adaptive == 0
            fprintf(2,'A non-adaptive calculation according to the modified AMI method was probably desired, but this does not make sense! The calculation is now adaptive after all!\n');
            arg.comp.adaptive = true;
        end
end


if arg.comp.adaptive == 1
    
    % k_loc
    if ~ist_typ(arg.comp.k_loc,'zahl')
        fprintf(2,'The argument "k_loc" is invalid! It is now calculated with 0.9!\n');
        arg.comp.k_loc = 0.9;
    elseif arg.comp.k_loc < 0 || 1 < arg.comp.k_loc
        fprintf(2,'DThe argument "k_loc" is invalid! It is now calculated with 0.9!\n');
        arg.comp.k_loc = 0.9;
    end
    
    % k_glob
    if ~ist_typ(arg.comp.k_glob,'zahl')
        fprintf(2,'The argument "k_glob" is invalid! It is now calculated with 0.9!\n');
        arg.comp.k_glob = 0.9;
    elseif arg.comp.k_glob < 0 || 1 < arg.comp.k_glob
        fprintf(2,'The argument "k_glob" is invalid! It is now calculated with 0.9!\n');
        arg.comp.k_glob = 0.9;
    end

    % algodec
    if any(strcmp(arg.info.procedure,{'ami_c','ami_o'}))
        if ~ist_typ(arg.comp.algodec,'logical') && ~ist_typ(arg.comp.algodec,'int')
            fprintf(2,'The argument "algodec" is invalid! It is thus set to 0!\n');
            arg.comp.algodec = false;
        elseif ist_typ(arg.comp.adaptive,'int') && arg.comp.algodec ~= 0 && arg.comp.algodec ~= 1
            fprintf(2,'The argument "algodec" is invalid! It is thus set to 0!\n');
            arg.comp.algodec = false;
        end
    end
    
    % auto_run
    if ~ist_typ(arg.comp.auto_run,'logical') && ~ist_typ(arg.comp.auto_run,'int')
        % Festlegung je nach Verfahren
        switch arg.info.procedure
            case 'standard'
                fprintf(2,'The argument "auto_run" is invalid! The calculation is now not fully automatic, but manual!\n');
                arg.comp.auto_run = false;
            case {'ami_c','ami_o'}
                fprintf(2,'The argument "auto_run" is invalid! However, the calculation is still fully automatic, as this makes sense for the modified AMI procedure!\n');
                arg.comp.auto_run = true;
        end
    elseif ist_typ(arg.comp.auto_run,'int') && arg.comp.auto_run ~= 0 && arg.comp.auto_run ~= 1
        % Festlegung je nach Verfahren
        switch arg.info.procedure
            case 'standard'
                fprintf(2,'The argument "auto_run" is invalid! The calculation is now not fully automatic, but manual!\n');
                arg.comp.auto_run = false;
            case {'ami_c','ami_o'}
                fprintf(2,'The argument "auto_run" is invalid! However, the calculation is still fully automatic, as this makes sense for the modified AMI procedure!\n');
                arg.comp.auto_run = true;
        end
    elseif any(strcmp(arg.info.procedure,{'ami_c','ami_o'})) && arg.comp.auto_run == false
        fprintf(2,'A non-adaptive calculation should be carried out using the modified AMI method! However, the calculation is fully automatic, as this is the only sensible option for the modified AMI method!\n');
        arg.comp.auto_run = true;
    end
end

% console
if ~ist_typ(arg.info.console,'int')
    arg.info.console = 1;
elseif arg.info.console ~= 0 && arg.info.console ~= 1
    arg.info.console = 1;
end

% sound
if ~ist_typ(arg.info.sound,'int') || ~any(ismember([0 0.5 1],arg.info.sound))
    arg.info.sound = 1;
end
if arg.info.sound == 0.5 || arg.info.sound == 1 
    % Vorsichtshalber schonmal die Warnung "Unable to play audio..."
    % unterdrücken
    warning('off','MATLAB:audiovideo:audioplayer:noAudioOutputDevice') % Hinweis: Die Warning-ID hab ich mir über [MSG, MSGID] = lastwarn(); geholt, nachdem ich die Warnung über "hupe('zug')" provoziert hatte!
end

% push_load_ref
if ~ist_typ(arg.comp.push_load_ref,'string') || ~ismember(arg.comp.push_load_ref,{'frames','joints'})
    fprintf(2,'The argument "push_load_ref" is invalid and is therefore replaced by "frames"!\n');
    arg.comp.push_load_ref = 'frames';
end

% d_earthquake
if ~(arg.comp.auto_run == 1 && arg.info.nummer > 1)
    if ~ist_typ(arg.comp.d_earthquake,'string')
        error('The argument "d_earthquake" is invalid!')
    else
        d_earthquake_lokal = '';
        for i_d_earthquake = 1:1:size(arg.comp.d_earthquake,2)
            if ismember(lower(arg.comp.d_earthquake(i_d_earthquake)),{'x','y','z'})
                d_earthquake_lokal = [d_earthquake_lokal arg.comp.d_earthquake(i_d_earthquake)];
            end
        end
    end
    if exist('d_earthquake_lokal','var')
        if isempty(d_earthquake_lokal)
            error('The argument "d_earthquake" does not contain a valid earthquake direction!')
        else
            d_earthquake_lokal = unique(d_earthquake_lokal,'stable');
            arg.comp.d_earthquake = cell(1,size(d_earthquake_lokal,2));
            for i_d_earthquake = 1:1:size(d_earthquake_lokal,2)
                arg.comp.d_earthquake(1,i_d_earthquake) = {upper(d_earthquake_lokal(i_d_earthquake))};
            end
        end
    end
    for i_d_earthquake = 1:1:size(arg.comp.d_earthquake,2)
        switch arg.comp.d_earthquake{1,i_d_earthquake}
            case 'X'
                dir = 1;
            case 'Y'
                dir = 2;
            case 'Z'
                dir = 3;
        end
        arg.comp.d_earthquake(2,i_d_earthquake) = {dir};
    end
end

% xi_0 (Grundwert der Systemdämpfung)
if ~ist_typ(arg.comp.xi_0,'zahl')
    arg.comp.xi_0 = 5; % wenn ungültig definiert: xi_0 = 5 %
    fprintf(2,'Attention: The basic value of the system damping was defined incorrectly! It is now set to 5 percent!\n')
end


%% Verfahrensbedingte Argumente prüfen
switch arg.info.procedure
    case 'standard'
        
        % check (NW-Führung)
        if ~ist_typ(arg.comp.check,'int')
            arg.comp.check = 0;
        elseif arg.comp.check ~= 0 && arg.comp.check ~= 1
            arg.comp.check = 0;
        end
        
        % Irregularitätsindex "IRI" nur "ein Thema", wenn NW erwünscht &
        % KEINE ohnehin schon adaptive Berechnung durchgeführt wird
        if arg.comp.check == 1 && arg.comp.adaptive == false
            if ~ist_typ(arg.comp.iri,'int')
                arg.comp.iri = 0;
            elseif arg.comp.iri ~= 0 && arg.comp.iri ~= 1
                arg.comp.iri = 0;
            end
        else
            % Falls 'standard'-Pushover-Ber. OHNE NW UND/ODER ADAPTIV
            % durchgeführt wird: IRI-Ermittlung unterbinden
            arg.comp.iri = 0;
        end

        % varargin zum Antwortspektrum nur lesen, wenn NW erwünscht
        if arg.comp.check == 1
            arg.rs = sub_lese_varargin(argin.rs); % 2. Input-Argument (Standardwerte) gibt es hier nicht; Standardwerte werden in der Routine "aapa_el_accel_response_spectrum" selbst definiert
        end
        
        % load_pattern & mode
        if ~ist_typ(arg.comp.load_pattern,'string')
            fprintf(2,'The argument "load_pattern" is invalid!\n');
            arg.comp.load_pattern = 'mass';
        end
        
        % Flag für das Prüfen der Moden vordefinieren
        flag_check_modes = 0;
        
        switch arg.comp.load_pattern
            case 'mass'
                arg.comp.adaptive = false;
                arg.comp.auto_run = false;
                
                % In diesem Fall muss ein liegender Vektor
                % "arg.comp.VZ_Faktor" ([1 x n_Bebenrichtungen]) def. sein:
                if ~isfield(arg.comp,'sign_factors') || size(arg.comp.sign_factors,1) ~= 1 || size(arg.comp.sign_factors,2) ~= size(arg.comp.d_earthquake,2)
                    fprintf(2,'ATTENTION: The definition of the sign factors for the load distributions in the respective earthquake directions is missing or incorrect! The loads now act in pos. global coordinate directions!')
                    % In der Warnung beschriebene Definition in die Tat umsetzen
                    arg.comp.sign_factors = ones(1,size(arg.comp.d_earthquake,2));
                end
            
                if arg.comp.check == 1
                    flag_check_modes = 1;
                end
                
            case {'modal','mass_modal'}
                flag_check_modes = 1;
                
            otherwise
                fprintf(2,'The load distribution "%s" is invalid!\n',arg.comp.load_pattern);
                arg.comp.load_pattern = 'mass';
        end
        
        if flag_check_modes == 1
            if ~isfield(arg.comp,'modes')
                error('For the load distribution "%s", the specification of "modes" is required!', arg.comp.load_pattern)
            else
                arg = sub_check_modes(arg);
                
                modes_felder = fieldnames(arg.comp.modes);
                for i_feld = 1:1:size(modes_felder,1)
                    % Mit Feldern wie "unique", "gesamt", "changes" etc. soll nichts
                    % passieren, nur mit "X", "Y" und "Z"
                    if any(strcmp(modes_felder{i_feld},{'X','Y','Z'}))
                        if ~(ist_typ(arg.comp.modes.(modes_felder{i_feld}),'int') && arg.comp.modes.(modes_felder{i_feld}) ~= 0)
                            error('The specification for "modes" is invalid with regard to the %s direction!',modes_felder{i_feld})
                        end
                    end
                end
            end
        end
        
        % arg.comp.modes.unique und arg.comp.modes.gesamt anlegen (werden seit 08/2022 bzw. 08/2023 auch beim "Standard"-Pushover-Verfahren für Zwischenkontrollen in "check_eigenmodes" benötigt)
        arg.comp.modes.unique = [];
        arg.comp.modes.gesamt = [];
        for i_R = 1:size(arg.comp.d_earthquake,2)
            arg.comp.modes.unique = unique([arg.comp.modes.unique abs(arg.comp.modes.(arg.comp.d_earthquake{1,i_R}))],'stable');
            arg.comp.modes.gesamt = [arg.comp.modes.gesamt abs(arg.comp.modes.(arg.comp.d_earthquake{1,i_R}))];
        end

    case {'ami_c','ami_o'}
        
        % Antwortspektrum
        arg.rs = sub_lese_varargin(argin.rs); % 2. Input-Argument (Standardwerte) gibt es hier nicht; Standardwerte werden in der Routine "aapa_el_accel_response_spectrum" selbst definiert
        
        % im Fall des modifizierten AMI-Verfahrens mit konst. Spektralbeschl.-Inkrementen: DELTA S_a_B
        if strcmp(arg.info.procedure,'ami_c')
            % Fall: AMI-Verfahren mit konst. DELTA S_a_B
            if ~isfield(arg.comp,'delta_s_a_b') || ~ist_typ(arg.comp.delta_s_a_b,'zahl') || arg.comp.delta_s_a_b <= 0
                fprintf(2,'The specification of the (constant) spectral acceleration increment for the reference mode in the primary earthquake direction is missing or incorrect! It is now calculated with 0.01 m/s²!\n');
                arg.comp.delta_s_a_b = 0.01; % [m/s²]
            end
        end
        
        % modes & modes_dir_protected
        % => Nach dem neusten Stand DÜRFEN die Moden NUR AM ANFANG
        % (VOR dem allerersten Berechnungsdurchlauf) EINMALIG definiert
        % werden, danach wird intern gewährleistet, dass Richtung und
        % Mode-Zuordnung (Stichwort frequency shifting) konstant bleiben.
        % DAHER NUR GANZ AM ANFANG einmal prüfen UND "arg.comp.modes.gesamt"
        % AUFBAUEN UND die "uniquen Beträge" AN "arg.comp.modes.unique" übergeben:
        if arg.info.nummer == 1
            if ~isfield(arg.comp,'modes')
                error('In case of the modified AMI procedure, the specification of "modes" is required!')
            else
                arg = sub_check_modes(arg);
                
                modes_felder = fieldnames(arg.comp.modes);
                
                arg.comp.modes.gesamt = [];
                for i_feld = 1:1:size(modes_felder,1)
                    % Mit Feldern wie "unique", "gesamt", "changes" etc. soll nichts
                    % passieren, nur mit "X", "Y" und "Z"
                    if any(strcmp(modes_felder{i_feld},{'X','Y','Z'}))
                        % Fall: Das aktuelle Feld ist ein tats. Richtungs-Feld
                        if ~(ist_typ(arg.comp.modes.(modes_felder{i_feld}),'array') || ist_typ(arg.comp.modes.(modes_felder{i_feld}),'int'))
                            error('The definition of "modes" is invalid!')
                        else
                            arg.comp.modes.(modes_felder{i_feld}) = ...
                                reshape(arg.comp.modes.(modes_felder{i_feld}),1, ...
                                size(arg.comp.modes.(modes_felder{i_feld}),1)*size(arg.comp.modes.(modes_felder{i_feld}),2));
                            
                            for i_mode = size(arg.comp.modes.(modes_felder{i_feld}),2):-1:1
                                if ~(ist_typ(arg.comp.modes.(modes_felder{i_feld})(i_mode),'int') && arg.comp.modes.(modes_felder{i_feld})(i_mode) ~= 0)
                                    arg.comp.modes.(modes_felder{i_feld})(i_mode) = [];
                                end
                            end
                            if size(arg.comp.modes.(modes_felder{i_feld}),2) == 0
                                error('The specification for "modes" is invalid with regard to the %s direction!',modes_felder{i_feld})
                            end
                        end
                        arg.comp.modes.gesamt = [arg.comp.modes.gesamt,arg.comp.modes.(modes_felder{i_feld})];
                    end
                end
            end
            % "arg.comp.modes.gesamt" hier (arg.info.nummer == 1) EINMALIG
            % als initialen "Stand" an "arg.comp.modes.gesamt_initial"
            % übergeben, da "arg.comp.modes.gesamt" ggf. später programmintern
            % angepasst wird bei entspr. VZ-wechseln der Eigenformen oder im
            % Fall von mode changeses:
            arg.comp.modes.gesamt_initial = arg.comp.modes.gesamt;
            % Außerdem die "uniquen Beträge" von arg.comp.modes.gesamt in 
            % "arg.comp.modes.unique" speichern (gibt Überblick darüber,
            % welche Modalformen überhaupt berücksichtigt werden, Richtungs-
            % und VZ-unabhängig!!!)
            arg.comp.modes.unique = unique(abs(arg.comp.modes.gesamt),'stable');
            % << Kurze Zwischenüberprüfung, ob - wenn (mind.) ein Mode in
            %    (mind.) zwei Richtungen angesetzt wurde - dieser auch
            %    wirklich mit demselben VZ angesetzt wurde:
            if length(unique(abs(arg.comp.modes.gesamt_initial),'stable')) ~= length(abs(unique(arg.comp.modes.gesamt_initial,'stable')))
                error('A certain mode may be considered in different directions at the same time, but not with different signs, as this would have an exonerating effect!')
            end

            % modes_dir_protected
            if isfield(arg.comp,'modes_dir_protected')
                if ~ist_typ(arg.comp.modes_dir_protected,'array') && ~ist_typ(arg.comp.modes_dir_protected,'int')
                    error('The specification of the directionally protected modes is incorrect!')
                else
                    % In arg.comp.modes "einsortieren" 
                    % (Nur dort nicht direkt bei der Eingabe angelegt, da man so als Eingabe wirklich nur die
                    %  Bebenrichtungen als Felder von arg.comp.modes hat!
                    %  -> Finde ich auf Benutzerebene stringenter, jetzt (was wir hier programmintern treiben)
                    %     können wir ja machen, was wir wollen!!!)
                    arg.comp.modes.dir_protected = abs(arg.comp.modes_dir_protected); % sicherheitshalber nochmal ein "abs()" drauf gepackt, falls der Benutzer doch (fälschlicherweise) hier ein VZ mitgegeben hat
                    arg.comp = rmfield(arg.comp,'modes_dir_protected');
                end
            end
        end    
end


%% Finale formale Überprüfungen
% Richtungsfaktoren
if ~ist_typ(arg.comp.dir_factor,'array') && ~ist_typ(arg.comp.dir_factor,'zahl')
    arg.comp.dir_factor = [1 0.3 0.3];
else
    arg.comp.dir_factor = reshape(arg.comp.dir_factor,1,size(arg.comp.dir_factor,1)*size(arg.comp.dir_factor,2));
end

% d_earthquake
if size(arg.comp.d_earthquake,2) == 1 && isempty(arg.comp.dir_factor)
    arg.comp.dir_factor = 1;
elseif size(arg.comp.dir_factor,2) < size(arg.comp.d_earthquake,2)
    error('There is too little information in the "dir_factor" specification!')
else
    arg.comp.dir_factor = arg.comp.dir_factor(1:size(arg.comp.d_earthquake,2));
end

end


%% Sub-Funktionen

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Lese argin
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function argumente = sub_lese_varargin(argin,standardwerte,ignoreEmpty)
% lese_varargin(argin,standardwerte,leerIgnorieren)
%
% Parsen von Eingabeargumenten:
% - als Cellaray: {'name','wert',...}
% - als Struktur
% - als Struktur in einer Zelle {struct(...)}
% - als Text: fe_pl_xxx(..,'name','wert',...)
% - als Text: 'struct('name','wert',...)
%
% Dabei werden nicht vorhandene Werte aus den Standardwerten in
% "standardwerte" (Struktur) übernommen
%
% Zusatzschalter: ignoreEmpty: Standard: 0, wenn gesetzt werden leere
%                              Eingabefelder durch die Standardwerte überschrieben

if nargin < 3
    ignoreEmpty = 0;
end

if nargin < 2 || isempty(standardwerte)
    % Keine Standardwerte
    standardwerte = struct();
else
    % alle Eingeben sind immer lowercase, insofern Standardwerte auch
    % --> Wenn diese Zeile Problem macht, konnte schon vorher kein Benutzer
    % jemals den betreffenden Wert ändern!
    standardwerte = struct_lower(standardwerte);
end

if iscell(argin) && length(argin)~=1
    % Standardfall, gilt auch für leere varargin
    if mod(length(argin),2)
        error('The input contains an odd number of arguments! Always specify pairs of property and value!');
    else
        % Einspeichern der neuen Werte
        for iarg=1:2:size(argin,2)
            if ~ischar(argin{iarg})
                error('The input contains an incorrect property definition!');
            end
            if ~ignoreEmpty || ~isempty(argin{iarg+1})
                standardwerte.(lower(argin{iarg}))=argin{iarg+1};
            end
        end
        % Umspeichern für Ausgabe
        argumente = standardwerte;
    end
elseif isstruct(argin)
    % dann kurz Felder löschen, die groß geschrieben sind und ein
    % komplett klein geschriebenes Partner-Feld haben
    % (groß geschriebene kommen dann aus Skript, klein geschriebene aus
    % letztem Funktionsdurchlauf -> aktuellere Informationen!!!)
    argin = sub_delete_doppelte_felder(argin);
    % jetzt können alle Feldnamen komplett klein geschrieben werden ohne
    % Konflikte
    argin = struct_lower(argin);
    argumente = struct_add(standardwerte,argin);
elseif length(argin) == 1
    % Struktur innerhalb einer Zelle
    if isstruct(argin{1})
        argin = struct_lower(argin{1});
        argumente = struct_add(standardwerte,argin);
    elseif isempty(argin{1})
        argumente = standardwerte;
    else
        error('The input contains an incorrect property definition!');
    end
elseif ischar(argin) && ~isempty(argin)
    test = strfind(argin,'struct');
    if isempty(test)
        % wahrscheinlich Dummy-Aufruf, zerlegen
        % Suchen des ersten Hochkommas
        test = strfind(argin,'''');
        if isempty(test)
            msgbox('View information cannot be processed!');
        end
        befehl = argin(test(1):end);
        % Letzte Klammer
        test = strfind(befehl,')');
        if ~isempty(test)
            befehl = befehl(1:test(end)-1);
        end
        % Struct Aufruf
        befehl = ['struct(' befehl ')'];
    else
        befehl = argin;
    end
    % Leise Ausführung
    if ~strcmp(befehl(end),';')
        befehl = [befehl ';'];
    end
    % Ausgabe-Variable
    befehl = ['argumente = ' befehl];
    % Ausführen
    eval(befehl);
    % Standardwerte verwenden
    argumente = struct_add(standardwerte,argumente);
elseif isempty(argin)
    % Leere Menge, Standardwerte verwenden
    argumente = standardwerte;
else
    error('argin must be either a CellArray or a struct!');
end
end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Lösche Felder mit Namen "FELD" / "Feld", die schon als "feld" vorliegen
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function argin = sub_delete_doppelte_felder(argin)
% Feldnamen der aktuellen Struktur auslesen
feldnamen = fieldnames(argin);

% Schleife über alle Feldnamen
for i_feld = 1:length(feldnamen)
    % Als erstes prüfen, ob der aktuelle Feldname überhaupt Großbuchstaben
    % enthält (dann ist es ein potenziell zu löschendes Feld und sonst eben
    % uninteressant):
    if ~strcmp(feldnamen{i_feld},lower(feldnamen{i_feld}))
        % Wenn nun zwei Stellen gefunden werden, wo das aktuelle Feld unter
        % Vernachlässigung der Groß- & Kleinschreibung (genau das macht die
        % "strcmpi"-Fkt.) vorliegt, dann muss es einen klein geschriebenen
        % Partner zu dem (auf jeden Fall gem. der 1. Prüfung mit Großbuch-
        % staben bestückten) aktuellen Feldnamen geben
        idx_partner_potenziell = find(strcmpi(feldnamen,feldnamen{i_feld})); % "strcmpi" = "strcmp(...,lower(...))"
        % Prüfen, ob es wirklich ein Pärchen ist oder nicht
        if length(idx_partner_potenziell) == 2
            % Fall: Es liegt wirklich ein klein geschriebener Partner zu
            % dem aktuellen Feldnamen vor
            % => Dann das AKTUELL betrachtete Feld löschen, denn ein groß
            % geschriebenes kommt bei einem zweiten Funktionsdurchlauf
            % wieder aus dem Skript, das klein geschriebene wohl eher aus
            % dem Output eines vorherigen Berechnungsdurchlaufs (und dann
            % brauchen wir im Folgenden diesen Inhalt!)
            argin = rmfield(argin,feldnamen{i_feld});
        end
    end
end

end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Prüfe arg.comp.modes
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function arg = sub_check_modes(arg)
% Kurze Zwischenüberprüfung: Wenn ich arg.comp.modes.x, arg.comp.modes.y ... auf
% Skriptebene definierte habe (sprich: die Richtungsangaben klein), kann es
% sein, dass zus. arg.comp.modes.X, arg.comp.modes.Y ... aus einem vorherigen
% Berechnungsschritt (durch die programminterne Großschreibung) vorliegen:
% -> Maßgebend sind dann natürlich die klein geschriebenen, neu im Skript
% definierten Moden!
% (Bei Großschreibung im Skript werden die Mode-Angaben eines vorherigen
% Berechnungsschrittes in jedem Fall überschrieben, dann ist eh alles gut.)
arg.comp.modes = sub_delete_doppelte_felder(arg.comp.modes);
% Nun kann die eigentliche Überprüfung erfolgen, ob nämlich zu jeder in
% "arg.comp.d_earthquake" def. Richtung entspr. Moden angegeben wurden.
modes_felder = fieldnames(arg.comp.modes);

% Fall: "Standard"-Pushover-Verfahren und rein massenmodale
% Lastverteilung (Basismode wird nur für Pushover-Kurven-Trafo benötigt)
if strcmp(arg.info.procedure,'standard') && strcmp(arg.comp.load_pattern,'mass')
    if ismember(arg.comp.d_earthquake{1,1},modes_felder)
        sub_modes.(arg.comp.d_earthquake{1,1}) = arg.comp.modes.(arg.comp.d_earthquake{1,1});
    elseif ismember(lower(arg.comp.d_earthquake{1,1}),modes_felder)
        sub_modes.(arg.comp.d_earthquake{1,1}) = arg.comp.modes.(lower(arg.comp.d_earthquake{1,1}));
    else
        error('No natural mode for the transformation was specified for the earthquake direction %s!',arg.comp.d_earthquake{1,1})
    end
% In allen anderen Fällen:
else
    for i_dir = 1:1:size(arg.comp.d_earthquake,2)
        if ismember(arg.comp.d_earthquake{1,i_dir},modes_felder)
            sub_modes.(arg.comp.d_earthquake{1,i_dir}) = arg.comp.modes.(arg.comp.d_earthquake{1,i_dir});
        elseif ismember(lower(arg.comp.d_earthquake{1,i_dir}),modes_felder)
            sub_modes.(arg.comp.d_earthquake{1,i_dir}) = arg.comp.modes.(lower(arg.comp.d_earthquake{1,i_dir}));
        elseif ~(strcmp(arg.info.procedure,'standard') && strcmp(arg.comp.load_pattern,'mass'))
            error('No natural modes were specified for the earthquake direction %s!',arg.comp.d_earthquake{1,i_dir})
        end
    end
    % Im Fall des AMI-Verfahrens (mit konstanten oder optimierten DELTA S_a_B):
    if any(strcmp(arg.info.procedure,{'ami_c','ami_o'}))
        % Zusätzlich bei späteren Berechnungsdurchläufen "arg.comp.modes.unique"
        % (Vektor der "uniquen" Mode-Nummern aus dem ersten Durchlauf) sowie 
        % "arg.comp.modes.gesamt_initial" (VZ-gerechte "Aneinanderreihung von
        % arg.comp.modes.Rp, arg.comp.modes.Rs ...) und "arg.comp.modes.massenanteile_massg_neu"
        % merken
        if arg.info.nummer ~= 1
            sub_modes.unique = arg.comp.modes.unique;
            sub_modes.gesamt_initial = arg.comp.modes.gesamt_initial;
            sub_modes.massenanteile_massg_neu = arg.comp.modes.massenanteile_massg_neu;
        end
    end
    % Zusätzlich in allen Fällen ("standard" & "ami_c" bzw. "ami_o"):
    % "arg.comp.kontrollinfos_initial" merken
    if arg.info.nummer ~= 1
        sub_modes.kontrollinfos_initial = arg.comp.modes.kontrollinfos_initial;
    end
    % Falls vorhanden: Feld "comp.modes.changes" merken
    if isfield(arg.comp.modes,'changes')
        sub_modes.changes = arg.comp.modes.changes;
    end
end
% Dann arg.comp.modes(alt) löschen...
arg.comp = rmfield(arg.comp,'modes');
% ... und neu bestücken... Dabei werden jetzt die Richtungsfelder in
% arg.comp.modes groß geschrieben, wie die Angaben in arg.comp.d_earthquake
arg.comp.modes = sub_modes;
end

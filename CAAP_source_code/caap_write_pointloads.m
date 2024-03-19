function modell = caap_write_pointloads(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   modell = caap_write_pointloads(modell,arg)
%   
%   Funktion zum Schreiben der Lastverteilung
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% Aktuelle Kraftkomponenten-Matrix auslesen
F = arg.comp.f_matrix_akt;


%% Definition der Punktlasten je nach Bezug ('frames' oder 'joints')
%% FALL 1: Punktlasten sollen auf die 'frames' bezogen definiert werden (dabei werden ALLE System- UND FE-Knoten belastet; allerdings dürfen im System auch NUR 'frame'-Elemente vorhanden sein!)
if strcmp(arg.comp.push_load_ref,'frames')

    % * Zwischenschritt: Erweiterte Zeilenanzahl ermitteln *
    % Anzahl neuer Zeilen (die hinzukommen)
    n_neu = size(F,1)*size(F,2);

    % * Prüfen, ob es schon Punktlasten gibt *
    if isfield(modell,'FrameLoads0x2DPoint')
        % => Vorarbeit:
        % Anzahl bisheriger Zeilen
        n_alt = size(modell.FrameLoads0x2DPoint.AbsDist,1);
        % Neue Gesamtzeilenanzahl: alt + neu
        n = n_alt + n_neu;
        % Feldnamen (Attribute) von "modell.FrameLoads0x2DPoint" auslesen
        ATTRIBUTE = fieldnames(modell.FrameLoads0x2DPoint);
        % => Alle Sub-Felder von "modell.FrameLoads0x2DPoint" bis auf "name" entsprechend erweitern
        % -> Erstmal alle "allgemeinen" (d. h. ZEILEN- bzw. KNOTENUNABHÄNGIGEN) Informationen hinterlegen
        for i_attribut = 1:size(ATTRIBUTE,1)
            if ~strcmp(ATTRIBUTE{i_attribut},'name') % der Name bleibt natürlich unverändert
                % Bisherige Daten merken
                alte_werte = modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut});
                % Vorbelegung mit Cell-Array der Dim. [nx1]
                modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut}) = cell(n,1);
                % Bisherige Daten wieder eintragen
                modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(1:n_alt,1) = alte_werte;
                % Dann bezüglich der neuen Daten erstmal nur die "allgemeinen" (d. h. ZEILENUNABHÄNGIGEN) Informationen hinterlegen
                switch ATTRIBUTE{i_attribut}
                    case 'LoadPat'
                        modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {arg.info.name_pushover_old};
                    case 'CoordSys'
                        modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {'GLOBAL'};
                    case 'Type'
                        modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {'FORCE'};
                    case 'DistType'
                        modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {'RelDist'};
                    otherwise
                        modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {''};
                end
            end
        end
        % -> Anschließend alle "konkreten" (d. h. ZEILEN- bzw. KNOTENABHÄNGIGEN) Informationen hinterlegen
        % Zwischenschritt: Vorbelegungen für den Zeilenindex und die kartesischen Koordinatenrichtungen
        line_counter = n_alt+1;
        richtungen = {'X','Y','Z'};
        % Schleife über alle Zeilen der F-Matrix
        for i_value = 1:size(F,1)
            % Untergeordnete Schleife über alle kartesischen Koordinatenrichtungen
            for i_richtung = 1:3
                % Lastordinaten nur auswerten, wenn nicht NaN
                if ~isnan(F(i_value,i_richtung))
                    % Knotenlabel eintragen
                    modell.FrameLoads0x2DPoint.Frame(line_counter,1) = {num2str(arg.comp.joint_lastverteilung.Werte{i_value,5})};
                    % Lastrichtung eintragen
                    modell.FrameLoads0x2DPoint.Dir(line_counter,1) = richtungen(i_richtung);
                    % Relative Distanz (des akt. Knotens im zugehörigen Balkenelement) eintragen
                    modell.FrameLoads0x2DPoint.RelDist(line_counter,1) = {strrep(num2str(arg.comp.joint_lastverteilung.Werte{i_value,6}),'.',',')};
                    % Absolute Distanz (des akt. Knotens im zugehörigen Balkenelement) eintragen
                    modell.FrameLoads0x2DPoint.AbsDist(line_counter,1) = {strrep(num2str(arg.comp.joint_lastverteilung.Werte{i_value,7}),'.',',')};
                    % Knotenlast eintragen
                    modell.FrameLoads0x2DPoint.Force(line_counter,1) = {num2str(F(i_value,i_richtung))};
                    % Nächste Zeile ansteuern
                    line_counter = line_counter + 1;
                end
            end
        end
        % -> Und ferner eventuell weitere vorhandene Zeilen (innerhalb der Subfelder zu allen Attributen) löschen
        % Feldnamen (Attribute) von "modell.FrameLoads0x2DPoint" neu auslesen
        ATTRIBUTE = fieldnames(modell.FrameLoads0x2DPoint); % ERFORDERLICH?????????? HAT SICH DAS GEÄNDERT IM VERGLEICH ZU OBEN?????????????????????????????????????????????????????
        % Schleife über alle Feldnamen (Attribute) von "modell.FrameLoads0x2DPoint"
        for i_attribut = 1:size(ATTRIBUTE,1)
            if ~strcmp(ATTRIBUTE{i_attribut},'name') % der Name bleibt natürlich unverändert
                % Zeilen, die über die bisherigen und neuen Daten hinausgehen, leeren
                modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(line_counter:end) = [];
            end
        end
        
    % * Ansonsten: Entspr. Felder anlegen *
    else
        % => Vorarbeit:
        % Feldnamen (Attribute) erstmal "frei" definieren (zunächst bis auf "GUID" und "name")
        ATTRIBUTE = {'LoadPat';'CoordSys';'Type';'DistType';'Frame';'Dir';'RelDist';'AbsDist';'Force'};
        % Nun alle obigen Felder in "modell"-Strukturfeld "FrameLoads0x2DPoint" anlegen
        % => Alle Sub-Felder von "modell.FrameLoads0x2DPoint" entsprechend anlegen und füllen
        % -> Erstmal alle "allgemeinen" (d. h. ZEILEN- bzw. KNOTENUNABHÄNGIGEN) Informationen hinterlegen
        for i_attribut = 1:size(ATTRIBUTE,1)
            % Vorbelegung
            modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut}) = cell(n_neu,1);
            % Dann mit Inhalt füllen
            switch ATTRIBUTE{i_attribut}
                case 'LoadPat'
                    modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(1:end,1) = {arg.info.name_pushover_old};
                case 'CoordSys'
                    modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(1:end,1) = {'GLOBAL'};
                case 'Type'
                    modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(1:end,1) = {'FORCE'};
                case 'DistType'
                    modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(1:end,1) = {'RelDist'};
                otherwise
                    modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(1:end,1) = {''};
            end
        end
        % -> Anschließend alle "konkreten" (d. h. ZEILEN- bzw. KNOTENABHÄNGIGEN) Informationen hinterlegen
        % Zwischenschritt: Vorbelegungen für den Zeilenindex und die kartesischen Koordinatenrichtungen
        line_counter = 1;
        richtungen = {'X','Y','Z'};
        % Schleife über alle Zeilen der F-Matrix
        for i_value = 1:size(F,1)
            % Untergeordnete Schleife über alle kartesischen Koordinatenrichtungen
            for i_richtung = 1:3
                % Lastordinate nur auswerten, wenn "groß genug" (nicht praktisch 0)
                if abs(F(i_value,i_richtung)) > 10e-6
                    % Knotenlabel eintragen
                    modell.FrameLoads0x2DPoint.Frame(line_counter,1) = {num2str(arg.comp.joint_lastverteilung.Werte{i_value,5})};
                    % Lastrichtung eintragen
                    modell.FrameLoads0x2DPoint.Dir(line_counter,1) = richtungen(i_richtung);
                    % Relative Distanz (des akt. Knotens im zugehörigen Balkenelement) eintragen
                    modell.FrameLoads0x2DPoint.RelDist(line_counter,1) = {strrep(num2str(arg.comp.joint_lastverteilung.Werte{i_value,6}),'.',',')};
                    % Absolute Distanz (des akt. Knotens im zugehörigen Balkenelement) eintragen
                    modell.FrameLoads0x2DPoint.AbsDist(line_counter,1) = {strrep(num2str(arg.comp.joint_lastverteilung.Werte{i_value,7}),'.',',')};
                    % Knotenlast eintragen
                    modell.FrameLoads0x2DPoint.Force(line_counter,1) = {num2str(F(i_value,i_richtung))};
                    % Nächste Zeile ansteuern
                    line_counter = line_counter + 1;
                end
            end
        end
        % -> Und ferner eventuell weitere vorhandene Zeilen (innerhalb der Subfelder zu allen Attributen) löschen
        % Feldnamen (Attribute) von "modell.FrameLoads0x2DPoint" neu auslesen
        ATTRIBUTE = fieldnames(modell.FrameLoads0x2DPoint); % ERFORDERLICH?????????? HAT SICH DAS GEÄNDERT IM VERGLEICH ZU OBEN?????????????????????????????????????????????????????
        for i_attribut = 1:size(ATTRIBUTE,1)
            % Zeilen, die über die bisherigen und neuen Daten hinausgehen, leeren
            modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(line_counter:end) = [];
        end
        % -> Abschließend den Tabellennamen angeben
        modell.FrameLoads0x2DPoint.name = 'FRAME LOADS - POINT';
    end

%% FALL 2: Punktlasten sollen auf die 'joints' bezogen definiert werden (dabei werden ALLE Systemknoten belastet, unabhängig vom zugehörigen Elementtyp; allerdings werden FE-Knoten hierbei ignoriert!)
else
    % Voruntersuchung: Sicherheitskontrolle, ob es (entgegen der Angabe in
    % der Doku) DOCH reine FE-KNOTEN im System gibt im Falle der Wahl von
    % "arg.comp.push_load_ref" = 'joints'
    if ismember(1,cell2mat(strfind(arg.comp.joint_lastverteilung.Werte(:,1),'~')))
        % Berechnung abbrechen, da es sonst in SAP2000 zu einem Absturz käme,
        % da die F-Matrix mehr Lasten hat, als es reine Systemknoten gibt
        % und sich die Lastdefinition bei der hier gewählten Variante dann
        % "verschluckt"
        error('There are FE nodes in the system, which is not permitted when deciding on system node-related pushover loads.')
    end
    
    % * Zwischenschritt: Erweiterte Zeilenanzahl ermitteln *
    % Anzahl neuer Zeilen (die hinzukommen)
    n_neu = size(F,1);

    % * Prüfen, ob es schon Punktlasten gibt *
    if isfield(modell,'JointLoads0x2DForce')
        % => Vorarbeit:
        % Anzahl bisheriger Zeilen
        n_alt = size(modell.JointLoads0x2DForce.Joint,1);
        % Neue Gesamtzeilenanzahl: alt + neu
        n = n_alt + n_neu;
        % Feldnamen (Attribute) von "modell.JointLoads0x2DForce" auslesen
        ATTRIBUTE = fieldnames(modell.JointLoads0x2DForce);
        % => Alle Sub-Felder von "modell.JointLoads0x2DForce" bis auf "name" entsprechend erweitern
        % -> Erstmal alle "allgemeinen" (d. h. ZEILEN- bzw. KNOTENUNABHÄNGIGEN) Informationen hinterlegen
        for i_attribut = 1:size(ATTRIBUTE,1)
            if ~strcmp(ATTRIBUTE{i_attribut},'name') % der Name bleibt natürlich unverändert
                % Bisherige Daten merken
                alte_werte = modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut});
                % Vorbelegung mit Cell-Array der Dim. [nx1]
                modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut}) = cell(n,1);
                % Bisherige Daten wieder eintragen
                modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(1:n_alt,1) = alte_werte;
                % Dann bezüglich der neuen Daten erstmal nur die "allgemeinen" (d. h. ZEILENUNABHÄNGIGEN) Informationen hinterlegen
                switch ATTRIBUTE{i_attribut}
                    case 'LoadPat'
                        modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {arg.info.name_pushover_old};
                    case 'CoordSys'
                        modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {'GLOBAL'};
                    otherwise
                        modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(n_alt+1:end,1) = {''};
                end
            end
        end
        % -> Anschließend alle "konkreten" (d. h. ZEILEN- bzw. KNOTENABHÄNGIGEN) Informationen hinterlegen
        % Schleife über alle Zeilen der F-Matrix
        for i_value = 1:size(F,1)
            % Untergeordnete Schleife über alle kartesischen Koordinatenrichtungen
            for i_richtung = 1:3
                % Knotenlabel eintragen
                modell.JointLoads0x2DForce.Joint(n_alt+i_value,1) = {num2str(arg.comp.joint_lastverteilung.Werte{i_value,1})};
                % Lastkomponente eintragen, wenn nicht NaN
                if ~isnan(F(i_value,i_richtung))
                    modell.JointLoads0x2DForce.(['F',num2str(i_richtung)])(n_alt+i_value,1) = {num2str(F(i_value,i_richtung))};
                % Sonst einfach eine "0"-Last eintragen (man sollte/muss hier aber im Ggs. zu den frame-Zuweisungen was eintragen, denn es gibt die Zeile zu dem Knoten ja trotzdem aufgrund der weiteren Lastkomponenten)
                else
                    modell.JointLoads0x2DForce.(['F',num2str(i_richtung)])(n_alt+i_value,1) = {'0'};
                end
            end
            % Momente in allen drei kartesischen Koordinaten werden nicht
            % definiert, sind also alle = 0!
            modell.JointLoads0x2DForce.M1(n_alt+i_value,1) = {'0'};
            modell.JointLoads0x2DForce.M2(n_alt+i_value,1) = {'0'};
            modell.JointLoads0x2DForce.M3(n_alt+i_value,1) = {'0'};
        end
        % -> Und ferner eventuell weitere vorhandene Zeilen (innerhalb der Subfelder zu allen Attributen) löschen
        % Feldnamen (Attribute) von "modell.JointLoads0x2DForce" neu auslesen
        ATTRIBUTE = fieldnames(modell.JointLoads0x2DForce); % ERFORDERLICH?????????? HAT SICH DAS GEÄNDERT IM VERGLEICH ZU OBEN?????????????????????????????????????????????????????
        % Schleife über alle Feldnamen (Attribute) von "modell.JointLoads0x2DForce"
        for i_attribut = 1:size(ATTRIBUTE,1)
            if ~strcmp(ATTRIBUTE{i_attribut},'name') % der Name bleibt natürlich unverändert
                % Zeilen, die über die bisherigen und neuen Daten hinausgehen, leeren
                modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(n+1:end) = [];
            end
        end
        
    % * Ansonsten: Entspr. Felder anlegen *
    else
        % => Vorarbeit:
        % Feldnamen (Attribute) erstmal "frei" definieren (zunächst bis auf "GUID" und "name")
        ATTRIBUTE = {'LoadPat';'CoordSys';'Joint';'F1';'F2';'F3';'M1';'M2';'M3'};
        % Nun alle obigen Felder in "modell"-Strukturfeld "JointLoads0x2DForce" anlegen
        % => Alle Sub-Felder von "modell.JointLoads0x2DForce" entsprechend anlegen und füllen
        % -> Erstmal alle "allgemeinen" (d. h. ZEILEN- bzw. KNOTENUNABHÄNGIGEN) Informationen hinterlegen
        for i_attribut = 1:size(ATTRIBUTE,1)
            % Vorbelegung
            modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut}) = cell(n_neu,1);
            % Dann mit Inhalt füllen
            switch ATTRIBUTE{i_attribut}
                case 'LoadPat'
                    modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(1:end,1) = {arg.info.name_pushover_old};
                case 'CoordSys'
                    modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(1:end,1) = {'GLOBAL'};
                otherwise
                    modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(1:end,1) = {''};
            end
        end
        % -> Anschließend alle "konkreten" (d. h. ZEILEN- bzw. KNOTENABHÄNGIGEN) Informationen hinterlegen
        % Schleife über alle Zeilen der F-Matrix
        for i_value = 1:size(F,1)
            % Untergeordnete Schleife über alle kartesischen Koordinatenrichtungen
            for i_richtung = 1:3
                % Knotenlabel eintragen
                modell.JointLoads0x2DForce.Joint(i_value,1) = {num2str(arg.comp.joint_lastverteilung.Werte{i_value,1})};
                % Lastordinate nur auswerten, wenn "groß genug" (nicht praktisch 0)
                if abs(F(i_value,i_richtung)) > 10e-6
                    modell.JointLoads0x2DForce.(['F',num2str(i_richtung)])(i_value,1) = {num2str(F(i_value,i_richtung))};
                % Sonst einfach eine "0"-Last eintragen (man sollte/muss hier aber im Ggs. zu den frame-Zuweisungen was eintragen, denn es gibt die Zeile zu dem Knoten ja trotzdem aufgrund der weiteren Lastkomponenten)
                else
                    modell.JointLoads0x2DForce.(['F',num2str(i_richtung)])(i_value,1) = {'0'};
                end
            end
            % Momente in allen drei kartesischen Koordinaten werden nicht
            % definiert, sind also alle = 0!
            modell.JointLoads0x2DForce.M1(i_value,1) = {'0'};
            modell.JointLoads0x2DForce.M2(i_value,1) = {'0'};
            modell.JointLoads0x2DForce.M3(i_value,1) = {'0'};
        end
        % -> Und ferner eventuell weitere vorhandene Zeilen (innerhalb der Subfelder zu allen Attributen) löschen
        % Feldnamen (Attribute) von "modell.JointLoads0x2DForce" neu auslesen
        ATTRIBUTE = fieldnames(modell.JointLoads0x2DForce); % ERFORDERLICH?????????? HAT SICH DAS GEÄNDERT IM VERGLEICH ZU OBEN?????????????????????????????????????????????????????
        for i_attribut = 1:size(ATTRIBUTE,1)
            % Zeilen, die über die bisherigen und neuen Daten hinausgehen, leeren
            modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(n_neu+1:end) = [];
        end
        % -> Abschließend den Tabellennamen angeben
        modell.JointLoads0x2DForce.name = 'JOINT LOADS - FORCE';
    end


end

end

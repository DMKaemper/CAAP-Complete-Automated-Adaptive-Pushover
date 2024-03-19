function modell = caap_delete_pointloads(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   modell = caap_delete_pointloads(modell,arg)
%   
%   Funktion zum Löschen der Punktlasten zu dem letzten Pushover-Lastfall
%   (um dann i. Allg. später neue, korrigierte Knotenlasten definieren zu können)
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% Vorarbeit: Name des aktuellen/letzten Load Patterns definieren über den letzten Pushover-Lastfall
loadpattern = arg.info.name_pushover_old;


%% Übergeordnete Prüfung, ob es überhaupt JointLoads gibt, je nach Bezug ('frames' oder 'joints')
%% FALL 1: Punktlasten wurden (wenn) auf die 'frames' bezogen definiert (dabei werden ALLE System- UND FE-Knoten belastet; allerdings dürfen im System auch NUR 'frame'-Elemente vorhanden sein!)
if strcmp(arg.comp.push_load_ref,'frames') && isfield(modell,'FrameLoads0x2DPoint')
    % => Voruntersuchung: Prüfen, ob es bisher nur den einen LoadPattern gibt
    LoadPatterns = unique(modell.FrameLoads0x2DPoint.LoadPat(:,1));
    if size(LoadPatterns,1) == 1 && strcmp(LoadPatterns{1},loadpattern) % 2. Überprüfung nur so sicherheitshalber!
        % Dann: Direkt das ganze Feld "FrameLoads0x2DPoint" löschen
        modell = rmfield(modell,'FrameLoads0x2DPoint');
    else
        % => Zu löschende Zeilen (die eben zum LoadPattern "loadpattern" korresp.) in "modell.FrameLoads0x2DPoint" identifizieren
        i_zeilen_delete = find(strcmp(modell.FrameLoads0x2DPoint.LoadPat(:,1),loadpattern));
        % => Alle Sub-Felder von "modell.FrameLoads0x2DPoint" bis auf "name" entsprechend reduzieren
        % Feldnamen definieren
        ATTRIBUTE = fieldnames(modell.FrameLoads0x2DPoint);
        % Schleife über alle Feldnamen
        for i_attribut = 1:1:size(ATTRIBUTE,1)
            if ~strcmp(ATTRIBUTE{i_attribut},'name') % der Name bleibt natürlich unverändert
                modell.FrameLoads0x2DPoint.(ATTRIBUTE{i_attribut})(i_zeilen_delete) = [];
            end
        end
    end

%% FALL 2: Punktlasten wurden (wenn) auf die 'joints' bezogen definiert (dabei werden ALLE Systemknoten belastet, unabhängig vom zugehörigen Elementtyp; allerdings werden FE-Knoten hierbei ignoriert!)
elseif strcmp(arg.comp.push_load_ref,'joints') && isfield(modell,'JointLoads0x2DForce')
    % => Voruntersuchung: Prüfen, ob es bisher nur den einen LoadPattern gibt
    LoadPatterns = unique(modell.JointLoads0x2DForce.LoadPat(:,1));
    if size(LoadPatterns,1) == 1 && strcmp(LoadPatterns{1},loadpattern) % 2. Überprüfung nur so sicherheitshalber!
        % Dann: Direkt das ganze Feld "JointLoads0x2DForce" löschen
        modell = rmfield(modell,'JointLoads0x2DForce');
    else
        % => Zu löschende Zeilen (die eben zum LoadPattern "loadpattern" korresp.) in "modell.JointLoads0x2DForce" identifizieren
        i_zeilen_delete = find(strcmp(modell.JointLoads0x2DForce.LoadPat(:,1),loadpattern));
        % => Alle Sub-Felder von "modell.JointLoads0x2DForce" bis auf "name" entsprechend reduzieren
        % Feldnamen definieren
        ATTRIBUTE = fieldnames(modell.JointLoads0x2DForce);
        % Schleife über alle Feldnamen
        for i_attribut = 1:1:size(ATTRIBUTE,1)
            if ~strcmp(ATTRIBUTE{i_attribut},'name') % der Name bleibt natürlich unverändert
                modell.JointLoads0x2DForce.(ATTRIBUTE{i_attribut})(i_zeilen_delete) = [];
            end
        end
    end

end

end
function arg = caap_build_pushover(erg,arg,typ)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_build_pushover(erg,arg,typ)
%   
%   Funktion zum Zusammenbauen der PushOver-Kruve
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


%% Ergebnisse sortieren (bzw. BaseReactions ggf. erstmal erzeugen)

% (A) BaseReactions
%{
Hinweis:
BaseReactions liegen genau dann NICHT vor, wenn man bei einem FH-Modell für
den Beton als Hysteresemodell "Elastic" auswählt und SAP2000 dann
komischerweise die "Y08"-Datei mit den Base Reactions erst exportiert und
dann wieder löscht!
%}
if isfield(erg,'BaseReactions')
    % Fall: BaseReactions liegen vor
    % -> Ergebnisse entspr. sortieren
    erg = caap_sort_field(erg,'BaseReactions','OutputCase');
else
    % Fall: BaseReactions liegen  NICHT vor
    % -> Ergebnisse (unmittelbar richtig sortiert) generieren
    erg = caap_sort_field(erg,'JointReactions','OutputCase');
    erg = caap_create_BaseReactions_from_JointReactions(erg,arg.info.name_pushover_old);
end

% (B) JointDisplacements
erg = caap_sort_field(erg,'JointDisplacements','OutputCase');


%% Das ist jetzt mega elegant!

% Spalte für die Translation in primärer Bebenrichtung ermitteln
index_col_v = find(strcmp(erg.JointDisplacements.Inhalt(1,:),['U' mat2str(arg.comp.d_earthquake{2,1})]));

% Spalte für den Fundamentschub in primärer Bebenrichtung ermitteln
index_col_F = find(strcmp(erg.BaseReactions.Inhalt(1,:),['GlobalF' arg.comp.d_earthquake{1,1}]));

switch typ
    case 'initial'
            % Zeilen Translationen
            index_row_v = find(strcmp(erg.JointDisplacements.Werte.(arg.info.name_pushover_old)(:,1),arg.comp.kk));
            arg.comp.pushoverkurve.initial = cellfun(@str2num,erg.JointDisplacements.Werte.(arg.info.name_pushover)(index_row_v,index_col_v));
            arg.comp.pushoverkurve.initial(:,2) = abs(cellfun(@str2num,erg.BaseReactions.Werte.(arg.info.name_pushover)(:,index_col_F)));
        
    otherwise
        % Wenn man sich im ersten Schritt befindet
        if arg.info.nummer == 1
            
            % Größe ermitteln
            n_ges = size(erg.BaseReactions.Werte.(arg.info.name_pushover),1);
            
            % Vorbelegen
            arg.comp.pushoverkurve.gesamt = NaN(n_ges,2);
            
            % Zeilen korrespondierend zum Kontrollknoten identifizieren
            index_row_v = find(strcmp(erg.JointDisplacements.Werte.(arg.info.name_pushover)(:,1),arg.comp.kk));
            
            % Translation des Kontrollknotens zu jedem Schritt ablegen
            arg.comp.pushoverkurve.gesamt(:,1) = cellfun(@str2num,erg.JointDisplacements.Werte.(arg.info.name_pushover)(index_row_v,index_col_v));
            
            % Fundamentschub zu jedem Schritt ablegen
            arg.comp.pushoverkurve.gesamt(:,2) = abs(cellfun(@str2num,erg.BaseReactions.Werte.(arg.info.name_pushover)(:,index_col_F)));
            
            % Wenn adaptiv, dann auch als segment_1 abspeichern
            if arg.comp.adaptive == 1
                arg.comp.pushoverkurve.segment_1 = arg.comp.pushoverkurve.gesamt;
            end
            
            
        % Sonst in jedem anderen Schritt
        else
            
            % Zusätzliche Größe ermitteln
            n_zus = size(erg.BaseReactions.Werte.([arg.info.name_pushover '__' num2str(arg.info.nummer)]),1);
            n_vorh = size(arg.comp.pushoverkurve.gesamt,1);
            
            % Vorbelegung
            pushoverkurve_gesamt_tmp = NaN(n_zus+n_vorh,2);
            
            % Bereits vorhandene Daten übernehmen
            pushoverkurve_gesamt_tmp(1:n_vorh,:) = arg.comp.pushoverkurve.gesamt;
            
            % Zeilen Translationen
            index_row_v = find(strcmp(erg.JointDisplacements.Werte.([arg.info.name_pushover '__' num2str(arg.info.nummer)])(:,1),arg.comp.kk));
            
            % Translation des Kontrollknotens zu jedem Schritt ablegen
            pushoverkurve_gesamt_tmp(n_vorh+1:end,1) = cellfun(@str2num,erg.JointDisplacements.Werte.([arg.info.name_pushover '__' num2str(arg.info.nummer)])(index_row_v,index_col_v));
            
            % Fundamentschub zu jedem Schritt ablegen
            pushoverkurve_gesamt_tmp(n_vorh+1:end,2) = abs(cellfun(@str2num,erg.BaseReactions.Werte.([arg.info.name_pushover '__' num2str(arg.info.nummer)])(:,index_col_F)));
            
            % Segment ablegen
            arg.comp.pushoverkurve.(['segment_' num2str(arg.info.nummer)]) = pushoverkurve_gesamt_tmp(n_vorh+1:end,:);
            
            % pushoverkurve_gesamt_tmp umspeichern
            arg.comp.pushoverkurve.gesamt = pushoverkurve_gesamt_tmp;
        end
end
end

%% Sub-Funktionen

% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Spaltennummer finden
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function erg = caap_create_BaseReactions_from_JointReactions(erg,name_pushover_loadcase)
% 1) Spalten 1-4 aus den JointReactions übernehmen
Spalte_4 = unique(erg.JointReactions.Werte.(name_pushover_loadcase)(:,5));
anz_Schritte = length(Spalte_4);
Spalte_1 = erg.JointReactions.Werte.(name_pushover_loadcase)(1:anz_Schritte,2);
Spalte_2 = erg.JointReactions.Werte.(name_pushover_loadcase)(1:anz_Schritte,3);
Spalte_3 = erg.JointReactions.Werte.(name_pushover_loadcase)(1:anz_Schritte,4);

% 2) Nun ein kleines "anz_Schritte x 3"-CellArray mit den "Step"-bezogenen
% Fundamentschüben in X-, Y- & Z-Richtung aufbauen
% Werte-Array vorbelegen
Werte_Array = cell(anz_Schritte,3);
% Werte-Array mit Leben füllen
% Schleife über alle Pushover-Schritte
for i_step = 1:anz_Schritte
    % Welche Zeilen beziehen sich auf den aktuellen Schritt?
    idzs_zeilen_logical = strcmp(erg.JointReactions.Werte.(name_pushover_loadcase)(:,5),Spalte_4(i_step));
    % Untergeordnete Schleife über alle 3 globalen Koordinatenrichtungen
    for i_R = 1:3
        % Resultierenden Fundamentschub für die aktuelle Richtung für den
        % aktuellen Schritt bestimmen
        F_R_akt_step_akt = sum(cellfun(@str2num,erg.JointReactions.Werte.(name_pushover_loadcase)(idzs_zeilen_logical,5+i_R)));
        % Diesen in das neue Werte-Array mit den BaseReactions
        % "einsortieren":
        Werte_Array(i_step,i_R) = {num2str(F_R_akt_step_akt)};       
    end   
end

% 3) Strukturfeld für die BaseReactions zusammenbasteln
erg.BaseReactions.Werte.(name_pushover_loadcase) = [Spalte_1 Spalte_2 Spalte_3 Spalte_4 Werte_Array];
erg.BaseReactions.Inhalt = [erg.JointReactions.Inhalt(1,2:5) {'GlobalFX' 'GlobalFY' 'GlobalFZ'}];

end
function [modell,arg] = caap_final_performance(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   [modell,arg] = caap_final_performance(modell,arg)
%
%   Finale Berechnung zum Performance-Zustand
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

% Nummer umspeichern
segment =  arg.comp.pp.lastschritt_und_segment(1,2);

% Zielverschiebung umspeichern
v_target = arg.comp.pp.delta_kk_pp;

% DELTA_v berechnen
v_target = v_target - sum(arg.comp.v_target(1:segment-1)); % Alternativ hätte man auch die faktische Kontrollknotenverschiebung im letzten Step vom Pushover-LF mit der Nummer "segment -1" abziehen können, ist aber tats. identisch (hab ich gecheckt)!

% Entsprechenden LoadCase anpassen
if segment == 1
    [i_pushover, ~, ~] = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),arg.info.name_pushover));
else
    [i_pushover, ~, ~] = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),[arg.info.name_pushover '__' num2str(arg.info.nummer)]));
end
modell.Case0x2DStatic20x2DNonlinearLoadApplication.TargetDispl(i_pushover,1) = {strrep(mat2str(v_target),'.',',')};

% Restliches Modell aufräumen
for i_nummer = segment+1:1:arg.info.nummer
    % PushOver-Namen zusammensetzen ...
    name_pushover = [arg.info.name_pushover '__' num2str(i_nummer)];
    
    % ... und dazugehörige PointLoads im Modell löschen ...
    modell = caap_delete_pointloads(modell,name_pushover);
    
    % ... und LoadCases bzw. Patterns löschen
    modell = caap_delete_LC(modell,name_pushover,'pushover');
    
    % Modal-Namen zusammensetzen ...
    name_modal = [arg.info.name_modal '__' num2str(i_nummer)];
    
    % ... und dazugehörigen LoadCase löschen
    modell = caap_delete_LC(modell,name_modal,'modal');
    
    % PushOver-Vergleich löschen
    modell = caap_delete_LC(modell,'PushOver_Vergleich','pushover_vergleich');
end

% Modell öffnen, rechnen und schließen
%{
WICHTIG: Das Modell MUSS geschlossen werden (obwohl man es eigentlich
geöffnet haben will, um sich Ergebnisse in SAP2000 angucken zu können),
damit SAP2000 wirklich erst den Auto-Export neu geschrieben hat und dann
erst im Matlab-Tool weiter fortgefahren wird mit dem Einlesen genau dieser
daten. Denn sonst liest Matlab alte Daten ein und speichert sie unter
"final performance" (ist tatsächlich passiert und beim debuggen mit mehr
Zeit dazwischen eben nicht)!!!
%}
caap_run_sap(modell,arg,'orc');
% Neue (finale) Berechnungsergebnisse einlesen
arg.comp.erg.final_performance = caap_read_sap_file(arg.info.export_file);
% Jetzt kann das Modell geöffnet werden, sofern nicht noch eine
% "IRI"-Berechnung hinterher geschaltet wird
if ~arg.comp.iri
    caap_run_sap(modell,arg,'o');
end
end
function [modell, arg] = caap_edit_ami_o_to_ami_c(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   [modell, arg] = caap_repare_ami_o_to_ami_c(modell,arg)
%   
%   Funktion zur "Aufbereitung" gewisser Teile der modell- & arg-Struktur 
%   für den Fall, dass in einem bestimmten Adaptionsschritt des "ami_o"-
%   Verf. negative maximale Spektralbeschleunigungsinkremente aufgetreten
%   sind und man deshalb nun auf das "ami_c"-Verfahren umswitchen muss!
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

% Point Loads des letzten Pushover-Lastfalls löschen (werden jetzt
% gleich ja neu definiert)
modell = caap_delete_pointloads(modell,arg.info.name_pushover_old);
% Aktuellen Pushover- sowie Modalanalyse-Lastfall löschen (denn wir
% gehen jetzt erst nochmal schön einen Schritt zurück!)
modell = caap_delete_LC(modell,arg.info.name_pushover_new,'pushover');
modell = caap_delete_LC(modell,arg.info.name_modal_new,'modal');
% Auto-Export-Tabelle updaten hinsichtlich des gelöschten Pushover- und
% Modalanalyse-Lastfalls
% a) Pushover-Lastfälle abhandeln
% -> Der aktuelle Pushover-Lastfall ist erstmal Zukunftsmusik!
name_pushover_delete = arg.info.name_pushover_new;
% -> Neuer/Aktueller Pushover-Lastfall wird nämlich jetzt erstmal der alte!
arg.info.name_pushover_new = arg.info.name_pushover_old;
% -> Und jetzt müssen wir der Routine "caap_write_auto_export" noch vorgaukeln,
%    der Lastfall name_pushover_delete sei arg.info.name_pushover_before_old,
%    damit er nicht mehr betrachtet wird!
name_pushover_before_old_merken = arg.info.name_pushover_before_old;
arg.info.name_pushover_before_old = name_pushover_delete;
% -> ...und jetzt endlich die NamedSet-Tabelle updaten!
modell = caap_write_auto_export(modell,arg,'update_push');
% b) Modale Lastfälle abhandeln
% -> Der aktuelle modale Lastfall ist erstmal Zukunftsmusik!
name_modal_delete = arg.info.name_modal_new;
% -> Neuer/Aktueller modaler Lastfall wird nämlich jetzt erstmal der alte!
arg.info.name_modal_new = arg.info.name_modal_old;
% -> Und jetzt müssen wir der Routine "caap_write_auto_export" noch vorgaukeln,
%    der Lastfall name_modal_delete sei arg.info.name_modal_old, 
%    damit er nicht mehr betrachtet wird!
arg.info.name_modal_old = name_modal_delete;
% -> ...und jetzt endlich die NamedSet-Tabelle updaten!
modell = caap_write_auto_export(modell,arg,'update_modal');
% Nun final die Lastfall-Namen wieder korrigieren...
arg.info.name_pushover_before_old = name_pushover_before_old_merken;
arg.info.name_pushover_old = arg.info.name_pushover_new;
arg.info.name_modal_old = arg.info.name_modal_new;
arg.info.name_pushover_new = name_pushover_delete;
arg.info.name_modal_new = name_modal_delete;

% ... und eine kurze Konsolenausgabe tätigen
disp(' ') % Leerzeile
fprintf('In step %d, a change was made from "ami_o" to "ami_c" due to negative spectral acceleration increments!',arg.info.ami_o_zu_ami_c);
disp(' ') % Leerzeile
end
function arg = caap_analyze_modal_participating_mass_ratios(arg)

%% Funktion zur Überprüfung, ob in (einer) der betrachteten Bebenrichtung(en) eine bisher nicht berücksichtigte Modalform nun (Zustand i) eine größere effektive Modalmasse hat als 5%
% -> Wird in der MAIN Function im Falle einer adaptiven AMI-Berechnung
%    (egal ob "ami_c" oder "ami_o") aufgerufen, sofern ein neuer
%    Adaptionsschritt erforderlich ist!

% Sinnvoll/Notwendig ab Schritt 2
if arg.info.nummer == 1
    % Im Schritt 1:
    % Vorbelegung
    for i_R = 1:size(arg.comp.d_earthquake,2)
        arg.comp.modes.massenanteile_massg_neu.(arg.comp.d_earthquake{1,i_R}) = [];
    end
else
    % Ab Schritt 2:
    flag_neue_relevante_Moden_aktueller_Schritt = 0; % Vorbelegung der Flag, die die Notwendigkeit einer abschließenden(richtungsübergreifenden) Erläuterungsausgabe anzeigt
    % Schleife über alle Bebenrichtungen
    for i_R = 1:size(arg.comp.d_earthquake,2)
        % Aktuelle Bebenrichtung auslesen
        R_Beben_akt = arg.comp.d_earthquake{1,i_R};
        Nr_R_Beben_akt = arg.comp.d_earthquake{2,i_R};
        % Sämtliche aktuellen effektiven Modalmassenanteile in der gerade betrachteten Bebenrichtung auslesen
        erg_i = caap_sort_field(arg.comp.erg.(['schritt_',num2str(arg.info.nummer)]),'ModalParticipatingMassRatios','OutputCase');
        massenanteile_akt_R_akt = cellfun(@str2num,erg_i.ModalParticipatingMassRatios.Werte.(arg.info.name_modal_old)(:,4+Nr_R_Beben_akt));
        % Identifikation der aktuell maßgebenden Anteile
        % -> Heißt: Größer als 5%
        moden_akt_massenanteile_massg_akt_R_akt = find(massenanteile_akt_R_akt > 0.05);
        % Zwischenschritt 1: Die bereits berücksichtigten Moden rausschmeißen
        % (in kl. Schleife über ALLE angesetzten Moden, Bezug hier aber immer auf die jew. AKTUELLE Mode-Nr.)
        for i_Mode_angesetzt = 1:length(arg.comp.modes_aktuell)
            moden_akt_massenanteile_massg_akt_R_akt = moden_akt_massenanteile_massg_akt_R_akt(moden_akt_massenanteile_massg_akt_R_akt~=abs(arg.comp.modes_aktuell(i_Mode_angesetzt)));
        end
        % Zwischenschritt 2: Diejenigen Moden rausschmeißen, die bereits in "massenanteile_massg_neu" stehen für die aktuelle Bebenrichtung
        % (in kl. Schleife über alle bereits in "massenanteile_massg_neu" für die aktuelle Bebenrichtung aufgeführten Moden)
        if ~isempty(arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt))
            for i_Mode_vorh = 1:size(arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt),1)
                moden_akt_massenanteile_massg_akt_R_akt = moden_akt_massenanteile_massg_akt_R_akt(moden_akt_massenanteile_massg_akt_R_akt~=...
                                                                                                    arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt)(i_Mode_vorh,1));
            end
        end
        % Informationen für später abspeichern
        % 1. Spalte: Aktuelle Mode-Nummer, 2. Spalte: Schritt-Nummer der ersten Überschreitung der "5%-Hürde"
        arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt) = [arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt); ...
            [moden_akt_massenanteile_massg_akt_R_akt repmat(arg.info.nummer,length(moden_akt_massenanteile_massg_akt_R_akt),1)]];
        % Ausgabe zu ggf. in der aktuellen Richtung IM AKTUELLEN SCHRITT
        % (hinsichtlich der effektiven Modalmassenanteile) neu relevant 
        % gewordenen Moden
        if ~isempty(arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt)) && any(arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt)(:,2)==arg.info.nummer)
            % Flag aktualisieren
            flag_neue_relevante_Moden_aktueller_Schritt = 1;
            % Ausgabe
            fprintf(2,'\n ATTENTION: In the current step %d, the following mode(s) became additionally relevant in the %s direction:\n',arg.info.nummer,R_Beben_akt)
            (arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt)(arg.comp.modes.massenanteile_massg_neu.(R_Beben_akt)(:,2)==arg.info.nummer,1))'
        end
    end
    % Ggf. zusätzliche Erläuterung, sofern es eine Ausgabe im aktuellen
    % Schritt (bezüglich mindestens in einer Richtung neu relevant
    % gewordener Moden) gab
    if flag_neue_relevante_Moden_aktueller_Schritt
        fprintf(2,['Please note: Modes that are not taken into account will of course not be\n',...
            'investigated regarding potential mode changes, so that the numbers given above are not guaranteed,\n',...
            'to be related to the corresponding initial mode numbers!\n',...
            'Please check BEFORE including in new calculation!\n\n'])
    end
end

end
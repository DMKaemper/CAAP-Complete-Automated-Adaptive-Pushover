function arg = caap_check_eigenmodes(arg)

%% Vorarbeit
% Auslesen, wie viele Moden überhaupt berechnet wurden
anz_moden_berechnet = size(arg.comp.erg.schritt_0.ModalParticipationFactors.Werte,1);

% Relevante Eigenform-Ergebnisse nach Lastfällen sortieren
% -> Aktuelle/Neue Ergebnisse
erg_i_minus_1 = caap_sort_field(arg.comp.erg.(['schritt_',num2str(arg.info.nummer-1)]),'JointDisplacements','OutputCase');
% -> Ab Schritt 2: Auch alte Ergebnisse (aus dem vorherigen Schritt)
if arg.info.nummer > 1
    erg_i_minus_2 = caap_sort_field(arg.comp.erg.(['schritt_',num2str(arg.info.nummer-2)]),'JointDisplacements','OutputCase');
end

% Prüfen, welche Moden (der initialen Modal-Analyse) berücksichtigt werden
% sollen, und damit auch wie viele (Überprüfung in Abhängigkeit des Verfahrens)
switch arg.info.procedure
    case 'standard'
        % Fall: Je Richtung gibt es nur einen Mode!
        % Je betrachteter Bebenrichtung gibt es einen Mode
        anz_moden = size(arg.comp.d_earthquake,2); % Anzahl Moden = Anzahl der betrachteten Bebenrichtungen
        Moden_initial = zeros(anz_moden,1);
        % Mode-Nr je Richtung auslesen und zusammenfügen
        for i_mode = 1:anz_moden
            Moden_initial(i_mode) = abs(arg.comp.modes.(upper(arg.comp.d_earthquake{1,i_mode}))); % abs(): Vorzeichen hat natürlich nichts mit der Mode-Nr. zu tun!
        end
    case {'ami_c','ami_o'}
        % Fall: Je Richtung gibt es eine gewisse Anzahl an Moden
        % Je betrachteter Bebenrichtung gibt es eine gewisse Anzahl an
        % Moden, die alle hintereinander in arg.comp.modes.unique für die
        % erste Modal-Analyse aufgeführt sind; ein Mode kann aber durchaus
        % auch in mehreren Richtungen relevant sein, daher werden in
        % "arg.comp.modes.unique" mittlerweile nur noch Beträge hinterlegt
        % (damit im Fall: arg.comp.modes.Y = [-2 6], arg.comp.modes.X = [1 2]
        % nicht "-2" und "2" in arg.comp.modes.unique auftauchen!!!)!
        % << Die VZ-gerechten Angaben finden sich "unbehandelt" in
        % arg.comp.modes.gesamt_initial" bzw. "auf dem Laufenden gehalten"
        % in arg.comp.modes.gesamt! >>
        anz_moden = length(arg.comp.modes.unique);
        % Mode-Nrn auslesen
        Moden_initial = arg.comp.modes.unique; % arg.comp.modes.unique enthält mittlerweile nur noch positive Integer-Werte (s. o.), daher hier kein "abs()"-Befehl notwendig!
end

% Nun die aktuellen Mode-Nummern auf Basis der vorherigen Modal-Analyse auslesen
if arg.info.nummer == 1
    % Moden_aktuell entspricht im ersten Schritt automatisch Moden_initial
    Moden_aktuell = Moden_initial;
else
    % Später holt man sich Moden_aktuell aus der arg-Struktur
    Moden_aktuell = arg.comp.modes_aktuell;
end

% Ab Schritt 2: Zwischenspeichern des bisherigen Inhalts des "changes"-Feldes von arg.comp.modes
if arg.info.nummer > 1
    arg.comp.modes.changes_old = arg.comp.modes.changes;
end
    
% Nun: Kurze Vorbelegung/Leerung des aktuellen "changes"-Feldes von arg.comp.modes
arg.comp.modes.changes = [];


%% Überprüfung möglicher "mode changes" (bei allen Verfahren, "standard" und "ami_c" oder "ami_o") ab dem zweiten Adaptionsschritt
% > Erst ab dem zweiten Schritt
if arg.info.nummer > 1
    
    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    % << Zwischenschritt:
    % a) Effektive Modalmassen und Eigenperioden für die Mode-Zuordnungsvariante I zusammenstellen
    % UND
    % b) Außerdem schonmal (vorsorglich) für die (im Zweifel für irgendeine Modalform doch erforderlichen) Mode-Verformungen
    %    der beiden relevanten Modalanalysen (aktuell und vorherig) zusammenstellen
    % Vorarbeit: Namen der jew. relevanten Modalanalyse-Lastfälle
    % definieren
    if arg.info.nummer == 2
        % Dann gibt es keinen Lastfall (arg.info.name_modal)__1,
        % sondern er heißt einfach (arg.info.name_modal)
        Name_Modal_i_minus_1 = arg.info.name_modal;
    else
        Name_Modal_i_minus_1 = strrep(arg.info.name_modal_old,num2str(arg.info.nummer),num2str(arg.info.nummer-1));
    end
    Name_Modal_i = arg.info.name_modal_old;
    % zu a):
    ModeNrn = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),Name_Modal_i_minus_1),3));
    M_eff_i_minus_1 = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),Name_Modal_i_minus_1),5:7))*100; % [%]
    M_eff_i = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),Name_Modal_i),5:7))*100; % [%]
    T_i_minus_1 = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),Name_Modal_i_minus_1),4)); % [s]
    T_i = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),Name_Modal_i),4)); % [s]
    % zu b):
    Modalerg_i_minus_1 = erg_i_minus_2.JointDisplacements.Werte.(Name_Modal_i_minus_1);
    Modalerg_i = erg_i_minus_1.JointDisplacements.Werte.(Name_Modal_i);
    % (Ende: Zwischenschritt) >>
    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    % Schleife über alle zu berücksichtigenden Moden
    for i_mode = 1:anz_moden

        % Allgemeine Vorarbeit:
        % Mode-Nummer des AKTUELL betrachteten Modes bezogen auf die INITIALE Modal-Analyse auslesen
        ModeNr_akt_initial = Moden_initial(i_mode);
        % Mode-Nummer des AKTUELL betrachteten Modes bezogen auf die VORHERIGE Modal-Analyse auslesen
        ModeNr_akt_i_minus_1 = Moden_aktuell(i_mode);

        % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        % <><><><><><><><> Variante I: Versuch der Mode-Zuordnung über die effektiven Modalmassen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        % Korridor mit bis zu vier Nachbarn zu beiden Seiten definieren
        Mode_Korridor = unique([max(ModeNr_akt_i_minus_1-4,1) max(ModeNr_akt_i_minus_1-3,1) max(ModeNr_akt_i_minus_1-2,1) max(ModeNr_akt_i_minus_1-1,1) ModeNr_akt_i_minus_1...
                        min(ModeNr_akt_i_minus_1+1,anz_moden_berechnet) min(ModeNr_akt_i_minus_1+2,anz_moden_berechnet) min(ModeNr_akt_i_minus_1+3,anz_moden_berechnet) min(ModeNr_akt_i_minus_1+4,anz_moden_berechnet)]);
                    %{
                    unique-Befehl außen drum, da z. B. bei ModeNr_akt_i_minus_1 = 1
                    herauskäme: [1 1 1 1 1 2 3 4 5] (es soll aber [1 2 3 4 5] herauskommen),
                    oder für ModeNr_akt_i_minus_1 = 2: [1 1 1 1 2 3 4 5 6] (es soll aber
                    [1 2 3 4 5 6] herauskommen)!!!
                    %}
        % Effektive Modalmassen bezüglich aller drei kartesischen Koordinatenrichtungen
        % DES AKTUELL BETRACHTETEN MODES AUS SCHRITT i-1 auslesen
        M_eff_i_minus_1_ModeNr_akt_i_minus_1 = M_eff_i_minus_1(ModeNrn==ModeNr_akt_i_minus_1,:);
        % Dann die effektiven Modalmassen bezüglich aller drei kartesischenKoordinatenrichtungen
        % ALLER IM KORRIDOR befindlichen Moden AUS dem aktuellen SCHRITT i auslesen
        M_eff_i_Moden_im_Korridor_akt = M_eff_i(Mode_Korridor,:);
        % Schleife über alle Richtungen, in denen der aktuell betrachtete Mode in seiner alten Form ("i-1")
        % eine signifikante eff. Modalmasse (> 2%) hatte
        ModeNrn_korridorintern_potenziell = []; % Vorbelegung
        for i_R = find(M_eff_i_minus_1_ModeNr_akt_i_minus_1>2)
            % ModeNrn_akt_potenziell mit der Mode-Nummer belegen/erweitern,
            % die in der aktuell untersuchten Richtung die geringsten
            % Abweichung zwischen alter eff. Modalmasse des akt.
            % betrachteten Modes und den neuen eff. Modalmassen aller im
            % Korridor befindlichen Moden aufweist
            [ModeNr_korridorintern_potenziell_tmp,Abstand_1] = finde_aehnlichsten(M_eff_i_Moden_im_Korridor_akt(:,i_R),M_eff_i_minus_1_ModeNr_akt_i_minus_1(i_R));
            % Prüfen, ob...
            % 1.) der ABSTAND ZWISCHEN der ALTEN eff. Modalmasse UND DER ZWEITÄHNLICHSTEN neuen mindestens das DOPPELTE 
            %     DES ABSTANDES ZWISCHEN ALTER UND DER NEU AUFGEFUNDENEN ÄHNLICHSTEN UND MINDESTENS 4 % beträgt
            % 2.) die neue zugeordnete ÄHNLICHSTE eff. Modalmasse nicht fast 0 ist (> 2%, 0-Zuordnungen sind immer heikel!)
            [~,Abstand_2] = finde_aehnlichsten(M_eff_i_Moden_im_Korridor_akt(setdiff(1:length(Mode_Korridor),ModeNr_korridorintern_potenziell_tmp),i_R),M_eff_i_minus_1_ModeNr_akt_i_minus_1(i_R));
            if Abstand_2 >= max(2*Abstand_1,4) && M_eff_i_Moden_im_Korridor_akt(ModeNr_korridorintern_potenziell_tmp,i_R) > 2
                % Wenn ja: Dann ist diese Mode-Zuordnung, zumindest in der aktuell betrachteten Richtung, verlässlich!
                ModeNrn_korridorintern_potenziell = [ModeNrn_korridorintern_potenziell, ModeNr_korridorintern_potenziell_tmp];
            else
                % Wenn nein: Dann ist die Mode-Zuordnung in der aktuell
                % betrachteten Richtung und damit auch INSGESAMT NICHT
                % VERLÄSSLICH!!! -> Mode-Zuordnung nach Variante I (über
                % eff. Modalmassen) ist gescheitert und wird abgebrochen
                flag_ModeZuordnung_ueber_Meff = 0;
                break
            end
        end
        % Wenn in allen Richtungen IN SICH plausible Mode-Zuordnungen möglich waren
        % (und damit "flag_ModeZuordnung_ueber_Meff" nicht auf 0 steht, sondern noch gar nicht existiert):
        if ~exist('flag_ModeZuordnung_ueber_Meff','var')
            % -> Dann prüfen, ob die unterschiedlichen Richtungsuntersuchungen dieselbe Mode-Nummer geliefert haben,
            %    sodass "unique(ModeNrn_akt_potenziell)" zu GENAU EINER (widerspruchsfreien) POTENZIELLEN Mode-Zuordnung führt
            ModeNr_korridorintern_potenziell = unique(ModeNrn_korridorintern_potenziell);
            if length(ModeNr_korridorintern_potenziell) == 1
                % Dann entspricht die aktuelle ModeNr dem Wert von
                % 'ModeNr_akt_potenziell'
                ModeNr_akt_i = Mode_Korridor(ModeNr_korridorintern_potenziell);
                % Dann: PRÜFEN, OB die ZUORDNUNG einen MODE-SWITCH
                % darstellt oder nicht (sondern eine Selbstzuordnung,
                % sodass an dieser Stelle nichts zu tun ist!)
                if ModeNr_akt_i ~= ModeNr_akt_i_minus_1
                    % Fall: Mode-Switch!!!
                    % Gehen erstmal davon aus, dass dieser ok ist
                    flag_changes_ok = 1;
                    % --Trotzdem aber genau hierzu vier kurze Zwischenüberprüfungen (vom 05./06. & 16.07.2023)-----------------------------------------------------------------------------------------------------------------
                    % (1) Wenn z. B. Mode 4^(i-1) dem Mode 6^(i) zugeordnet wurde: Prüfen, ob jetzt die effektive Modalmasse von Mode 4(i) am besten zu der von Mode 6^(i-1) passt
                    %    (unter Einhaltung der "Abstandsregeln"). Dann würde es nämlich zu einer allein auf den effektiven Modalmassen basierenden 1:1-Vertauschung zweier Moden 
                    %    BEZÜGLICH EINER RICHTUNG kommen, was (anders als 1:1-Vertauschungen mit untersch. Richtungen, z. B. X-Mode tauscht mit Y-Mode) erfahrungsgemäß durchaus
                    %    gefährlich sein kann!!!
                    [ModeNr_korridorintern_potenziell_tmp,Abstand_1] = finde_aehnlichsten(M_eff_i_Moden_im_Korridor_akt(:,i_R),M_eff_i_minus_1(ModeNrn==ModeNr_akt_i,i_R));
                    [~,Abstand_2] = finde_aehnlichsten(M_eff_i_Moden_im_Korridor_akt(setdiff(1:length(Mode_Korridor),ModeNr_korridorintern_potenziell_tmp),i_R),M_eff_i_minus_1(ModeNrn==ModeNr_akt_i,i_R));
                    if Mode_Korridor(ModeNr_korridorintern_potenziell_tmp)==ModeNr_akt_i_minus_1 && Abstand_2 >= max(2*Abstand_1,4)
                        % Dann handelt es sich um einen RICHTUNGSINTERNEN 1:1-Mode-Switch
                        % -> Vom Benutzer "absegnen" lassen!
                        % "tic-toc"-Beziehung aufbauen
                        t_local = tic;
                        % Und ggf. eine kurze (informative)
                        % Mail rausschicken
                        if isfield(arg.info,'mail')
                            % Inhalt der Mail schreiben
                            arg.info.mail.content = sprintf(['ATTENTION:\n',...
                                'For the current calculation in step ',num2str(arg.info.nummer),' the CAAP tool',...
                                'requires a user-side confirmation of a mode change based on effective modal masses!']);
                            % Mail rausschicken
                            send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                                arg.info.mail.subject,arg.info.mail.content)
                        end
                        % While-Schleife, so lange, bis eine 1 oder 0
                        % eingetippt wurde!
                        flag_changes_akt = 0; % Noch keine verwertbare Eingabe
                        while ~flag_changes_akt
                            % Eingabe-Aufforderung - ggf. mit akustischer Warnung
                            if arg.info.sound == 0.5 || arg.info.sound == 1
                                try
                                    hupe('gong');
                                catch
                                    disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                                end
                            end
                            % Eingabe-Aufforderung
                            Koord_Richtgen = {'X','Y','Z'};
                            eingabestring = input(sprintf(['For the modes %d and %d of the previous modal analysis in step %d, relevant in the %s direction,\n',...
                                                           'a 1:1 swap (mode interchange) was identified in step %d based only on the effective modal masses!\n',...
                                'Please look at the mode shapes in SAP2000 and confirm (1) or reject (0): '],ModeNr_akt_i,ModeNr_akt_i_minus_1,(arg.info.nummer-1),Koord_Richtgen{i_R},arg.info.nummer),'s');
                            % Eingabe verarbeiten
                            if ismember(str2double(eingabestring),[1 0])
                                % Super Eingabe!
                                flag_changes_akt = 1;
                                % Eingabe verwerten
                                if str2double(eingabestring) == 0
                                    flag_changes_ok = 0;
                                end
                            end
                        end
                        % Ausgabe der Unterbrechungszeit
                        % (relevant, falls man die Eingabe-Aufforderung erst
                        % Stunden später bemerkt hat)
                        sec_local = toc(t_local); % [s]
                        disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
                        hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
                        disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
                    end
                    % (2) Wenn z. B. Mode 4^(i-1) dem Mode 6^(i) zugeordnet wurde: Prüfen, ob die effektive Modalmasse von Mode 6(i-1) auch am besten zu sich selbst, also der von Mode 6^(i) passt
                    ModeNr_korridorintern_potenziell_tmp = finde_aehnlichsten(M_eff_i_Moden_im_Korridor_akt(:,i_R),M_eff_i_minus_1(ModeNrn==ModeNr_akt_i,i_R));
                    if Mode_Korridor(ModeNr_korridorintern_potenziell_tmp)==ModeNr_akt_i
                        % Fall: Ja, M_eff,6(i-1) hätte auch am besten zu M_eff,6(i) gepasst z. B.
                        % Dann sollte die automatisierte Switch-Zuordnung als gescheitert angesehen werden
                        flag_changes_ok = 0;
                    end
                    % (3) Außerdem hat sich herausgestellt, dass Unterschiede der Eigenfrequenzen 
                    % von mehr als 30 % Zeichen für eine falsche Mode-Switch-Zuweisung (zum. wenn sie
                    % eben alleinig auf den eff. Modalmassen basieren) sein können!
                    if max(T_i_minus_1(ModeNr_akt_i_minus_1),T_i(ModeNr_akt_i))/min(T_i_minus_1(ModeNr_akt_i_minus_1),T_i(ModeNr_akt_i)) > 1.3
                        % Ein solch großer Frequenzsprung (um mehr als 30 %)
                        % kann wie gesagt unrealistisch sein, daher lieber
                        % die Zuordnung ALLEIN AUF BASIS VON M_eff_n^(i-1)
                        % und M_eff_m^(i) als gescheitert ansehen
                        flag_changes_ok = 0;
                    end
                    % (4) Zu guter Letzt wird noch überprüft, dass die Eigenperiode (und damit -frequenz) des neu zugeordneten Modes nicht negativ ist 
                    %     (dann ist es nämlich ein kinematischer Mode, was wiederum zu einem komplexen Eigenvektor führt und komplexe Einträge im Lastvektor führen anschließend zum Systemabsturz in SAP2000!)
                    if T_i(ModeNr_akt_i) < 0
                        flag_changes_ok = 0;
                        % Kurze informative Ausgabe hierzu:
                        fprintf(1,['\n NOTE: In the current step %d, mode %d from step %d was actually assigned to\n',...
                                   'the new mode %d on the basis of the effective modal masses!\n',...
                                   'However, as the latter has a negative natural frequency and \n',...
                                   'is therefore presumably kinematic, this was prevented!\n\n'],arg.info.nummer,ModeNr_akt_i_minus_1,arg.info.nummer-1,ModeNr_akt_i)
                    end
                    % --ENDE: Kurze Zwischenüberprüfungen (vom 05./06.07.2023)---------------------------------------------------------------------------------------------------------------------------------------------------
                    % WENN NUN Mode-Switch ok:
                    if flag_changes_ok
                        % Dann den entspr. "mode changes" nun in dem neu aufgebauten Feld "arg.comp.modes.changes" definieren,
                        % sofern im aktuellen Schritt noch kein Mode dieser (neuen) aktuellen Eigenform zugeordnet wurde (was dann ja auch ein Widerspruch wäre):
                        arg = sub_define_mode_changes(arg,ModeNr_akt_initial,ModeNr_akt_i_minus_1,ModeNr_akt_i);
                        % Und: Flag setzen!
                        flag_ModeZuordnung_ueber_Meff = 1;
                    else
                        % Ansonsten ist die Mode-Switch-Untersuchung für
                        % den aktuellen Mode AUF BASIS VON M_eff gescheitert
                        flag_ModeZuordnung_ueber_Meff = 0;
                    end
                else
                    % Fall: Selbstzuordnung
                    % Flag setzen!
                    flag_ModeZuordnung_ueber_Meff = 1;
                end
            else
                % Mode-Zuordnung über die effektiven Modalmassen definitiv
                % nicht "bedenkenlos" möglich
                flag_ModeZuordnung_ueber_Meff = 0;
            end
        end
        % Aufräumen
        clear Mode_Korridor M_eff_i_minus_1_ModeNr_akt_i_minus_1 M_eff_i_Moden_im_Korridor_akt i_R ModeNrn_korridorintern_potenziell ModeNr_korridorintern_potenziell_tmp Abstand_2 Abstand_1 ModeNr_korridorintern_potenziell
        % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        % <><><><><><><><> ENDE Variante I: Versuch der Mode-Zuordnung über die effektiven Modalmassen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
        % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

        % => WENN DIE MODE-ZUORDNUNG ÜBER DIE EFFEKTIVEN MODALMASSEN NICHT ERFOLGREICH WAR: 
        %    ZU VARIANTE II ÜBERGEHEN!
        if ~flag_ModeZuordnung_ueber_Meff
            % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % <><><><><><><><> Alternative Variante II: Versuch der Mode-Zuordnung über die Eigenformen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % > Verformungsbasierte changes-Überprüfung nur notwendig, wenn sich der aktuell betrachtete Mode
            %   im Vergleich zum vorherigen Schritt (i-1) merklich verändert hat
                % >> Entsprechende Zwischenüberprüfung:
                % (1) Aktuelle Mode-Nr. identifizieren
                %{
                      Gehen zunächst davon aus, dass der Mode sich im Vergleich
                      zum letzten Schritt nicht großartig geändert hat (Regelfall!),
                      sodass man sich auf die "aktuelle" Mode-Nummer aus dem letzten
                      Schritt (i-1) beziehen kann (genau das müsste ja der Fall sein,
                      den wir hier betrachten wollen) und es gilt:
                %}
                ModeNr_akt_i = ModeNr_akt_i_minus_1;
                % (2) Eigenvektor mit aktueller Mode-Nummer des letzten sowie
                %     des aktuellen Schrittes auslesen und auf max. Translation
                %     normieren
                % Indizes der Zeilen in den modalen Knoten-Verformungen herausfinden, die sich auf
                % den jew. aktuellen Mode beziehen
                indizes_Mode_akt_Erg_i_minus_1 = find(cellfun(@str2num,Modalerg_i_minus_1(:,5)) == ModeNr_akt_i);
                indizes_Vergleichsmode_akt_Erg_i = find(cellfun(@str2num,Modalerg_i(:,5)) == ModeNr_akt_i);
                % Entsprechende Modalergebnisse dieser Modalform extrahieren
                Modalerg_i_minus_1_von_Mode_akt = Modalerg_i_minus_1(indizes_Mode_akt_Erg_i_minus_1,:);
                Modalerg_i_von_Mode_akt = Modalerg_i(indizes_Vergleichsmode_akt_Erg_i,:);
                % Nur die Knotentranslationen dieses Modes auswählen
                v_Bezugsmode_akt_i_minus_1 = cellfun(@str2num,Modalerg_i_minus_1_von_Mode_akt(:,6:8));
                v_Bezugsmode_akt_i = cellfun(@str2num,Modalerg_i_von_Mode_akt(:,6:8));
                % Diesen jew. Eigenvektor auf die maximale Verschiebungskomponente
                % (richtungsübergreifend!!!) normieren;
                % dadurch ist die größte Komponente nun immer +1!!!
                    % >> Zwischenschritt: Betraglich maximale Verschiebung
                    %    vorzeichengerecht ermitteln, sodass nach der Normierung
                    %    v_max immer = +1 ist!!!
                    %{
                         Hinweis: 
                         -> "unique(...)", falls exakt dieser maximale Wert mehrfach auftritt 
                         -> und abs(...), falls dieser Wert einmal positiv und einmal
                            negativ auftritt (z. B. bei einer antimetrischen Eigenform);
                            dass hierbei dann mit dem positiven und nicht mit dem
                            negativen skaliert wird, spielt insofern keine Rolle, als ja
                            ohnehin noch einmal die komplette PHI-Matrix dann mit -1
                            skaliert zusätzlich untersucht wird!
                    %}
                         v_massg_PHI_akt_i_minus_1 = unique(v_Bezugsmode_akt_i_minus_1(abs(v_Bezugsmode_akt_i_minus_1)==max(max(abs(v_Bezugsmode_akt_i_minus_1))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
                         % Tritt der betraglich maximale Wert positiv UND negativ auf,
                         % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
                         % sich bezieht, gewählt wird dann einfach der positive
                         if length(v_massg_PHI_akt_i_minus_1) == 2
                             v_massg_PHI_akt_i_minus_1 = unique(abs(v_massg_PHI_akt_i_minus_1));
                         end
                         v_massg_PHI_akt_i = unique(v_Bezugsmode_akt_i(abs(v_Bezugsmode_akt_i)==max(max(abs(v_Bezugsmode_akt_i))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
                         % Tritt der betraglich maximale Wert positiv UND negativ auf,
                         % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
                         % sich bezieht, gewählt wird dann einfach der positive
                         if length(v_massg_PHI_akt_i) == 2
                             v_massg_PHI_akt_i = unique(abs(v_massg_PHI_akt_i));
                         end
                   % (Ende: Zwischenschritt) >>
                PHI_akt_i_minus_1_norm = v_Bezugsmode_akt_i_minus_1 / v_massg_PHI_akt_i_minus_1;
                PHI_akt_i_norm = v_Bezugsmode_akt_i / v_massg_PHI_akt_i;
                % (3) Summierte betragliche Differenzen der Knotenverschiebungen ermitteln 
                % -> Vorbelegung
                Mat_Diff = nan(2,3); % (Zwei Zeilen, da: Diff. des pos. Vektor aus Schritt (i-1) einmal von positivem und einmal von negativem Vektor aus Schritt (i))
                % -> Schleife über alle drei globalen Translationsrichtungen
                for i_R = 1:3
                    % vec_PHI_i_minus_1_R auslesen
                    vec_PHI_i_minus_1_R = PHI_akt_i_minus_1_norm(:,i_R);
                    % Prüfen, ob der aktuell betrachtete NORMIERTE MODE aus dem Schritt 
                    % (i-1) in der aktuellen Richtung "eine signifikante Rolle spielt"
                    if max(max(abs(vec_PHI_i_minus_1_R))) > 0.1
                        % Nur dann: Diese Richtung überhaupt untersuchen
                        % vec PHI_n_i_R auslesen
                        vec_PHI_i__R = PHI_akt_i_norm(:,i_R);
                        % Prüfen, ob der aktuell betrachtete NORMIERTE MODE aus dem Schritt
                        % (i) in der aktuellen Richtung "ebenfalls eine signifikante Rolle spielt"
                        % (Grenze hier bewusst "etwas" herabgesetzt)
                        if max(max(abs(vec_PHI_i__R))) > 0.08 % hier nochmal abs(vec_PHI_i__R), da er ja einmal mit (-1) skaliert auftritt
                            % Ja, beide Moden scheinen in dieser Richtung wirklich
                            % "aktiv zu sein"
                            % -> Einmal die Differenz zum "1"-fachen aktuellen Vektor
                            Mat_Diff(1,i_R) = sum(abs(vec_PHI_i_minus_1_R-vec_PHI_i__R));
                            % -> Und einmal die Differenz zum "-1"-fachen aktuellen Vektor
                            Mat_Diff(2,i_R) = sum(abs(vec_PHI_i_minus_1_R-(-vec_PHI_i__R)));
                        % Ansonsten bleibt der vorbelegte "NaN"-Wert erhalten,
                        % daher kein "else"-Fall erforderlich!
                        end
                    end
                end
                % (4) Diese Differenzen nun noch durch die Anzahl der Knoten teilen
                %{
                Eine Art Normierung, also eine mittlere Abweichung
                pro Knoten ermitteln, da die absolute Summe bei immer
                größeren Tragwerken zunehmen würde!
                %}
                % Zwischenschritt: Anzahl der Knoten ermitteln
                anz_knot = size(Modalerg_i_minus_1_von_Mode_akt,1);
                % "Normierung" durchführen
                Mat_Diff = Mat_Diff/anz_knot;
                % (5) Nun endlich die oben angedeutete Überprüfung durchführen
                %{
                Eine "merkliche" Veränderung eines Modes von Schritt (i-1) zu
                Schritt (i) kann hierbei ZUM EINEN gekennzeichnet sein durch eine
                maximale normierte Differenz > 0,05. Beispieluntersuchungen ergaben 
                eine merkliche, d. h. sichtbare Veränderung ab einer normierten
                Differenz von 0,1; das Kriterium wurde aber bewusst deutlich
                schärfer formuliert, um "nichts wichtiges zu unterschlagen"!
                => ACHTUNG: "Maximale Differenz" heißt, maximal aus den jew.
                Richtungs-Werten; innerhalb einer Richtung zählt das Minimum,
                da das Maximum zu einer "falschen" Richtung/einem falschen VZ
                des Modes im Schritt (i) korrespondiert!!!
                ZUM ANDEREN kann sie dadurch gekennzeichnet sein, dass überhaupt
                keine Differenzen ausgerechnet wurden, weil z. B. ein reiner
                Y-Mode zu einem reinen X-Mode geworden ist (dann ist der neue
                Mode in der einzig maßgebenden Y-Richtung des alten Modes nicht
                relevant)!     
                %}
                if max([min(Mat_Diff(:,1)) min(Mat_Diff(:,2)) min(Mat_Diff(:,3))]) > 0.05 || ~any(any(~isnan(Mat_Diff)))
                    % FALL: Der aktuell betrachtete Mode hat sich zwischen Schritt (i-1) und
                    % Schritt (i) so deutlich verändert, dass er einer "Mode-Switch"-
                    % Untersuchung unterzogen werden sollte!
                    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                    % <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                    % -BEGINN:--MODE-SWITCH-UNTERSUCHUNG-FÜR-DEN-AKTUELLEN-MODE------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                    
                        % Vergleichs-Moden ermitteln, bezogen auf die letzte Modal-Analyse im Schritt (i-1) (immer der aktuelle Mode selbst und, sofern vorhanden, vier "Nachbarn zu beiden Seiten")
                        Moden_vergleich = unique([max(ModeNr_akt_i_minus_1-4,1) max(ModeNr_akt_i_minus_1-3,1) max(ModeNr_akt_i_minus_1-2,1) max(ModeNr_akt_i_minus_1-1,1) ModeNr_akt_i_minus_1...
                            min(ModeNr_akt_i_minus_1+1,anz_moden_berechnet) min(ModeNr_akt_i_minus_1+2,anz_moden_berechnet) min(ModeNr_akt_i_minus_1+3,anz_moden_berechnet) min(ModeNr_akt_i_minus_1+4,anz_moden_berechnet)]);
                        %{
                        unique-Befehl außen drum, da z. B. bei ModeNr_akt_i_minus_1 = 1
                        herauskäme: [1 1 1 1 1 2 3 4 5] (es soll aber [1 2 3 4 5] herauskommen),
                        oder für ModeNr_akt_i_minus_1 = 2: [1 1 1 1 2 3 4 5 6] (es soll aber
                        [1 2 3 4 5 6] herauskommen)!!!
                        %}
                        % Die letzten und aktuellen Modal-Ergebnisse wurden in
                        % der anfänglichen Voruntersuchung bereits ausgelesen
                        % und dort unter "Modalerg_i_minus_1" bzw. "Modalerg_i"
                        % abgespeichert.
                        % Index der Zeilen in den modalen Knoten-Verformungen der letzten
                        % Modal-Analyse herausfinden, die zum aktuellen
                        % Bezugsmode korrespondieren
                        indizes_Mode_akt_Erg_i_minus_1 = find(cellfun(@str2num,Modalerg_i_minus_1(:,5)) == ModeNr_akt_i_minus_1);
                        % Entsprechende Modalergebnisse dieser Modalform extrahieren
                        Modalerg_i_minus_1_von_Mode_akt = Modalerg_i_minus_1(indizes_Mode_akt_Erg_i_minus_1,:);
                        % Nur die Knotentranslationen dieses Modes auswählen
                        v_Bezugsmode_akt_i_minus_1 = cellfun(@str2num,Modalerg_i_minus_1_von_Mode_akt(:,6:8));
                        % Diesen Eigenvektor auf die maximale Verschiebungskomponente
                        % (richtungsübergreifend!!!) normieren
                        % Dadurch ist die größte Komponente nun immer +1 und ein potenzieller
                        % Richtungswechsel eines (sonst etwa gleichen Modes) spielt keine Geige!
                        v_Bezugsmode_massg_i_minus_1 = unique(v_Bezugsmode_akt_i_minus_1(abs(v_Bezugsmode_akt_i_minus_1)==max(max(abs(v_Bezugsmode_akt_i_minus_1))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
                        % Tritt der betraglich maximale Wert positiv UND negativ auf,
                        % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
                        % sich bezieht, gewählt wird dann einfach der positive
                        if length(v_Bezugsmode_massg_i_minus_1) == 2
                            v_Bezugsmode_massg_i_minus_1 = unique(abs(v_Bezugsmode_massg_i_minus_1));
                        end
                        PHI_Mode_akt_i_minus_1 = v_Bezugsmode_akt_i_minus_1 / v_Bezugsmode_massg_i_minus_1;
                        % Feld dritter Stufe aufbauen, welches "scheibchenweise" die
                        % richtungsbezogenen PHI-Vektoren der einzelnen Moden aus
                        % "Moden_vergleich" aus der aktuellen Modal-Analyse beinhaltet
                        % und diese PHI-Matrizen jeweils einmal mit einer bestimmten
                        % Vorzeichenkonfiguration und einmal mit der komplementären
                        % -> Vorbelegung
                        anz_Vergleichsmoden = length(Moden_vergleich);
                        PHI_n = zeros(anz_knot,3,2*anz_Vergleichsmoden);
                        % -> Füllen mittels Schleife über alle Vergleichsmoden
                        for n_Matrix = 1:anz_Vergleichsmoden
                            % Indizes der Zeilen in "Modalerg_i" herausfinden, die sich auf
                            % den aktuellen Vergleichsmode beziehen
                            indizes_Vergleichsmode_akt_Erg_i = find(cellfun(@str2num,Modalerg_i(:,5)) == Moden_vergleich(n_Matrix));
                            % Entsprechende Modalergebnisse dieser Modalform extrahieren
                            Modalerg_i_von_Mode_n = Modalerg_i(indizes_Vergleichsmode_akt_Erg_i,:);
                            % Nur die Knotentranslationen dieses Modes auswählen
                            v_Vergleichsmode_akt_i = cellfun(@str2num,Modalerg_i_von_Mode_n(:,6:8));
                            % Diesen Eigenvektor auf die maximale Verschiebungskomponente
                            % (richtungsübergreifend!!!) normieren
                            % Dadurch ist die größte Komponente nun immer +1 und ein potenzieller
                            % Richtungswechsel eines (sonst etwa gleichen Modes) spielt keine Geige!
                            v_Vergleichsmode_massg_i = unique(v_Vergleichsmode_akt_i(abs(v_Vergleichsmode_akt_i)==max(max(abs(v_Vergleichsmode_akt_i))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
                            % Tritt der betraglich maximale Wert positiv UND negativ auf,
                            % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
                            % sich bezieht, gewählt wird dann einfach der positive
                            if length(v_Vergleichsmode_massg_i) == 2
                                v_Vergleichsmode_massg_i = unique(abs(v_Vergleichsmode_massg_i));
                            end
                            PHI_n(:,:,n_Matrix) = v_Vergleichsmode_akt_i / v_Vergleichsmode_massg_i;
                        end
                        % Jetzt können die 'anz_Vergleichsmoden' (z. B. 5) PHI-Matrizen einmal
                        % mit dem Faktor -1 multipliziert kopiert werden, um für jeden
                        % Vergleichsmode "beide Richtungen" abzudecken, die dann mit dem in
                        % eine bestimmte Richtung angesetzten Bezugsmode der vorherigen Modal-
                        % Analyse verglichen werden!
                        PHI_n(:,:,((anz_Vergleichsmoden+1):2*anz_Vergleichsmoden)) = PHI_n(:,:,(1:anz_Vergleichsmoden)) * (-1);
                        % Nun für alle Moden aus "Moden_vergleich" die richtungsbezogenen
                        % Summen der betraglichen Differenzen zwischen dem aktuellen
                        % richtungsbezogenen Vergleichs-PHI-Vektor (z. B. vec PHI_n_i_X) in Schritt
                        % (i) und dem PHI-Vektor des Bezugsmodes der vorherigen Modal-Analyse in
                        % derselben Richtung ausrechnen, allerdings nur, wenn die maximalen Komponenten
                        % der beiden (auf die richtungsübergreifend größte Verschiebung normierten) Vektoren
                        % (Bezugs- & Vergleichsvektor) in dieser Richtung nicht praktisch 0 sind!
                        % -> Vorbelegung
                        Mat_Diff = nan(2*anz_Vergleichsmoden,3);
                        % -> Schleife über alle drei globalen Translationsrichtungen
                        for i_R = 1:3
                            % vec PHI_Bezug_R_i_minus_1 auslesen
                            vec_PHI_Bezug_R_i_minus_1 = PHI_Mode_akt_i_minus_1(:,i_R);
                            % Prüfen, ob der aktuell betrachtete BEZUGSMODE der
                            % vorherigen Modal-Analyse, der jedoch anschl. hinsichtlich
                            % der max. Translation (richtungsübergreifend) normiert wurde
                            % in der aktuellen Richtung "eine signifikante Rolle spielt"
                            if max(max(vec_PHI_Bezug_R_i_minus_1)) > 0.1
                                % Nur dann: Diese Richtung überhaupt untersuchen
                                % -> Untergeordnete Schleife über alle Moden aus
                                % "Moden_vergleich" und dort beide VZ-Kombinationen
                                for n_Matrix = 1:2*anz_Vergleichsmoden
                                    % vec PHI_n_R_i auslesen
                                    vec_PHI_n_R_i = PHI_n(:,i_R,n_Matrix);
                                    % Prüfen, ob der aktuelle VERGLEICHSMODE in seiner
                                    % FORM DER "i-ten" MODAL-ANALYSE in der aktuellen
                                    % Richtung "eine Rolle spielt" (zum. noch eine kleine)
                                    %{
                                    Grenze bewusst von 0,1 auf 0,01 "herabgesetzt", falls
                                    die maximale Verformung von Bezugsmode zu Vergleichsmode
                                    etwas abnimmt, damit sie nicht voher knapp über der
                                    Schranke liegt, sodass diese Richtung dann untersucht
                                    wird, und beim Vergleichsmode dann knapp drunter, dass
                                    in dieser Richtung dieser Mode bei einem faktisch nicht
                                    vorliegenden Mode-Switch dann nicht erkannt wird
                                    sondern IRGENDEIN anderer Mode (mit viel größerer
                                    Differenz)!!!
                                    %}
                                    if max(max(abs(vec_PHI_n_R_i))) > 0.01 % hier nochmal abs(vec_PHI_n_i_R), da er ja einmal mit (-1) skaliert auftritt
                                        % Ja, beide Moden scheinen in dieser Richtung wirklich
                                        % "aktiv zu sein"
                                        Mat_Diff(n_Matrix,i_R) = sum(abs(vec_PHI_Bezug_R_i_minus_1-vec_PHI_n_R_i));
                                        % Ansonsten bleibt der vorbelegte "NaN"-Wert erhalten,
                                        % daher kein "else"-Fall erforderlich!
                                    end
                                end
                            end
                        end
                        % Für jede der drei globalen Richtungen X, Y und Z:
                        % -> Index des (aktuellen) Vergleichmodes mit dem kleinsten
                        %    Differenzwert identifizieren
                        indizes_kleinste_Diff = nan(1,3); % Vorbelegung
                        n_mode_vergleich = find(Moden_vergleich==ModeNr_akt_i_minus_1); % Index des aktuell betrachteten Modes in "Moden_vergleich" finden
                        flag_relevante_moden_akt_aehnlich = 0; % Erstmal davon ausgehen, dass für potenzielle changes relevante (aktuelle) Moden recht verschieden (und damit eindeutig zuordenbar) sind!
                        for i_R = 3:-1:1 % Rückwärts gehen, da "indezes" schrumpfen kann / i. Allg. schrumpfen wird und dann gibt es im letzten Schritt index(3) gar nicht mehr!
                            % Diese Überprüfung nur für solche Richtungen durchführen,
                            % in denen nicht die gesamte Spalte in "Mat_Diff" = "NaN" ist
                            % (weil der Bezugsmode aus der vorherigen Modal-Analyse dort
                            % "nichts tut" und/oder sämtliche aktuelle Vergleichsmoden)
                            if any(~isnan(Mat_Diff(:,i_R)))
                                [indizes_kleinste_Diff(i_R),~] = find(Mat_Diff(:,i_R) == min(Mat_Diff(:,i_R)));
                                % Nun prüfen, ob die kleinste Differenz "schön
                                % weit weg ist" von der zweitkleinsten, denn
                                % nur dann kann man damit guten Gewissens eine
                                % Mode-Zuordnung durchführen!
                                % -> Dafür fordern, dass die zweitkleinste
                                % Differenz geteilt durch die kleinste eine
                                % Abweichung von mind. 5 % liefert 
                                if min(Mat_Diff(Mat_Diff(:,i_R)~=min(Mat_Diff(:,i_R)),i_R)) / Mat_Diff(indizes_kleinste_Diff(i_R),i_R) < 1.05
                                    % Fall: Die Abweichung ist kleiner als 5 %,
                                    % dann ist vorischt geboten!
                                    flag_relevante_moden_akt_aehnlich = 1;
                                end
                            else
                                indizes_kleinste_Diff(i_R) = [];
                            end
                        end
                        % Tatsächlicher Index (nur auszuwerten für die kleinste Differenz) 
                        % sollte eine skalare Größe sein, die sich zum einen aus "unique(indizes_kleinste_Diff)" 
                        % ergibt und zum anderen einem Index zwischen 1 und anz_Vergleichsmoden
                        % entspricht (letzteres heißt: ein größerer Index kommt dann durch die 
                        % "-1"-fachen Kopien der PHI-Matrizen, welche dann dem Mode noch zugeordnet 
                        % werden müssen)
                        % -> Erstmal unique-Befehl anwenden
                        index_kleinste_Diff_akt_tats = unique(indizes_kleinste_Diff);
                        % -> Jetzt ggf. den konkreten Mode-Bezug herstellen
                        % (ACHTUNG: Da index_kleinste_Diff_akt_tats theoretisch aber ja leider doch zwei oder drei verschiedene Werte enthalten kann, muss hier eine Schleife über alle Einträge erfolgen)
                        for i_Eintrag = 1:length(index_kleinste_Diff_akt_tats)
                            if index_kleinste_Diff_akt_tats(i_Eintrag) > anz_Vergleichsmoden
                                index_kleinste_Diff_akt_tats(i_Eintrag) = index_kleinste_Diff_akt_tats(i_Eintrag) - anz_Vergleichsmoden;
                            end
                        end
                        % ->-> NEUE ZWISCHENÜBERPRÜFUNG (vom 03.07.2023): ----------------------------------------------------------------------------------------------------------------------------------------------------------------
                        % Beinhaltet jetzt 'index_kleinste_Diff_akt_tats' zwei identische Zahlen? Dann kann dies (aufgrund des obigen "unique"-Befehls) NUR daran liegen,
                        % dass in einer Richtung z. B. "-2" und in einer Richtung "+2" herausgekommen ist, sprich: eigentlich derselbe Mode, aber mit unterschiedlichen Skalierungsfaktoren
                        if length(index_kleinste_Diff_akt_tats) > 1 && length(unique(index_kleinste_Diff_akt_tats)) == 1
                            % => SEIT NEUSTEM WERDEN INKONSISTENTE VORZEICHEN IN UNTERSCHIEDLICHEN RICHTUNGEN (meist eine Richtung relevant und andere ziemlich irrelevant) ignoriert, daher auch
                            %    an dieser Stelle!
                            index_kleinste_Diff_akt_tats = unique(index_kleinste_Diff_akt_tats); % und schon ignoriert!
                            % => Aber zumindest eine kleine Warnung dazu ausgeben je nach Fall: Selbstzuordnung (also KEIN SWITCH) ODER Switch!
                            disp(' ');
                            if index_kleinste_Diff_akt_tats == n_mode_vergleich
                                % Fall: KEIN Switch
                                fprintf(2,['In step %d, the mode-change examination of mode %d from the previous step\n',...
                                    '(initial mode %d) returned a self-assignment (no interchange!), BUT WITH DIFFERENT\n',...
                                    'SIGNS IN DIFFERENT DIRECTIONS.\n',...
                                    'However, a mirrored mode in a rather irrelevant direction is now accepted.\n',...
                                    '-> Please check after the calculation whether this was permitted!\n'],arg.info.nummer,ModeNr_akt_i_minus_1,ModeNr_akt_initial)
                            else
                                % Fall: Erfolgreicher Mode-Switch
                                fprintf(2,['In step %d, the mode-change examination of mode %d from the previous step\n',...
                                    '(initial mode %d) returned an assignment to the new mode %d, BUT WITH DIFFERENT\n',...
                                    'SIGNS IN DIFFERENT DIRECTIONS.\n',...
                                    'However, a mirrored mode in a rather irrelevant direction is now accepted.\n',...
                                    'This is therefore a successful change assignment.\n',...
                                    '-> Please check after the calculation whether this is correct!\n'],arg.info.nummer,ModeNr_akt_i_minus_1,ModeNr_akt_initial,Moden_vergleich(index_kleinste_Diff_akt_tats))
                            end
                        end
                        % ->-> (Ende: NEUE ZWISCHENÜBERPRÜFUNG (vom 03.07.2023)) ----------------------------------------------------------------------------------------------------------------------------------------------------------------
                        % Nun kann es sein, dass für den Index auf Basis der kleinsten 
                        % Differenzen genau EINE skalare Zahl herausgekommen ist
                        % (sprich: alle untersuchten Richtungen liefern dieselbe Zeile),
                        % dann spricht zunächst recht viel für diesen Mode, zumindest wenn
                        % der Abstand zwischen der kleinsten und der zweitkleinsten
                        % Differenz eben nicht kleiner war als 5 %: 
                        if (length(index_kleinste_Diff_akt_tats) == 1 && ~flag_relevante_moden_akt_aehnlich) % ACHTUNG: Statt eines "else"-Falls wird die "if"-Abfrage mittlerweile (Stand: 07.06.2023) beendet und dann nochmal mit dem negativen Statement abgefragt, um sie noch um "~flag_changes_ok" ergänzen zu können!
                            % Fall: Es wurde genau EINE Zeile gefunden, in der die
                            % relevanten (also nicht "NaN") Differenzen am kleinsten sind
                            % und der ähnlichste und zweitähnlichste Mode sind durchaus verschieden!
                            % => Dann prüfen, ob es sich um eine andere Zeile handelt, als beim
                            %    aktuellen Mode (dann läge ein eindeutiger "mode changes" vor)
                            if index_kleinste_Diff_akt_tats == n_mode_vergleich % Index des Modes (in Moden_vergleich) hat sich nicht geändert
                                % Es hat sich nichts geändert! 
                                % => Nur überprüfen, ob sich der (sich selbst wieder zugeordnete)
                                % Mode trotzdem vlt. dahingehend geändert hat, dass er Verformungsanteile 
                                % in einer anfänglich verformungslosen bzw. -armen Richtung dazu bekommen hat
                                PHI_akt_1_norm = sub_get_phi_akt_1_norm(arg,ModeNr_akt_initial);
                                sub_check_mode_change(arg,ModeNr_akt_initial,PHI_akt_1_norm,PHI_n(:,:,index_kleinste_Diff_akt_tats))
                            else
                                % Es hat sich was geändert, was aber offensichtlich (eindeutig)
                                % interpretiert werden konnte.
                                % -.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
                                % << Trotzdem: Kleine neue Zwischenüberprüfung (vom 13.06.2023, wieder eingeschränkt auf "wirklich schräge Moden" mit |v|max,R2 > 0.5*|v|max,R1 am 01.07.2023),
                                %    ob die Vorzeichen der "relevanten" Verformungen schräger Moden "zueinander passen" (sprich entweder jeweils ALLE gleich oder ALLE unterschiedlich sind (was einem SF von -1 entspräche),
                                %    ABER WIE GESAGT NUR (Einschränkung vom 01.07.2023), sofern beide (alter Bezugsmode und aktueller, neu zugeordneter Mode) in zwei (denselben) Richtungen "einigermaßen ähnlich große 
                                %    Verformungen" aufweisen (s. o.: sekundäre Richtung des Modes soll mind. 50 % der Verformung in primärer Richtung aufweisen)
                                %    HINTERGRUND DIESER EINSCHRÄNKUNG: Es gab nämlich diverse Fälle, wo ein eigentlich "reiner" Y-Mode auch X-Verformungen (von vlt. 10 bis 20 % der Y-Verf.) ausgebildet hat, 
                                %                                      die dann aber z. T. bei OFFENSICHTLICH EINEM BESTIMMTEN (weiterentwickelten) Mode mal positiv und mal negativ waren!!!
                                % Flag setzen (gehen erstmal davon aus, dass der Switch passt)
                                flag_changes_ok = 1;
                                % Eigenvektor des neu zugeordneten Modes (in der aktuellen Form "i") auslesen
                                v_neuer_mode_akt_i = PHI_n(:,:,index_kleinste_Diff_akt_tats);
                                % Zeile und Spalte (Richtung) mit der betraglich maximalen Verschiebung identifizieren (anhand des Bezugsmodes in der Form "i-1")
                                [Idzs_Zeilen_max_pot,Idzs_Spalte_max_pot] = find(abs(v_Bezugsmode_akt_i_minus_1(:,:))==max(max(abs(v_Bezugsmode_akt_i_minus_1(:,:)))));
                                Idx_Zeile_max = Idzs_Zeilen_max_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                                Idx_Spalte_max = Idzs_Spalte_max_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                                % Spalte (Richtung) mit den zweitgrößten Verformungen identifizieren (anhand des Bezugsmodes in der Form "i-1")
                                [Idzs_Zeilen_Rzweitmax_pot,Idzs_Spalte_zweitmax_pot] = find(abs(v_Bezugsmode_akt_i_minus_1(:,setdiff(1:3,Idx_Spalte_max)))==max(max(abs(v_Bezugsmode_akt_i_minus_1(:,setdiff(1:3,Idx_Spalte_max))))));
                                Idx_Zeile_Rzweitmax = Idzs_Zeilen_Rzweitmax_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                                Idx_Spalte_zweitmax = Idzs_Spalte_zweitmax_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                                if abs(v_Bezugsmode_akt_i_minus_1(Idx_Zeile_Rzweitmax,Idx_Spalte_zweitmax))/abs(v_Bezugsmode_akt_i_minus_1(Idx_Zeile_max,Idx_Spalte_max)) > 0.5 ...
                                    && abs(v_neuer_mode_akt_i(Idx_Zeile_Rzweitmax,Idx_Spalte_zweitmax))/abs(v_neuer_mode_akt_i(Idx_Zeile_max,Idx_Spalte_max)) > 0.5
                                    % Anzahl der gleichen Vorzeichen bezüglich aller Knotenverschiebungen ermitteln in der Richtung der betraglich größten Verformungen
                                    % -> einmal mit dem neu zugeordneten Mode, so wie er ist
                                    anz_VZ_gleich_R1_neuer_Mode_pos = sum(sign(v_Bezugsmode_akt_i_minus_1(:,Idx_Spalte_max)./v_neuer_mode_akt_i(:,Idx_Spalte_max)) == 1);
                                    % -> einmal genau mit der gespiegelten Variante des neu zugeordneten Modes
                                    anz_VZ_gleich_R1_neuer_Mode_neg = sum(sign(v_Bezugsmode_akt_i_minus_1(:,Idx_Spalte_max)./(-v_neuer_mode_akt_i(:,Idx_Spalte_max))) == 1);
                                    % Jetzt prüfen, ob wir für möglichst viele gleichgerichtete Knotenverschiebungen IN RICHTUNG R1 den neu zugeordneten Mode so lassen können, wie er ist
                                    if anz_VZ_gleich_R1_neuer_Mode_pos >= anz_VZ_gleich_R1_neuer_Mode_neg
                                        % Ja, können wir
                                        SF_R1 = 1;
                                    else
                                        % Nein, er sollte hierfür gespiegelt werden
                                        SF_R1 = -1;
                                    end
                                    % Anzahl der gleichen Vorzeichen bezüglich aller Knotenverschiebungen ermitteln in der Richtung der betraglich zweitgrößten Verformungen
                                    % -> einmal mit dem neu zugeordneten Mode, so wie er ist
                                    anz_VZ_gleich_R2_neuer_Mode_pos = sum(sign(v_Bezugsmode_akt_i_minus_1(:,Idx_Spalte_zweitmax)./v_neuer_mode_akt_i(:,Idx_Spalte_zweitmax)) == 1);
                                    % -> einmal genau mit der gespiegelten Variante des neu zugeordneten Modes
                                    anz_VZ_gleich_R2_neuer_Mode_neg = sum(sign(v_Bezugsmode_akt_i_minus_1(:,Idx_Spalte_zweitmax)./(-v_neuer_mode_akt_i(:,Idx_Spalte_zweitmax))) == 1);
                                    % Jetzt prüfen, ob wir für möglichst viele gleichgerichtete Knotenverschiebungen IN RICHTUNG R2 den neu zugeordneten Mode so lassen können, wie er ist
                                    if anz_VZ_gleich_R2_neuer_Mode_pos >= anz_VZ_gleich_R2_neuer_Mode_neg
                                        % Ja, können wir
                                        SF_R2 = 1;
                                    else
                                        % Nein, er sollte hierfür gespiegelt werden
                                        SF_R2 = -1;
                                    end
                                    % Überprüfung: Switch NICHT IN ORDNUNG, wenn ich für die obige Bedingung in einer Richtung den Mode spiegeln müsste, in der anderen aber nicht!!!
                                    if SF_R1/SF_R2 == -1
                                        flag_changes_ok = 0;
                                    end
                                end
                                % -.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
                                % >..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>
                                % UND WEITERE (an dieser Stelle letzte)
                                % ZWISCHENÜBERPRÜFUNG VOM 16.07.2023, ob die Eigenperiode (und damit -frequenz) des neu zugeordneten Modes nicht negativ ist 
                                % (dann ist es nämlich ein kinematischer Mode, was wiederum zu einem komplexen Eigenvektor führt und komplexe Einträge im Lastvektor führen anschließend zum Systemabsturz in SAP2000!)
                                if T_i(Moden_vergleich(index_kleinste_Diff_akt_tats)) < 0
                                    flag_changes_ok = 0;
                                    % Kurze informative Ausgabe hierzu:
                                    fprintf(1,['\n NOTE: In the current step %d, mode %d from step %d was actually assigned to\n',...
                                        'the new mode %d on the basis of the effective modal masses!\n',...
                                        'However, as the latter has a negative natural frequency and \n',...
                                        'is therefore presumably kinematic, this was prevented!\n\n'],arg.info.nummer,ModeNr_akt_i_minus_1,arg.info.nummer-1,Moden_vergleich(index_kleinste_Diff_akt_tats))
                                end
                                % (Ende: Zwischenüberprüfung vom 16.07.2023)
                                % >..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>..>
                                % Wenn die "Flag_changes_ok" auf "true" bzw. "1" steht:
                                if flag_changes_ok
                                    % Dann den entspr. "mode changes" nun in dem neu aufgebauten Feld "arg.comp.modes.changes" definieren,
                                    % sofern im aktuellen Schritt noch kein Mode dieser (neuen) aktuellen Eigenform zugeordnet wurde (was dann ja auch ein Widerspruch wäre):
                                    arg = sub_define_mode_changes(arg,ModeNr_akt_initial,ModeNr_akt_i_minus_1,Moden_vergleich(index_kleinste_Diff_akt_tats),PHI_n(:,:,index_kleinste_Diff_akt_tats));
                                % "else"-Fall (zu "if flag_changes_ok") gibt es an dieser Stelle nicht, da er jetzt nachfolgend noch mit zu der gescheiterten Mode-Switch-Analyse dazugezählt wird!
                                end
                            end
                        end
                        if ~(length(index_kleinste_Diff_akt_tats) == 1 && ~flag_relevante_moden_akt_aehnlich) || (exist('flag_changes_ok','Var') && ~flag_changes_ok) % NEU (vom 07.06.2023, statt des bisherigen reinen "else"-Falls zu "if (length(index_kleinste_Diff_akt_tats) == 1 && ~flag_relevante_moden_akt_aehnlich)")
                            % Fall: Eine solch eindeutige Zuordnung war nicht möglich, sondern
                            % es wurden unterschiedliche Zeilen gefunden, die in Frage kämen
                            % (oder vielleicht auch gar keine, also index_akt_tats = empty),
                            % oder die kleinste und zweitkleinste Differenz lagen so nah beieinander,
                            % dass die Zuordnung nicht so belastbar ist, ODER (NEU) der eigentlich
                            % gefundene "changes" war einfach (aufgrund der Verformungs-VZ in untersch.
                            % Richtungen) nicht "ok".
                            % ...Neue "Ultima Ratio" (vom 23.01.2023, überarbeitet am 05.07.2023):..........................................................................................................................................................................................................................................................................
                            % => IST DER AKTUELL BETRACHTETE MODE SICH...
                            % A) HINSICHTLICH SEINER FREQUENZ und
                            % B) HINSICHTLICH SEINER RICHTUNG DER MIT ABSTAND (betraglich) GRÖßTEN VERSCHIEBUNGEN 
                            % -> Zu A):
                            % Eigenperioden aller ermittelten Eigenvektoren des
                            % vorherigen "Modal"-Lastfalls auslesen
                            if arg.info.nummer == 2
                                arg.info.name_modal_before_old = arg.info.name_modal;
                            else
                                arg.info.name_modal_before_old = strrep(arg.info.name_modal_old,num2str(arg.info.nummer),num2str(arg.info.nummer-1));
                            end
                            Ti_alt = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),arg.info.name_modal_before_old),4));                       
                            % Eigenperioden aller ermittelten Eigenvektoren des
                            % aktuellen "Modal"-Lastfalls auslesen
                            Ti_neu = cellfun(@str2num,erg_i_minus_1.ModalParticipatingMassRatios.Werte(strcmp(erg_i_minus_1.ModalParticipatingMassRatios.Werte(:,1),arg.info.name_modal_old),4));
                            % Kurze Zwischenermittlung aller
                            % Periodendifferenzen (wird evtl. im nachfolgenden "elseif"-Fall, unter "3.)" benötigt!!!)
                            periodendiffs = Ti_neu-Ti_alt;
                            % Alte Periode des aktuellen Modes von sämtlichen
                            % aktuellen Perioden abziehen
                            perioden_diff = Ti_neu-Ti_alt(ModeNr_akt_i);
                            % Frage: Ist die betraglich kleinste Abweichung
                            % beim aktuellen Mode selbst vorhanden?
                            % >> Dabei sollte aber gewährleistet sein (2. Prüfung), dass das Verhältnis der kleinsten zur zweitkleinsten Differenz geringer ist als 50% (damit Frequenzen nicht zu nah beieinander liegen und Aussage wirklich belastbar ist)!
                            second_smallest_diffs = mink(abs(perioden_diff),2); % werden automatisch aufsteigend sortiert (also: 1. Zahl -> Absolutes, betragliches Minimum; 2. Zahl -> betraglich zweitkleinster Wert!!!)
                            ModeNr_gem_frequ_zuordnung = find(abs(perioden_diff)==second_smallest_diffs(1));
                            if ModeNr_gem_frequ_zuordnung == ModeNr_akt_i && second_smallest_diffs(1)/second_smallest_diffs(2) < 0.5
                                % Fall: Zumindest im Hinblick auf die Eigenperioden bzw. -frequenzen
                                %       scheint der aktuelle Mode sich selbst zugeordnet werden zu können
                                flag_selbstzuordnung_freq = 1;
                            elseif arg.comp.algodec == 1 && (ModeNr_gem_frequ_zuordnung == ModeNr_akt_i || ... % 1.)
                                   (find(abs(Ti_neu(ModeNr_akt_i)-Ti_alt)==min(abs(Ti_neu(ModeNr_akt_i)-Ti_alt))) == ModeNr_akt_i ||...
                                                find(abs(Ti_neu-Ti_alt(ModeNr_gem_frequ_zuordnung))==min(abs(Ti_neu-Ti_alt(ModeNr_gem_frequ_zuordnung)))) == ModeNr_gem_frequ_zuordnung) ||... % 2.)
                                    (all(periodendiffs(setdiff([ModeNr_akt_i-1,ModeNr_akt_i,ModeNr_akt_i+1],0)) > 0.05) &&...
                                                max(periodendiffs(setdiff([ModeNr_akt_i-1,ModeNr_akt_i,ModeNr_akt_i+1],0))/min(periodendiffs(setdiff([ModeNr_akt_i-1,ModeNr_akt_i,ModeNr_akt_i+1],0)))) < 10 ) ) % 3.)
                                % Neue "Ultima ultima Ratio" (vom 07.06.2023), die NUR IM FALL "arg.comp.algodec == 1, sprich bei vom Benutzer gewünschtem Mut zum Risiko durch Stärkung der Algo-Entscheidungen Anwendung findet:
                                % 1.) Ist vielleicht wenigstens "ModeNr_gem_frequ_zuordnung == ModeNr_akt_i" (auch wenn das Abw.-verh. die 50%-Regel nicht einhält), ODER 
                                % 2.) KEINE Zuordnung der jeweiligen "Gegenüberliegenden" von T_alt_ModeNr_akt_i bzw. T_neu_ModeNr_gem_frequ_zuordnung möglich
                                %     (Bsp. für 2.): T_1_alt passt am besten zu T_2_neu, aber T_1_neu passt auch am besten zu T_1_alt ODER T_2_alt passt auch am besten zu T_2_neu!!!), ODER
                                % 3.) Es haben sich alle (max.) drei Perioden "um die aktuelle Nummer herum" (also sprich: bei Mode 2: T_1, T_2 und T_3) in ähnlichem Maße ALLE vergrößert...
                                %     Dann ist es eine Art "Blockverschiebung" der Perioden und es gibt vermutlich keine Vertauschungen
                                flag_selbstzuordnung_freq = 1;
                            else
                                % Ansonsten ist die Frequenz-Zuordnung wirklich gescheitert!
                                flag_selbstzuordnung_freq = 0;
                            end
                            % -> Zu B):
                            % Maximale betragliche Verschiebung und deren zugehörige Richtung ermitteln...
                            % ... für den Bezugsmode in der Form "i-1"
                            % Zeile (Knoten) und Spalte (Richtung) mit der betraglich maximalen Verschiebung identifizieren
                            [Idzs_Zeilen_max_pot,Idzs_Spalte_max_pot] = find(abs(v_Bezugsmode_akt_i_minus_1(:,:))==max(max(abs(v_Bezugsmode_akt_i_minus_1(:,:)))));
                            Idx_Zeile_Rmax_i_minus_1 = Idzs_Zeilen_max_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            Idx_Spalte_Rmax_i_minus_1 = Idzs_Spalte_max_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            % Zugehörige betragliche Verformung ermitteln
                            max_Betrag_V_RmaxV_Schritt_i_minus_1 = abs(v_Bezugsmode_akt_i_minus_1(Idx_Zeile_Rmax_i_minus_1,Idx_Spalte_Rmax_i_minus_1));
                            % ... für den neuen Mode (mit derselben Nummer) in der Form "i"
                            % Zeile (Knoten) und Spalte (Richtung) mit der betraglich maximalen Verschiebung identifizieren
                            [Idzs_Zeilen_max_pot,Idzs_Spalte_max_pot] = find(abs(v_Vergleichsmode_akt_i(:,:))==max(max(abs(v_Vergleichsmode_akt_i(:,:)))));
                            Idx_Zeile_Rmax_i = Idzs_Zeilen_max_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            Idx_Spalte_Rmax_i = Idzs_Spalte_max_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            % Zugehörige betragliche Verformung ermitteln
                            max_Betrag_V_RmaxV_Schritt_i = abs(v_Vergleichsmode_akt_i(Idx_Zeile_Rmax_i,Idx_Spalte_Rmax_i));
                            % Maximale betragliche Verschiebung in der Richtung mit den betraglich zweitgrößten Verschiebungen und deren zugehörige Richtung ermitteln...
                            % ... für den Bezugsmode in der Form "i-1"
                            % Zeile (Knoten) und Spalte (Richtung) mit der betraglich maximalen Verschiebung identifizieren
                            [Idzs_Zeilen_Rzweitmax_pot,Idzs_Spalte_Rzweitmax_pot] = find(abs(v_Bezugsmode_akt_i_minus_1(:,setdiff(1:3,Idx_Spalte_Rmax_i_minus_1)))==max(max(abs(v_Bezugsmode_akt_i_minus_1(:,setdiff(1:3,Idx_Spalte_Rmax_i_minus_1))))));
                            Idx_Zeile_Rzweitmax_i_minus_1 = Idzs_Zeilen_Rzweitmax_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            Idx_Spalte_Rzweitmax_i_minus_1 = Idzs_Spalte_Rzweitmax_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            % Zugehörige betragliche Verformung ermitteln
                            max_Betrag_V_RzweitmaxV_Schritt_i_minus_1 = abs(v_Bezugsmode_akt_i_minus_1(Idx_Zeile_Rzweitmax_i_minus_1,Idx_Spalte_Rzweitmax_i_minus_1));
                            % ... für den Bezugsmode in der Form "i"
                            % Zeile (Knoten) und Spalte (Richtung) mit der betraglich maximalen Verschiebung identifizieren
                            [Idzs_Zeilen_Rzweitmax_pot,Idzs_Spalte_Rzweitmax_pot] = find(abs(v_Vergleichsmode_akt_i(:,setdiff(1:3,Idx_Spalte_Rmax_i)))==max(max(abs(v_Vergleichsmode_akt_i(:,setdiff(1:3,Idx_Spalte_Rmax_i))))));
                            Idx_Zeile_Rzweitmax_i = Idzs_Zeilen_Rzweitmax_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            Idx_Spalte_Rzweitmax_i = Idzs_Spalte_Rzweitmax_pot(1); % bei mehrfachem Auftreten dieses betraglichen Maximums: einfach den ersten Eintrag betrachten
                            % Zugehörige betragliche Verformung ermitteln
                            max_Betrag_V_RzweitmaxV_Schritt_i = abs(v_Vergleichsmode_akt_i(Idx_Zeile_Rzweitmax_i,Idx_Spalte_Rzweitmax_i));
                            % Richtungen vergleichen unter der Bedingung, dass sowohl in Schritt (i-1) als auch in Schritt (i) der Unterschied zwischen |v|max_Rmax > 2*|v|max_Rzweitmax
                            if Idx_Spalte_Rmax_i_minus_1 == Idx_Spalte_Rmax_i && Idx_Spalte_Rzweitmax_i_minus_1 == Idx_Spalte_Rzweitmax_i ...
                                    && max_Betrag_V_RmaxV_Schritt_i_minus_1 >= 2*max_Betrag_V_RzweitmaxV_Schritt_i_minus_1 && max_Betrag_V_RmaxV_Schritt_i >= 2*max_Betrag_V_RzweitmaxV_Schritt_i
                                % -> Richtungs-Untersuchung der betraglich maximalen Verschiebungen liefert keine "Unannehmlichkeiten", die einer Selbstzuordnung im Wege stünden!
                                flag_selbstzuordnung_R_v_betraglich_max = 1;
                            else
                                % -> Sonst: Selbstzuordnung definitiv nicht möglich!
                                flag_selbstzuordnung_R_v_betraglich_max = 0;
                            end
                            % Wenn jetzt laut A) (bez. der Frequenzen) UND B) (bez. der maßg. Richtung) eine Selbstzuordnung identifiziert wurde:
                            if flag_selbstzuordnung_freq && flag_selbstzuordnung_R_v_betraglich_max
                                % Mode einfach in "arg.comp.modes.changes" sich
                                % selbst zuordnen (diese überflüssige Zeile wird
                                % später bereinigt)
                                arg.comp.modes.changes = [arg.comp.modes.changes; [ModeNr_akt_initial ModeNr_akt_i_minus_1 ModeNr_akt_i_minus_1]];
                                % Und kurze informative Ausgabe
                                disp(' ');
                                fprintf(1,['In step %d, the mode %d (initial mode %d) was assigned to itself,\n',...
                                           'by comparing the signs of the displacements in the decisive directions.\n',...
                                           'and via the frequency similarity in the current and previous step.\n',...
                                           '-> Please check after the calculation whether this is correct!\n'],arg.info.nummer,ModeNr_akt_i_minus_1,ModeNr_akt_initial)
                                % ...(Ende: Neue "Ultima Ratio" (vom 23.01.2023, überarbeitet am 05.07.2023))................................................................................................................................................................................................................................................................
                            % Sonst ist halt doch eine Benutzereingabe vonnöten
                            else
                                % Dann KANN und SOLLTE dieser Algorithmus die Zuordnung nicht
                                % selbst durchführen, sondern den Benutzer durch eine entspr.
                                % Eingabe-Aufforderung entscheiden lassen (denn er kann sich
                                % die Moden visuell in SAP2000 anschauen und eine vernünftige
                                % Zuordnung treffen):
                                % "tic-toc"-Beziehung aufbauen
                                t_local = tic;
                                % Und ggf. eine kurze (informative)
                                % Mail rausschicken
                                if isfield(arg.info,'mail')
                                    % Inhalt der Mail schreiben
                                    arg.info.mail.content = sprintf(['ATTENTION:\n',...
                                        'For the current calculation in step ',num2str(arg.info.nummer),'\n',...
                                        'the CAAP tool requires a user-input\n',...
                                        'due to an unclear mode-change assignment!']);
                                    % Mail rausschicken
                                    send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                                        arg.info.mail.subject,arg.info.mail.content)
                                end
                                % While-Schleife, so lange, bis was eingetippt wurde, was sich in
                                % eine Zahl (Skalar) überführen lässt
                                flag_changes_akt = 0; % Noch keine verwertbare Eingabe
                                while ~flag_changes_akt
                                    % Eingabe-Aufforderung - ggf. mit akustischer Warnung
                                    if arg.info.sound == 0.5 || arg.info.sound == 1
                                        try
                                            hupe('gong');
                                        catch
                                            disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                                        end
                                    end
                                    % Eingabe-Aufforderung
                                    eingabestring = input(sprintf(['\n Mode %d of the modal analysis in step %d could not be assigned to a current mode in step %d!\n',...
                                        'Please take a look at the mode shapes in SAP2000 and enter the corresponding CURRENT mode number: '],ModeNr_akt_i_minus_1,(arg.info.nummer-1),arg.info.nummer),'s');
                                    % Eingabe verarbeiten
                                    if ist_typ(str2double(eingabestring),'int')
                                        % Super Eingabe!
                                        flag_changes_akt = 1;
                                        % arg.comp.modes.changes füttern
                                        arg.comp.modes.changes = [arg.comp.modes.changes; [ModeNr_akt_initial ModeNr_akt_i_minus_1 str2double(eingabestring)]];
                                    end
                                end
                                % Ausgabe der Unterbrechungszeit
                                % (relevant, falls man die Eingabe-Aufforderung erst
                                % Stunden später bemerkt hat)
                                sec_local = toc(t_local); % [s]
                                disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
                                hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
                                disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
                            end
                        end              
                    % -ENDE:--MODE-SWITCH-UNTERSUCHUNG-FÜR-DEN-AKTUELLEN-MODE--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                    % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                end % if max([min(Mat_Diff(:,1)) min(Mat_Diff(:,2)) min(Mat_Diff(:,3))]) > 0.05
            % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % <><><><><><><><> ENDE Alternative Variante II: Versuch der Mode-Zuordnung über die Eigenformen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
            % <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        end
        % Mode-Zuordnungsflage verbrennen
        clear flag_ModeZuordnung_ueber_Meff
    end % for i_mode = 1:anz_moden
    % --::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::
    % >> Abschließende Überprüfung (nachdem ALLE MODEN abgehandelt wurden),
    %    ob - wenn es entsprechende changes gab - die Zuordnungen "plausibel" sind:
    if ~isempty(arg.comp.modes.changes)
        % HINTERGRUND:
        % Es muss ja nicht nur 1:1-Vertauschungen geben, sodass
        % man sagen könnte: Wenn es eine Zeile [1 1 2] in arg.comp.modes.changes
        % gibt, MUSS es auch eine Zeile [2 2 1] geben, denn es ist ja auch
        % sowas denkbar (wenn die Moden 1, 2, 3 und 5 - Nrn gem. der vorherigen
        % bzw. auch gleich der initialen Modal-Analyse - berücksichtigt werden):
        % arg.comp.modes.changes = [1 1 2; 2 2 3; 3 3 1],
        % => Das heißt, es müssen konkret zwei Aspekte überprüft werden:
        %   1.) JEDE Zahl in Spalte 3 von arg.comp.modes.changes, sprich jede
        %       neu zugeordnete Mode-Nr., darf NUR EINMAL auftreten (in der
        %       ersten bzw. zweiten Spalte tritt jede Zahl autom. nur einmal auf).
        %       Das ist genau dann der Fall, wenn die "uniquen" Werte der
        %       Spalte 3 dieselbe Länge ergeben wie Spalte 3 an sich.
        %   2.) Jede (aktuelle) Mode-Nummer, die in Spalte 3 auftaucht und
        %       bei den betrachteten Mode-Nrn. der vorherigen Modal-Analyse
        %       in der zuletzt im Schritt (i-1) belegten Variablen Moden_aktuell
        %       ebenfalls, MUSS auch in Spalte 2 von arg.comp.modes.changes
        %       auftauchen, sprich: ein solcher (bereits berücksichtigter)
        %       Mode muss nun einen neuen (aktuellen) Mode zugewiesen
        %       bekommen, da er ja nicht mehr sich selbst zugehörig ist!
        % NICHT ZULÄSSIG wäre hingegen:
        % arg.comp.modes.changes = [1 1 2; 2 2 3; 5 5 4], da hier der berücksichtigte
        % Mode 3 (Nr. gem. Modal-Analyse im Schritt (i-1)) nicht mehr sich
        % selbst zugeordnet sein kann (schließlich wurde der aktuelle Mode 3
        % dem vorherigen Mode 2 zugeordnet), allerdings hat der alte Mode 3
        % noch keinen neuen Partner!!!
        % Kurze Zwischenermittlungen, damit die nachfolgende if-Abfrage leichter
        % nachzuvollziehen ist:
        % -> Ermittlung derjenigen Moden, die einem anderen Mode der vorherigen Modal-
        % Analyse neu zugewiesen wurden (sprich in der 3. Spalte von arg.comp.modes.changes
        % "auftauchen") und aufgrund der Tatsache, dass sie selbst bisher (so auch im Schritt
        % (i-1)) berücksichtigt wurden, nun ihrerseits einen neuen (aktuellen) Partner-Mode
        % brauchen (sprich: in Spalte 2 von arg.comp.modes.changes auftauchen müssen):
        indizes_moden_akt_betrachtet_und_neu_zugewiesen_logical = ismember(arg.comp.modes.changes(:,3),Moden_aktuell);
        moden_akt_neu_zugewiesen = arg.comp.modes.changes(indizes_moden_akt_betrachtet_und_neu_zugewiesen_logical,3); % Moden, die AKTUELL angesetzt wurden ("Moden_aktuell") UND ZU DENEN im aktuellen Switch neue Zuweisungen vorliegen ("arg.comp.modes.changes(:,3)")
        % Nun Abfrage der oben erläuterten zwei Kriterien:
        if ~(length(unique(arg.comp.modes.changes(:,3)))==length(arg.comp.modes.changes(:,3))) || ~all(ismember(moden_akt_neu_zugewiesen,arg.comp.modes.changes(:,2)))
            % Falls nicht, KANN und SOLLTE dieser Algorithmus auch dann die
            % Zuordnung nicht selbst durchführen, sondern den Benutzer durch
            % eine entspr. Eingabe-Aufforderung entscheiden lassen (denn er kann
            % sich die Moden visuell in SAP2000 anschauen und eine vernünftige
            % Zuordnung treffen):
            % Kurze Zwischenermittlung all der Moden, die nun einer
            % "sauberen" Zuordnung durch den Benutzer bedürfen:
            moden_zuletzt_betrachtet_und_betroffen = sort(unique([arg.comp.modes.changes(:,2);moden_akt_neu_zugewiesen]));
            % Nun die automatisiert ermittelten FALSCHEN changes
            % zwischenspeichern...
            moden_changes_falsch = arg.comp.modes.changes;
            % ... und das alte Feld leeren
            arg.comp.modes.changes = [];
            % Und eine kurze Ausgabe schonmal vorne weg:
            disp(' ');
            fprintf(2,['In step %d, mode changes were automatically determined for the following modes,\n',...
                      'that result in an "implausible" assignment:\n'],arg.info.nummer)
            for i_changes = 1:size(moden_changes_falsch,1)
                fprintf(2,'Mode %d of the previous modal analysis (initial mode: %d) was assigned to the current mode %d.\n',...
                    moden_changes_falsch(i_changes,2),moden_changes_falsch(i_changes,1),moden_changes_falsch(i_changes,3));
            end
            fprintf(2,'Natural modes NOT listed above have been assigned to themselves!\n')
            % Ggf. kurze akustische Warnung einstreuen, dass jetzt
            % eine Eingabe erfolgen muss, bis das Programm
            % weiterläuft...
            if arg.info.sound == 0.5 || arg.info.sound == 1
                try
                    hupe('gong');
                catch
                    disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                end
            end
            % Unterbrechungszeit (durch die Eingabe)
            % erfassen (relevant, wenn man die Eingabeaufforderung erst
            % Stunden später bemerkt hat)
            % "tic-toc"-Beziehung aufbauen
            t_local = tic;
            % Und ggf. eine kurze (informative)
            % Mail rausschicken
            if isfield(arg.info,'mail')
                % Inhalt der Mail schreiben
                arg.info.mail.content = sprintf(['ATTENTION:\n',...
                    'For the current calculation in step ',num2str(arg.info.nummer),'\n',...
                    'the CAAP tool requires a user-input\n',...
                    'due to an unclear mode-change assignment!']);
                % Mail rausschicken
                send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                    arg.info.mail.subject,arg.info.mail.content)
            end
            % Übergeordnete While-Schleife, so lange, bis es wirklich eine
            % plausible Zuordnung ergibt
            flag_plausibel = 0; % Erstmal liegt diese noch nicht vor
            while ~flag_plausibel
                % While-Schleifen für alle changes, so lange, bis jeweils was
                % eingetippt wurde, was sich in eine Zahl (Skalar) überführen lässt
                disp('Please take a look at the mode shapes in SAP2000 and...')
                for i_changes = 1:length(moden_zuletzt_betrachtet_und_betroffen)
                    flag_changes_akt = 0; % Noch keine verwertbare Eingabe für den aktuellen changes
                    while ~flag_changes_akt
                        % Eingabe-Aufforderung
                        eingabestring = input(sprintf('enter the corresponding CURRENT mode number for the mode %d of the previous modal analysis: ',moden_zuletzt_betrachtet_und_betroffen(i_changes)),'s');
                        % Eingabe verarbeiten
                        if ist_typ(str2double(eingabestring),'int')
                            % Super Eingabe!
                            flag_changes_akt = 1;
                            % Zwischenschritt: Prüfen, ob der Mode (aus Schritt (i-1)),
                            % zu dem gerade eine Eingabe getätigt wurde, bereits FRÜHER
                            % in Spalte 3 von arg.comp.modes.changes aufgetreten ist
                            % (ergo: jetzt, in Schritt i, also in Spalte 3 von arg.comp.modes.changes_old vorhanden ist)
                            if ~isempty(arg.comp.modes.changes_old) && ismember(moden_zuletzt_betrachtet_und_betroffen(i_changes),arg.comp.modes.changes_old(:,3))
                                % Fall: Der bei der gerade erfolgten Eingabe betrachtete Mode unterlag
                                % zuvor bereits einem Mode-Switch
                                ModeNr_initial_tmp = arg.comp.modes.changes_old(arg.comp.modes.changes_old(:,3)==moden_zuletzt_betrachtet_und_betroffen(i_changes),1);
                            else
                                ModeNr_initial_tmp = moden_zuletzt_betrachtet_und_betroffen(i_changes);
                            end
                            % arg.comp.modes.changes füttern
                            arg.comp.modes.changes = [arg.comp.modes.changes; [ModeNr_initial_tmp moden_zuletzt_betrachtet_und_betroffen(i_changes) str2double(eingabestring)]];
                        end
                    end
                end
                % Außerdem kurz abfragen, ob es weitere Mode-Switches gibt, die der
                % Algorithmus gar nicht auf dem Schirm hatte:
                antwort = input(sprintf('Are there still any other mode changes? Please enter 1 for "Yes" or 0 for "No": '));
                if antwort == 1
                    % Dann: Aufforderung zur Angabe dieser!
                    flag_weitere_Angaben_plausibel = 0;
                    while ~flag_weitere_Angaben_plausibel
                        weitere_Angaben = input(sprintf('Then please specify in the usual form [no_mode_initial no_mode_previous no_mode_current; no_mode_initial no_mode_previous no_mode_current; ...]: ' ));
                        % Prüfen, ob Angabe plausibel:
                        % ACHTUNG: Nur zwei rein formale Prüfungen, kein vollumfänglicher
                        % inhaltlicher Abgleich mit den bisherigen Angaben!!!)
                        if ist_typ(weitere_Angaben,'array') && size(weitere_Angaben,2)==3 && length(unique(weitere_Angaben(:,2)))==length(weitere_Angaben(:,2))
                            flag_weitere_Angaben_plausibel = 1;
                            arg.comp.modes.changes = [arg.comp.modes.changes; weitere_Angaben];
                        end
                    end
                end
                % Nun noch einmal prüfen, ob jetzt eine plausible Zuordnung vorliegt
                indizes_moden_akt_betrachtet_und_neu_zugewiesen_logical = ismember(arg.comp.modes.changes(:,3),Moden_aktuell);
                moden_akt_neu_zugewiesen = arg.comp.modes.changes(indizes_moden_akt_betrachtet_und_neu_zugewiesen_logical,3); % Moden, die AKTUELL angesetzt wurden ("Moden_aktuell") UND ZU DENEN im aktuellen Switch neue Zuweisungen vorliegen ("arg.comp.modes.changes(:,3)")
                if length(unique(arg.comp.modes.changes(:,3)))==length(arg.comp.modes.changes(:,3)) && all(ismember(moden_akt_neu_zugewiesen,arg.comp.modes.changes(:,2)))
                    % Geschafft! :)
                    flag_plausibel = 1;
                    % Jetzt kann es allerdings noch sein, dass der Algorithmus
                    % fälschlicherweise einen Mode "ins Spiel gebracht" hat, der
                    % überhaupt nicht von einem changes betroffen ist, was der
                    % Benutzer eben mit einer "Selbst-Zuweisung" angeben wird.
                    % -> Dann ergäbe sich eine Zeile in arg.comp.modes.changes mit
                    %    identischen Zahlen; solche Zeilen werden nun gelöscht!
                    arg.comp.modes.changes((arg.comp.modes.changes(:,2)==arg.comp.modes.changes(:,3)),:) = []; % Alle Einträge einer Zeile "empty" zu überschreiben löscht die komplette Zeile!
                else
                    % Strafrunde mit kurzer Info
                    fprintf(2,'The manual assignments again do not result in a plausible assignment!!! Therefore, once again:\n')
                    arg.comp.modes.changes = [];
                end
            end
            % Ausgabe der Unterbrechungszeit
            % (relevant, falls man die Eingabe-Aufforderung erst
            % Stunden später bemerkt hat)
            sec_local = toc(t_local); % [s]
            disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
            hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
            disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
        end
    end % Ende: Plausibilitätskontrolle
    % --::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::--::
end % if arg.info.nummer > 1 


%% NACH ABSCHLUSS ALLER PLAUSIBILITÄTSKONTROLLEN MÖGLICHER SWITCHES (für sämtliche berücksichtigten Moden!!!): ÜBERGEORDNETE Überprüfung möglicher Vorzeichenwechsel (Richtungswechsel) sämtlicher betrachteter Moden
for i_mode = 1:anz_moden
    
    % Mode-Nummer des AKTUELL betrachteten Modes bezogen auf die INITIALE Modal-Analyse auslesen
    ModeNr_akt_initial = Moden_initial(i_mode);
    
    % Mode-Nummer des AKTUELL betrachteten Modes bezogen auf die VORHERIGE Modal-Analyse auslesen
    ModeNr_akt_i_minus_1 = Moden_aktuell(i_mode);

    % Vorarbeit: Mögliche "Mode-changes" berücksichtigen
    if isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_initial),arg.comp.modes.changes(:,1)))
        ModeNr_akt_i = ModeNr_akt_i_minus_1;
    else
        ModeNr_akt_i = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==ModeNr_akt_initial,3);
    end
    
    % (A) Knoten mit betraglich größter Verschiebung in der zu
    % diesem Mode korresp. EINEN oder WICHTIGSTEN* Richtung ermitteln und
    % von dieser Verschiebung das Vorzeichen auslesen sowie den zugehörigen
    % Knoten-Namen und Richtungs-Index:
    %    * Das heißt: -> Die Richtung, in der dieser Mode in den jew. Feldern arg.comp.modes.R_i
    %      früher genannt wird. 
    %      Bsp.: arg.comp.modes.Y = [-2 6 1]; arg.comp.modes.X = [1 -2 6];
    %      => Dann ist bei Mode 1 die "X"-Richtung offenbar die entscheidende! ("X-Mode" 1 bekommt z. B. erst im Zuge der Berechnung Verformungsanteile in Y-Richtung und wird somit in Y-Richtung relevant)
    % HINWEIS: Es wird BEWUSST nicht "einfach" die Richtung genommen, in der der jew. Mode die betraglich größte Verschiebungskomponente
    % aufweist, denn dies könnte ggf. im Zuge der Berechnung (zwischenzeitlich) wechseln und dann käme die VZ-Zuordnung durcheinander;
    % es wird aber unterstellt, dass die hier vorgesehene Vorgehensweise die jew. relevante(ste) Richtung abdeckt!
    [vz,joint,Idx_Richtung] = sub_get_direction(arg,erg_i_minus_1,ModeNr_akt_i,ModeNr_akt_initial);
    % Diese Daten für die Kontrolle im nächsten Schritt (arg.info.nummer + 1)
    % in der arg-Struktur abspeichern
    %{
            => Im Falle des "Standard"-Verfahrens:
            Je betrachteter Bebenrichtung eine Information (bezüglich des
            Knotens und Vorzeichens)
            => Im Falle des AMI-Verfahrens:
            Je eine Information (bezüglich des Knotens und Vorzeichens) 
            für ALLE in "arg.comp.modes.unique" auftretenden Moden 
    %}
    arg.comp.modes.kontrollinfos.vz(arg.info.nummer,i_mode) = vz;
    arg.comp.modes.kontrollinfos.joint.name(arg.info.nummer,i_mode) = {joint.name};
    arg.comp.modes.kontrollinfos.joint.knot_index(arg.info.nummer,i_mode) = joint.knot_index;
    arg.comp.modes.kontrollinfos.Idx_Richtung(arg.info.nummer,i_mode) = Idx_Richtung;
        
    % (B) Den Richtungskorrekturfaktor "SF" ermitteln (durch Abgleich der
    % Vorzeichen von betraglich maximaler Verschiebung des aktuell betrachteten
    % Modes in der Form der letzten Modal-Analyse (i-1) mit dem Vorzeichen der
    % Verschiebung desselben Knotens (in derselben Richtung) in der
    % aktuellen Form (der i-ten Modalanalyse)
    if arg.info.nummer == 1 || vz == 0 || arg.comp.modes.kontrollinfos.vz(arg.info.nummer-1,i_mode) == 0 % im 1. Inkrementschritt ODER wenn der Mode im Zustand "i" bzw. "i-1" praktisch keine Verformungen in der relevanten Richtung aufweist (vz == 0 bzw. arg.comp.modes.kontrollinfos.vz(arg.info.nummer-1,i_mode) == 0)
        arg.comp.modes.SF(arg.info.nummer,i_mode) = 1; % im ersten Schritt und bei (NOCH!!!) keiner wirklichen Verformung des akt. Modes in der relevanten Richtung -> KEIN VZW!
        % Im Fall einer wirklichen Verformung des akt. Modes in der relevanten Richtung 
        % (sprich: HIER im Fall vz ~= 0):
        if vz ~= 0
            % <<--Zwischenkontrolle: Überprüfung, ob die Summe der Verformungen des aktuellen Eigenvektors in der "relevanten" Richtung positiv ist --------------------------------------------------------------------------------------------------------------------------------------------
            % Relevante Daten zusammenstellen
            Zeilenidzs_richtiger_Mode = strcmp(erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(:,5),[num2str(ModeNr_akt_i),'.']);
            Daten_relevant = erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(Zeilenidzs_richtiger_Mode,[1 5:8]); % Spalte 1: Knotennummern, Spalte 5: Mode-Nr., Spalten 6-8: u1-, u2- & u3-Verschiebung
            % Modalen, INITIAL DEFINIERTEN Vorzeichen-Faktor ermitteln
            Moden_VZgerecht_Richtung_relevant = arg.comp.modes.(arg.comp.d_earthquake{1,(cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung)});
            VZ = Moden_VZgerecht_Richtung_relevant(abs(Moden_VZgerecht_Richtung_relevant)==ModeNr_akt_initial) / ModeNr_akt_initial; % VZ gem. Mode-Def.!!! (nicht tats. VZ der Eigenform)
            % Verformungskompontenten des aktuellen Eigenvektors in der "relevanten" Richtung auslesen
            PHI_R_relevant = (VZ*1) * cellfun(@str2num,Daten_relevant(:,Idx_Richtung+2)); % SF = 1!
            % Vektor der auf diese Richtung bezogenen Knotenmassen aufbauen
            n_Knot = length(PHI_R_relevant);
            M_R_relevant = cellfun(@str2num,arg.comp.erg.schritt_0.AssembledJointMasses.Werte(1:n_Knot,Idx_Richtung+2));
            % Summe der Knotenmassen multipliziert mit den jeweiligen Knotenverformungen
            Fb_res_R_relevant = M_R_relevant' * PHI_R_relevant;
            % Überprüfung:
            if Fb_res_R_relevant < 0
                % ACHTUNG: Negative Resultierende der Knotenkräfte des aktuellen Modes
                % in der "relevanten" Richtung!!!
                % Jetzt 2 Möglichkeiten:
                % (1) Wenn Mode richtungsmäßig NICHT geschützt UND in KEINER WEITEREN RICHTUNG ANGESETZT -> SF korrigieren (überschreiben)
                if (~isfield(arg.comp.modes,'dir_protected') || ~ismember(abs(ModeNr_akt_initial),abs(arg.comp.modes.dir_protected))) && sum(ismember(abs(arg.comp.modes.gesamt),ModeNr_akt_initial),'all') == 1 % durch 2. Prüfung wird diese if-Abfrage vermutlich nur bei arg.info.nummer == 1 erfüllt sein
                    arg.comp.modes.SF(arg.info.nummer,i_mode) = -1;
                    % -> Entsprechende Warnung ausgeben!
                    fprintf(2,['\n ATTENTION: In step %d, the SF determination for the %d mode resulted in a\n',...
                        'NEGATIVE resulting base shear in the relevant %s direction, which contradicts\n',...
                        'the sign convention for modal proportional load distributions\n',...
                        'and must not occur at all in the first increment step!\n',...s
                        'The calculated scaling factor was therefore corrected accordingly.\n',...
                        '-> Please check whether this is correct!\n'],arg.info.nummer,ModeNr_akt_i,arg.comp.d_earthquake{1,cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung})
                % (2) Wenn Mode jedoch richtungsmäßig BEWUSST VOM BENUTZER geschützt wurde ODER er NICHT NUR IN DER AKTUELLEN RICHTUNG ANGESETZT wurde -> Nichts tun, außer ihn über den negativen Fundamentschub zu informieren
                else
                    fprintf(2,['\n NOTE: In step %d, the SF determination for the mode %d resulted in a\n',...
                        'NEGATIVE resulting base shear in the relevant %s direction, which actually contradicts \n',...
                        'the sign convention for mode proportional load distributions.\n',...
                        'However, the sign is NOT adjusted,\n',...
                        'as the mode is EITHER directionally protected, OR considered in at least one other direction!\n',...
                        'Please note that other modes in this direction then should also have a negative base shear!\n'],arg.info.nummer,ModeNr_akt_i,arg.comp.d_earthquake{1,cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung})
                end
            end
        end
        % --Ende: Zwischenkontrolle->>------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    else
        arg.comp.modes.SF(arg.info.nummer,i_mode) = sub_check_direction(arg,erg_i_minus_1,ModeNr_akt_i,i_mode);
    end % if arg.info.nummer == 1 || vz == 0 || arg.comp.modes.kontrollinfos.vz(arg.info.nummer-1,i_mode) == 0
end % for i_mode = 1:anz_moden

% <<--Abschlusskontrolle: Überprüfung, ob der resultierende Fundamentschub der aktuellen Eigenvektoren in den jeweiligen Richtungen (bei mehreren zählt die "höherwertigste" (Rp wichtiger als Rs usw.) positiv ist --------------------------------------------------------------------------------------------------------------------------------------------
% arg.comp.modes.gesamt löschen (wird unten neu geschrieben)
arg.comp.modes.gesamt = [];
% arg.comp.f_b mit Matrix der bewusst berücksichtigten Fundamentschübe (sprich: ohne "zufällig" auch minimal auftretende X-Fundamentschübe eines eigentlichen Y-Modes) für den aktuellen Schritt erweitern
arg.comp.f_b_fictitious(:,:,arg.info.nummer) = zeros(length(arg.comp.modes.unique),size(arg.comp.d_earthquake,2)); % erstmal mit Nullen vorbelegen
% ÜBERGEORDNETE SCHLEIFE ÜBER ALLE BETRACHTETEN BEBENRICHTUNGEN
for i_R = 1:size(arg.comp.d_earthquake,2)
    % Zugehörigen Richtungsindex auslesen
    Idx_Richtung = arg.comp.d_earthquake{2,i_R};
    % In dieser Richtung angesetzte Moden auslesen
    Moden_R_akt = arg.comp.modes.(arg.comp.d_earthquake{1,i_R});
    % UNTERGEORDNETE SCHLEIFE ÜBER ALLE IN DIESER RICHTUNG ANGESETZTEN MODEN
    for i_mode = 1:length(Moden_R_akt)
        % Initiale Mode-Nr dieses Modes auslesen
        ModeNr_akt_initial_mit_VZ = Moden_R_akt(i_mode);
        % Modalen, INITIAL DEFINIERTEN Vorzeichen-Faktor ermitteln (bezüglich der aktuellen Richtung, darf aber richtungsübergreifend ohnehin nicht variieren!)
        VZ = ModeNr_akt_initial_mit_VZ / abs(ModeNr_akt_initial_mit_VZ);
        % Zwischenschritt: Mögliche "Mode-changes" berücksichtigen
        % (ACHTUNG: ZU DIESEM ZEITPUNKT ENTHÄLT "arg.comp.modes.changes" NUR DIE IN DIESEM SCHRITT DAZUGEKOMMENEN SWITCHES!
        % MAN MUSS ALSO ZUSÄTZLICH "arg.comp.modes.changes_old" BETRACHTEN!!!)
        if (isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_initial_mit_VZ),arg.comp.modes.changes(:,1)))) ... % 1. Überprüfung: Keine neuen changes vorh. oder sie betreffen den akt. Mode nicht!
           && (arg.info.nummer == 1 || (isempty(arg.comp.modes.changes_old) || (~isempty(arg.comp.modes.changes_old) && ~ismember(abs(ModeNr_akt_initial_mit_VZ),arg.comp.modes.changes_old(:,1))))) % 2. Überprüfung (AB Schritt 2 notw.): Keine bisherigen changes vorh. oder sie betreffen den akt. Mode nicht!
            ModeNr_akt_i = abs(ModeNr_akt_initial_mit_VZ);
        else
            % Frage nun: Taucht der aktuelle Mode denn jetzt in "arg.comp.modes.changes" auf (sprich: hat sich im aktuellen Schritt verschoben) 
            % ODER in "arg.comp.modes.changes_old" (Mode-Verschiebung war in einem der vorherigen Schritte)
            if ~(isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_initial_mit_VZ),arg.comp.modes.changes(:,1))))
                ModeNr_akt_i = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==abs(ModeNr_akt_initial_mit_VZ),3);
            elseif ~(isempty(arg.comp.modes.changes_old) || (~isempty(arg.comp.modes.changes_old) && ~ismember(abs(ModeNr_akt_initial_mit_VZ),arg.comp.modes.changes_old(:,1)))) % hier hätte man auch einfach "else" sagen können!
                ModeNr_akt_i = arg.comp.modes.changes_old(arg.comp.modes.changes_old(:,1)==abs(ModeNr_akt_initial_mit_VZ),3);
            end
        end
        % Relevante Daten zusammenstellen
        Zeilenidzs_richtiger_Mode = strcmp(erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(:,5),[num2str(ModeNr_akt_i),'.']);
        Daten_relevant = erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(Zeilenidzs_richtiger_Mode,[1 5:8]); % Spalte 1: Knotennummern, Spalte 5: Mode-Nr., Spalten 6-8: u1-, u2- & u3-Verschiebung
        % Zwischenschritt: Index des aktuellen Modes in arg.comp.modes.unique ermitteln (für "Zugriff" in spaltenweise nach den uniquen Nummern sortierten arg.comp.modes.SF)
        Idx_Mode_i_in_moden_unique = find(arg.comp.modes.unique==abs(ModeNr_akt_initial_mit_VZ));
        % Verformungskompontenten des aktuellen Eigenvektors in der "relevanten" Richtung auslesen
        PHI_R_relevant = (VZ*arg.comp.modes.SF(arg.info.nummer,Idx_Mode_i_in_moden_unique)) * cellfun(@str2num,Daten_relevant(:,Idx_Richtung+2));
        % Vektor der auf diese Richtung bezogenen Knotenmassen aufbauen
        n_Knot = length(PHI_R_relevant);
        M_R_relevant = cellfun(@str2num,arg.comp.erg.schritt_0.AssembledJointMasses.Werte(1:n_Knot,Idx_Richtung+2));
        % Summe der Knotenmassen multipliziert mit den jeweiligen Knotenverformungen
        Fb_res_R_relevant = M_R_relevant' * PHI_R_relevant;
        % Überprüfung: (wenn Fundamentschub nicht praktisch 0!!!)
        if Fb_res_R_relevant < 0 && ((arg.info.nummer > 1 && abs(Fb_res_R_relevant)/max(max(max(abs(arg.comp.f_b_fictitious)))) > 0.05) || (arg.info.nummer == 1 && abs(Fb_res_R_relevant) > 0.001)) % 2. Überprüfung stellt dabei sicher, dass es sich aber um einen "ernst zu nehmenden" Fundamentschub von wenigstens 5% des Maximalwerts handelt!
            % ACHTUNG: Negative Resultierende der Knotenkräfte des aktuellen Modes in der aktuellen Richtung, in der der Mode ja angesetzt wurde!!!
            % => Nun drei Fälle möglich:
            % (1) Aktueller Mode wird in KEINER "höherwertigen" Richtung angesetzt (*) und ist auch richtungsmäßig NICHT geschützt 
            % (*) ...denn wenn ja, ist das Fundamentschubinkrement in der "höheren" Richtung, selbst wenn aktuell noch 0, (perspektivisch) maßgebend! 
            if (i_R == 1 || i_R == 2 && ~ismember(ModeNr_akt_initial_mit_VZ,arg.comp.modes.(arg.comp.d_earthquake{i_R-1})) || i_R == 3 && ~ismember(ModeNr_akt_initial_mit_VZ,arg.comp.modes.(arg.comp.d_earthquake{i_R-1})) && ~ismember(ModeNr_akt_initial_mit_VZ,arg.comp.modes.(arg.comp.d_earthquake{i_R-2}))) ...
                    && (~isfield(arg.comp.modes,'dir_protected') || ~ismember(abs(ModeNr_akt_initial_mit_VZ),abs(arg.comp.modes.dir_protected)))
                % -> VZ-Definition in arg.comp.modes.R_akt korrigieren!!!* (NICHT SF korrigieren (überschreiben), da dieser Faktor wirklich für reine Spiegelungen von (praktisch gleichen) Moden stehen soll!)
                % *Allerdings auch NUR, wenn der Benutzer dies absegnet (da es bisher in allen Fällen eine plötzliche Spiegelung des Modes zur Folge gehabt hätte, die man nicht haben möchte)!!!
                % "tic-toc"-Beziehung aufbauen
                t_local = tic;
                % Und ggf. eine kurze (informative)
                % Mail rausschicken
                if isfield(arg.info,'mail')
                    % Inhalt der Mail schreiben
                    arg.info.mail.content = sprintf(['ATTENTION:\n',...
                        'For the current calculation in step ',num2str(arg.info.nummer),' the CAAP tool\n',...
                        'requires a user-side confirmation of a sign change for a certain mode!']);
                    % Mail rausschicken
                    send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                        arg.info.mail.subject,arg.info.mail.content)
                end
                % While-Schleife, so lange, bis eine 1 oder 0
                % eingetippt wurde!
                flag_eingabe_logical = 0; % Noch keine verwertbare Eingabe
                while ~flag_eingabe_logical
                    % Eingabe-Aufforderung - ggf. mit akustischer Warnung
                    if arg.info.sound == 0.5 || arg.info.sound == 1
                        try
                            hupe('gong');
                        catch
                            disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                        end
                    end
                % Eingabe-Aufforderung
                fprintf(2,['\n ATTENTION: In step %d, the SF determination for the mode %d led to a\n',...
                    'NEGATIVE base shear shear in the considered %s direction,\n',...
                    'which contradicts the sign convention for mode shape proportional load distributions!\n',...
                    '-> If the adjustment of the sign defined in "arg.comp.modes.(R_akt)" results in a\n',...
                    '   approximately mirrored and thus relieving load distribution in the %s direction,\n',...% Hinweis: Kann bei 3. Biegeeigenform auftreten, wenn mittlerer "Bauch" plötzlich maßgebend wird! Dann sollte die Lastverteilung sich nicht schlagartig umdrehen!
                    '   this should not be done (and the mode should be protected for a recalculation\n',...
                    '   by specifying it in "arg.comp.modes_dir_protected")!\n'],arg.info.nummer,ModeNr_akt_i,arg.comp.d_earthquake{1,cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung},arg.comp.d_earthquake{1,cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung})
                    eingabestring = input(sprintf(['Should the sign defined in "arg.comp.modes.(R_akt)" be adjusted accordingly?\n',...
                                                     'Please enter "1" for "yes" or "0" for "no": ']),'s');
                    % Eingabe verarbeiten
                    if ismember(str2double(eingabestring),[1 0])
                        % Super Eingabe!
                        flag_eingabe_logical = 1;
                        % Eingabe verwerten
                        if str2double(eingabestring) == 1
                            % VZ temporär in "Moden_R_akt" ändern und diese Variable nach der Schleife über alle Moden in der akt. Richtung dann an arg.comp.modes.R_akt übergeben
                            Moden_R_akt(i_mode) = Moden_R_akt(i_mode) * (-1);
                            Fb_res_R_relevant = Fb_res_R_relevant * (-1);
                            % >-> Kurze Zwischenprüfung, ob Mode noch in einer anderen (muss ja dann "unwichtigeren" sein) Richtung berücksichtigt wird: Dann sollte das VZ nicht einfach
                            %     geändert werden, sondern eine erneute Berechnung mit komplementären VZ dieses Modes (in beiden/allen Richtungen) durchgeführt werden!
                            if sum(ismember(arg.comp.modes.gesamt_initial,ModeNr_akt_initial_mit_VZ),'all') > 1
                                % Dann: Berechnung abbrechen! (Benutzer muss sie mit komplementären VZ DIESES MODES wiederholen!)
                                fprintf(2,['ATTENTION: The calculation is aborted because the above-mentioned mode was set in (at least) one other direction!\n',...
                                    'The calculation must therefore be repeated with complementary sign of mode %d.'],ModeNr_akt_i)
                                error('DETERMINATION!')
                            end
                            % (Ende: Zwischenprüfung) <-<
                        end
                    end
                end
                % Ausgabe der Unterbrechungszeit
                % (relevant, falls man die Eingabe-Aufforderung erst
                % Stunden später bemerkt hat)
                sec_local = toc(t_local); % [s]
                disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
                hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
                disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
            % (2) Aktueller Mode ist (seitens des Benutzers) richtungsmäßig geschützt
            elseif isfield(arg.comp.modes,'dir_protected') && ismember(abs(ModeNr_akt_initial_mit_VZ),abs(arg.comp.modes.dir_protected))
                % -> Nichts tun außer warnen! (allerdings nur, wenn dieser negative Fundamentschub neu ist!)
                if arg.info.nummer > 1 && arg.comp.f_b_fictitious(Idx_Mode_i_in_moden_unique,i_R,arg.info.nummer-1) >= 0
                    fprintf(2,['\n NOTE: In step %d, the SF determination for the mode %d resulted in a\n',...
                        'NEGATIVE resulting base shear in the relevant %s direction, which actually contradicts \n',...
                        'the sign convention for mode proportional load distributions.\n',...
                        'However, the sign is NOT adjusted, as the mode is directionally protected!\n'],arg.info.nummer,ModeNr_akt_i,arg.comp.d_earthquake{1,cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung})
                end
            % (3) Aktueller Mode wird in (mind.) einer "höherwertigen" Richtung angesetzt, ist aber nicht geschützt
            else
                % -> Nichts tun außer warnen! (allerdings nur, wenn dieser negative Fundamentschub neu ist!)
                if arg.info.nummer > 1 && arg.comp.f_b_fictitious(Idx_Mode_i_in_moden_unique,i_R,arg.info.nummer-1) >= 0
                    fprintf(1,['\n NOTE: In step %d, the SF determination for the mode %d resulted in a\n',...
                        'NEGATIVE resulting base shear in the relevant %s direction, which actually contradicts \n',...
                        'the sign convention for mode proportional load distributions.\n',...
                        'However, the sign is NOT adjusted, as the mode is also considered in a "higher-order" direction!\n'],arg.info.nummer,ModeNr_akt_i,arg.comp.d_earthquake{1,cell2mat(arg.comp.d_earthquake(2,:))==Idx_Richtung})
                end
            end
        end
        % >> Kurze Zwischenprüfung, ob in der aktuelle Mode in einer vorherigen (höherwertigen) Richtung angesetzt wird und dort richtungsmäßig geändert wurde
        % (obwohl in "if" und "elseif" dasselbe passiert, so programmiert, da "if"-Abfrage sonst fast unlesbar!)
        if (i_R == 2 && (ismember(abs(ModeNr_akt_initial_mit_VZ),abs(arg.comp.modes.(arg.comp.d_earthquake{i_R-1}))) && ~ismember(ModeNr_akt_initial_mit_VZ,arg.comp.modes.(arg.comp.d_earthquake{i_R-1})))) % 2. Prüfung: Mode überhaupt in Rp angesetzt, 3. Prüfung: Wird jetzt mit anderem VZ angesetzt?
            % Wenn ja: Mode-VZ natürlich auch in der aktuellen Richtung daran anpassen (ändern)
            Moden_R_akt(i_mode) = Moden_R_akt(i_mode) * (-1);
            Fb_res_R_relevant = Fb_res_R_relevant * (-1);
        elseif i_R == 3 && ((ismember(abs(ModeNr_akt_initial_mit_VZ),abs(arg.comp.modes.(arg.comp.d_earthquake{i_R-1}))) && ~ismember(ModeNr_akt_initial_mit_VZ,arg.comp.modes.(arg.comp.d_earthquake{i_R-1}))) ... % 2. Prüfung: Mode überhaupt in Rs angesetzt, 3. Prüfung: Wird jetzt mit anderem VZ angesetzt?
                        || (ismember(abs(ModeNr_akt_initial_mit_VZ),abs(arg.comp.modes.(arg.comp.d_earthquake{i_R-2}))) && ~ismember(ModeNr_akt_initial_mit_VZ,arg.comp.modes.(arg.comp.d_earthquake{i_R-2}))))     % 2. Prüfung: Mode überhaupt in Rp angesetzt, 3. Prüfung: Wird jetzt mit anderem VZ angesetzt?
            % Wenn ja: Mode-VZ natürlich auch in der aktuellen Richtung daran anpassen (ändern)
            Moden_R_akt(i_mode) = Moden_R_akt(i_mode) * (-1);
            Fb_res_R_relevant = Fb_res_R_relevant * (-1);
        end
        % Ende: Kurze Zwischenprüfung <<
        % arg.comp.f_b mit Matrix der fiktiven Fundamentschübe mit aktuellen, ggf. vorzeichenmäßig korrigiertem Wert füttern, wenn "ernst zu nehmend"
        if abs(Fb_res_R_relevant)/max(max(max(abs(arg.comp.f_b_fictitious)))) > 0.05
            arg.comp.f_b_fictitious(Idx_Mode_i_in_moden_unique,i_R,arg.info.nummer) = Fb_res_R_relevant;
        end
    end
    % "Moden_R_akt" mit evtl. geänderten VZ bestimmter Moden nun an arg.comp.modes.R_akt übergeben
    arg.comp.modes.(arg.comp.d_earthquake{1,i_R}) = Moden_R_akt;
    % arg.comp.modes.gesamt aktualisieren (einfach immer neu schreiben, falls ein VZ geändert wurde)
    arg.comp.modes.gesamt = [arg.comp.modes.gesamt Moden_R_akt];
end
% Jetzt noch final prüfen, ob ein Mode ein anderes Vorzeichen bezüglich des
% Fundamentschubs in sekundärer oder tertiärer Richtung aufweist
% (Dies kann auftreten, wenn ein "anfänglicher X-Mode" "1" in Y- und X-Richtung
% der "YX"-Ber. berücksichtigt wird mit z. B. positivem Fbx und dann in
% einem späteren Schritt die obige Kontrolle zu einer Modifikation des Ansatzes
% (jetzt: "-1") führt, damit Fby in der "höherwertigen" Y-Richtung positiv ist
% und daraus jetzt aber plötzlich ein negatives Fbx resultiert!)
% Schleife über alle in uniquen Moden
for i_Mode = size(arg.comp.f_b_fictitious,1)
    % Schleife über alle "minderwertigen" Bebenrichtungen
    for i_R = 2:size(arg.comp.d_earthquake,2)
        % Ab Schritt 2: Prüfung, ob dieser Mode in der aktuellen sekundären oder
        % tertiären Richtung im letzten und aktuellen Schritt ein "ernst zu
        % nehmenden fiktiven Fundamentschub" aufweist 
        if arg.info.nummer > 1 && arg.comp.f_b_fictitious(i_Mode,i_R,arg.info.nummer-1) ~= 0 && arg.comp.f_b_fictitious(i_Mode,i_R,arg.info.nummer) ~= 0
            % Dann Prüfung: Hat sich das VZ geändert, sprich der Quotient ist < 0???
            if arg.comp.f_b_fictitious(i_Mode,i_R,arg.info.nummer-1)/arg.comp.f_b_fictitious(i_Mode,i_R,arg.info.nummer) < 0
                % Warnung ausgeben und Berechnung abbrechen, denn eine plötzliche Umkehrung eines Modes wäre entlastend und darf daher NICHT auftreten!!!
                fprintf(2,['\n ATTENTION: In step %d, the mode %d would have to be suddenly reversed,\n',...
                    'in order to NOT have a NEGATIVE resulting base shear in a "higher-order"\n',...
                    'direction than the %s direction!\n',...
                    'However, the resulting sign change of the foundation thrust in the %s direction would be relieving, \n',...
                    'which must not occur! Therefore, the calculation MUST be aborted and the affected mode must be set\n',... % Hinweis: Kann bei 3. Biegeeigenform auftretten, wenn mittlerer "Bauch" plötzlich maßgebend wird! Dann sollte die Lastverteilung sich nicht schlagartig umdrehen!
                    '"the other way round" from the start and then simply protected in terms of direction!'],arg.info.nummer,ModeNr_akt_i,arg.comp.d_earthquake{1,i_R},arg.comp.d_earthquake{1,i_R})
                error('The CALCULATION must therefore be CANCELLED at this point and repeated with a correspondingly different sign of the named mode and a corresponding directional protection!')
            end
        end
    end
end
% --Ende: Abschlusskontrolle->>------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


%% Als allerletztes (EBENFALLS) ÜBERGEORDNET arg.comp.modes.changes ggf. erweitern und "arg.comp.modes_aktuell" sowie arg.comp.modes_aktuell_richtungsbezogen" anlegen (im 1. Schritt) bzw. - falls erf. - aktualisieren
if arg.info.nummer == 1
    % "arg.comp.modes_aktuell" anlegen
    arg.comp.modes_aktuell = Moden_aktuell;
    % "arg.comp.modes_aktuell_richtungsbezogen" mit entsprechenden
    % Richtungsfelder der untersuchten Bebenrichtungen anlegen
    for i_R = 1:size(arg.comp.d_earthquake,2)
        Richtg_akt = arg.comp.d_earthquake{1,i_R};
        arg.comp.modes_aktuell_richtungsbezogen.(Richtg_akt) = abs(arg.comp.modes.(Richtg_akt)); % abs(), da die Richtungs-VZ bei den Nummern in "moden_aktuell" und "moden_aktuell_richtungsbezogen" nicht berücksichtigt werden!
    end
    % mit "arg.comp.modes.changes" muss man nichts tun (ist ja einfach empty)
elseif ~isempty(arg.comp.modes.changes)
    % Zwischenschritt:
    % (0) Alle "überflüssigen" Selbstzuordnungszeilen in "arg.comp.modes.changes"
    % löschen
    Zeilen_loeschen = [];
    for i_Zeile = 1:size(arg.comp.modes.changes,1)
        if length(unique(arg.comp.modes.changes(i_Zeile,2:3))) == 1 % sprich: ModeNr im Schritt (i-1) entspricht ModeNr im aktuellen Schritt (i) (völlig unabhängig von der Frage, ob diese auch der initialen ModeNr entspr., also ab es zuvor einen changes dieses Modes gab)
            % Dann: Zeile in arg.comp.modes.changes löschen (bei vorherigem
            % Switch dieses Modes, wo jetzt z. B. vorläge
            % arg.comp.modes.changes(i_Zeile,:) = [1 2 2] liegt ja in
            % arg.comp.modes.changes_old die Information [1 1 2] vor!)
            Zeilen_loeschen = [Zeilen_loeschen, i_Zeile];
        end
    end
    % Jetzt alle zu löschenden Zeilen auf einen Schlag rausschmeißen, da
    % man das nicht in der obigen Schleife über alle Zeilen machen
    % kann, denn dann würde sich die Schleife "verschlucken"!!!
    arg.comp.modes.changes(Zeilen_loeschen,:) = []; % Zeilen gelöscht!
    % Wenn es in einem späteren Schritt aktuelle Mode-Switches gibt:
    % (1) "arg.comp.modes_aktuell" sowie das betroffene/die betroffenen Feld(er) 
    % von "arg.comp.modes_aktuell_richtungsbezogen.(Richtg_akt)" anpassen
    % Zwischenschritt: Erfordernis wird in den nachfolgenden Programmzeilen deutlich!
    arg_ber_moden_aktuell_tmp = arg.comp.modes_aktuell;
    arg_ber_moden_aktuell_richtungsbezogen_tmp = arg.comp.modes_aktuell_richtungsbezogen;
    % Nun: Anpassung in Schleife über alle neuen (aktuellen) changes
    for i_Zeile = 1:size(arg.comp.modes.changes,1)
        % Übergeordnete Variable "arg.comp.modes_aktuell" anpassen (zunächst
        % in temporäre Variable schreiben, die später geschlossen übergeben
        % wird, sonst verschluckt sich die Schleife ggf.)
        arg_ber_moden_aktuell_tmp(arg.comp.modes_aktuell==arg.comp.modes.changes(i_Zeile,2)) = arg.comp.modes.changes(i_Zeile,3);
        % Betroffene Felder von "arg.comp.modes_aktuell_richtungsbezogen"
        % anpassen
        for i_R = 1:size(arg.comp.d_earthquake,2)
            Richtg_akt = arg.comp.d_earthquake{1,i_R};
            arg_ber_moden_aktuell_richtungsbezogen_tmp.(Richtg_akt)(arg.comp.modes_aktuell_richtungsbezogen.(Richtg_akt)==arg.comp.modes.changes(i_Zeile,2)) = arg.comp.modes.changes(i_Zeile,3);
        end
    end
    % Übergabe von "arg_ber_moden_aktuell_tmp" an arg.comp.modes_aktuell...
    arg.comp.modes_aktuell = arg_ber_moden_aktuell_tmp;
    % ...sowie von "arg_ber_moden_aktuell_richtungsbezogen_tmp" an arg.comp.modes_aktuell_richtungsbezogen
    arg.comp.modes_aktuell_richtungsbezogen = arg_ber_moden_aktuell_richtungsbezogen_tmp;
    % (2) "arg.comp.modes.changes" als übergeordnete "changes-gesamt"-Matrix 
    % für späteren Zugriff im aktuellen Adaptionsschritt (außerhalb dieser 
    % Fkt.) erweitern bzw. aktualisieren
    % Für changes-Identifikation INNERHALB dieser Routine war dieses erweiterte
    % Feld NICHT erforderlich, da reichte die (i-1)<->(i)-Betrachtung
    % -> In arg.comp.modes.changes_old (sofern nicht leer!) alle Zeilen löschen, wo zu 
    %    dem entspr. initialen Bezugsmode (in Spalte 1) aus der neuen (aktuellen)
    %    changes-Matrix neue Informationen vorliegen
    if ~isempty(arg.comp.modes.changes_old) && ~isempty(arg.comp.modes.changes) % 2. Überprüfung ggf. notwendig, wenn in Block (0) arg.comp.modes.changes "geleert" wurde
        arg.comp.modes.changes_old(ismember(arg.comp.modes.changes_old(:,1),arg.comp.modes.changes(:,1)),:) = [];
    end
    % -> Nun arg.comp.modes.changes neu aufbauen (durch Verschmelzen der
    %    alten und neuen changes-Matrix)
    arg.comp.modes.changes = [arg.comp.modes.changes_old; arg.comp.modes.changes];
    % -> Diese neue "changes-gesamt"-Matrix noch aufsteigend nach den
    %    Nummern der initialen Bezugsmoden sortieren
    [~,zeilenindizes_sortiert] = sort(arg.comp.modes.changes(:,1));
    arg.comp.modes.changes = arg.comp.modes.changes(zeilenindizes_sortiert,:);
else
    % FALL: Wir sind in einem späteren Schritt (als dem 1.) und es gab in
    % diesem (aktuellen) Schritt keinen (neuen) Mode-Switch.
    % -> Dann arg.comp.modes.changes (für den Zugriff in anderen Routinen als
    % dieser, z. B. caap_pushover_pointloads im aktuellen Adaptionsschritt)
    % einfach mit arg.comp.modes.changes_old überschreiben!
    arg.comp.modes.changes = arg.comp.modes.changes_old;
end % if arg.info.nummer == 1

% -<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>
% NEUE FINALE ÜBERPRÜFUNG HINSICHTLICH NEGATIVER EIGENFREQUENZEN BZW. -PERIODEN
% BERÜCKSICHTIGTER MODEN (vom 19.07.2023)
% -> Zwischenschritt:
% Aktuelle Tabelle der Modal Participation Factors auslesen
Eigenperioden_akt = cellfun(@str2double,arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]).ModalParticipationFactors.Werte(...,
                           strcmp(arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]).ModalParticipationFactors.Werte(:,1),arg.info.name_modal_old),4));
% Prüfen, ob es mind. eine aktuell angesetzte negative Eigenperiode gibt
if any(Eigenperioden_akt(arg.comp.modes_aktuell) < 0)
    % Zugehörige AKTUELLE Mode-Nr(n) herausfinden
    Mode_Nrn_akt_kritisch = arg.comp.modes_aktuell(find(Eigenperioden_akt(arg.comp.modes_aktuell)<0));
    % -> Untergeordnete Schleife über alle kritischen Mode-Nrn
    for Mode_kritisch = Mode_Nrn_akt_kritisch
        % Benutzer entscheiden lassen, ob er damit leben kann
        % => ERFAHRUNGEN HABEN GEZEIGT: IST OFT GAR NICHT SO KRITISCH,
        %    BETRAG DER NEGATIVEN FREQUENZ PASST ZU VORHERIGER POSITIVER
        %    UND EIGENFORM IST NUR IN MINIMALEM SEGMENT "KINEMATISCH"
        % Zwischenschritt: Zugehörige INITIALE ModeNr zu diesem
        % kritischen aktuellen Mode heraussuchen
        if isempty(arg.comp.modes.changes) || ~(ismember(Mode_kritisch,arg.comp.modes.changes(:,3)))
            ModeNr_initial_von_aktuellem_kritischem_Mode = Mode_kritisch;
            letzte_andere_ModeNr_von_aktuellem_kritischem_Mode = Mode_kritisch; % letzte abweichende Mode-Nummer, ggf. aber einige Schritte vorher schon gechangest
            ModeNr_i_minus_1_von_aktuellem_kritischem_Mode = Mode_kritisch; % wirklich die Mode-Nummer im LETZTEN Schritt
        else
            ModeNr_initial_von_aktuellem_kritischem_Mode = arg.comp.modes.changes(arg.comp.modes.changes(:,3)==Mode_kritisch,1);
            letzte_andere_ModeNr_von_aktuellem_kritischem_Mode = arg.comp.modes.changes(arg.comp.modes.changes(:,3)==Mode_kritisch,2); % letzte abweichende Mode-Nummer, ggf. aber einige Schritte vorher schon gechangest
            % Prüfen, ob die Mode-Nummer FRÜHER ALS vom letzten zum jetzigen Schritt gechangest ist
            if ismember(Mode_kritisch,arg.comp.modes.changes_old(:,3)) && ismember(letzte_andere_ModeNr_von_aktuellem_kritischem_Mode,arg.comp.modes.changes_old(:,2))
                % Dann ist es ein älterer Switch und die Mode-Nr. im letzten Schritt (i-1) war auch schon die aktuelle
                ModeNr_i_minus_1_von_aktuellem_kritischem_Mode = Mode_kritisch;
            else
                % Dann ist der Switch aus dem aktuellen Schritt und die Mode-Nr.
                % im letzten Schritt (i-1) entspricht "letzte_andere_ModeNr_von_aktuellem_kritischem_Mode"
                ModeNr_i_minus_1_von_aktuellem_kritischem_Mode = letzte_andere_ModeNr_von_aktuellem_kritischem_Mode;
            end
        end
        % Informative Warnung ausgeben
        fprintf(2,['\n ATTENTION: In step %d, the considered mode %d\n',...
            '(initial mode %d) has a negative natural frequency!!!!\n',...
            'Should the calculation still be continued \n',...
            'WITHOUT ANOTHER mode assignment?\n'],arg.info.nummer,Mode_kritisch,ModeNr_initial_von_aktuellem_kritischem_Mode)
        % "tic-toc"-Beziehung aufbauen
        t_local = tic;
        % Und ggf. eine kurze (informative)
        % Mail rausschicken
        if isfield(arg.info,'mail')
            % Inhalt der Mail schreiben
            arg.info.mail.content = sprintf(['ATTENTION:\n',...
                'For the current calculation in step ',num2str(arg.info.nummer),' the CAAP tool\n',...
                'requires a user-input due to a (at least one) relevant negative natural frequency!']);
            % Mail rausschicken
            send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                arg.info.mail.subject,arg.info.mail.content)
        end
        % While-Schleife, so lange, bis eine 1 oder 0 eingetippt wurde!
        flag_eingabe_logical = 0; % Noch keine verwertbare Eingabe
        while ~flag_eingabe_logical
            % Eingabe-Aufforderung - ggf. mit akustischer Warnung
            if arg.info.sound == 0.5 || arg.info.sound == 1
                try
                    hupe('gong');
                catch
                    disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                end
            end
            % Eingabe-Aufforderung
            eingabestring = input(['Please look at the natural modes and frequencies in SAP2000\n',...
                'and confirm (1) or reject (0) this: '],'s');
            % Eingabe verarbeiten
            if ismember(str2double(eingabestring),[1 0])
                % Super Eingabe!
                flag_eingabe_logical = 1;
                % Eingabe verwerten
                if str2double(eingabestring) == 0
                    flag_eingabe_logical = 0;
                end
            end
        end
        % Nun prüfen, ob der Benutzer einen "anderweitige
        % Mode-Zuordnung" vornehmen will
        if str2double(eingabestring) == 0
            % >FALL: BENUTZER MÖCHTE EINEN NEUEN MODE (mit fi > 0) ansetzen!
            % While-Schleife so lange, bis was eingetippt wurde,
            % was sich in eine Zahl (Skalar) überführen lässt
            flag_neuzuordnung_int = 0;
            while ~flag_neuzuordnung_int
                % Eingabe-Aufforderung
                eingabestring = input(sprintf(['\nA new mode assignment for the initial mode %d or\n',...
                    'mode %d of the previous modal analysis was requested!\n',...
                    'Therefore, please enter the desired CURRENT mode no. (with fi > 0): '],ModeNr_initial_von_aktuellem_kritischem_Mode,ModeNr_i_minus_1_von_aktuellem_kritischem_Mode),'s');
                % Eingabe verarbeiten
                if ist_typ(str2double(eingabestring),'int')
                    % Super Eingabe!
                    flag_neuzuordnung_int = 1;
                    % arg.comp.modes.changes füttern
                    if isempty(arg.comp.modes.changes) || ~(ismember(Mode_kritisch,arg.comp.modes.changes(:,3)))
                        % Neue Mode-Switch-Zuordnung des bisher in Mode-Switch-Angelegenheiten nicht auffälligen Modes anhängen
                        arg.comp.modes.changes = [arg.comp.modes.changes; [ModeNr_initial_von_aktuellem_kritischem_Mode ModeNr_i_minus_1_von_aktuellem_kritischem_Mode str2double(eingabestring)]];
                    else
                        % Mode-Switch-Zuordnung des entspr. Modes korrigieren
                        arg.comp.modes.changes(arg.comp.modes.changes(:,3)==Mode_kritisch,:) = [ModeNr_initial_von_aktuellem_kritischem_Mode letzte_andere_ModeNr_von_aktuellem_kritischem_Mode str2double(eingabestring)];
                    end
                    % Weitere erforderliche Korrekturen
                    arg.comp.modes_aktuell(arg.comp.modes_aktuell==Mode_kritisch) = str2double(eingabestring);
                    for i_R = 1:size(arg.comp.d_earthquake,2)
                        arg.comp.modes_aktuell_richtungsbezogen.(arg.comp.d_earthquake{1,i_R})(arg.comp.modes_aktuell_richtungsbezogen.(arg.comp.d_earthquake{1,i_R})==Mode_kritisch) = str2double(eingabestring);
                    end
                end
            end
        else
            % >FALL: BENUTZER MÖCHTE KEINEN NEUEN MODE ansetzen!
            % Dann muss aber zumindest die Eigenperiode im Betrag
            % genommen werden, denn sonst kommt es beim AMI-Verfahren
            % zu einem komplexen alpha-Faktor und damit insgesamt zu
            % komplexen Einträgen im Lastvektor, was zu einem Absturz
            % in SAP2000 führen würde!
            Idx_Zeile_Ende_Erg_letzte_Modalanalyse = find(strcmp(arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]).ModalParticipationFactors.Werte(:,1),arg.info.name_modal_old),1) - 1;
            arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]).ModalParticipationFactors.Werte{Idx_Zeile_Ende_Erg_letzte_Modalanalyse+Mode_kritisch,4} = ...
                                                           num2str(abs(str2double(arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]).ModalParticipationFactors.Werte{Idx_Zeile_Ende_Erg_letzte_Modalanalyse+Mode_kritisch,4})));
        end
        % Ausgabe der Unterbrechungszeit
        % (relevant, falls man die Eingabe-Aufforderung erst
        % Stunden später bemerkt hat)
        sec_local = toc(t_local); % [s]
        disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
        hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
        disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
    end
end
% (Ende: NEUE FINALE ÜBERPRÜFUNG HINSICHTLICH NEGATIVER EIGENFREQUENZEN BERÜCKSICHTIGTER MODEN (vom 19.07.2023))
% -<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>--<>

end % function arg = caap_check_eigenmodes(arg)


%% Sub-Funktionen

%% Identifizierten Mode-Switch in arg.comp.modes.changes definieren mit zusätzlichen internen Plausibilitätskontrollen
function arg = sub_define_mode_changes(arg,ModeNr_akt_initial,ModeNr_akt_i_minus_1,ModeNr_akt_i,PHI_akt_i)
% Den entspr. "mode changes" in dem neu aufgebauten Feld "arg.comp.modes.changes" definieren,
% sofern im aktuellen Schritt noch kein Mode dieser (neuen) aktuellen Eigenform zugeordnet wurde (was dann ja auch ein Widerspruch wäre):
if isempty(arg.comp.modes.changes) || ~any(ismember(arg.comp.modes.changes(:,3),ModeNr_akt_i))
    arg.comp.modes.changes = [arg.comp.modes.changes; [ModeNr_akt_initial ModeNr_akt_i_minus_1 ModeNr_akt_i]];
    % Trotzdem wird vorsichtshalber mal eine Warnung ausgespuckt
    fprintf(2,['\n Attention: Mode ',num2str(ModeNr_akt_i_minus_1),' from step ',num2str(arg.info.nummer-1),...
        ' was assigned to the new mode ',num2str(ModeNr_akt_i),' in step ',num2str(arg.info.nummer),'!\n',...
        'This is a modification of the initial mode ',num2str(ModeNr_akt_initial),'! -> Please check!\n\n'])
    % => IM FALL DER MODE-SWITCH-UNTERSUCHUNGSVARIANTE II (über Eigenformen selbst):
    %    Zusätzlich überprüfen,ob sich der (vom Algorithmus eigenständig zugeordnete)
    %    Mode trotzdem vlt. dahingehend geändert hat, dass er Verformungsanteile
    %    in einer anfänglich verformungslosen bzw. -armen Richtung dazu bekommen hat
    if nargin > 4
        PHI_akt_1_norm = sub_get_phi_akt_1_norm(arg,ModeNr_akt_initial);
        sub_check_mode_change(arg,ModeNr_akt_initial,PHI_akt_1_norm,PHI_akt_i)
    end
else
    % Ansonsten, wenn also diesem aktuellen Mode schon ein anderer Mode aus der vorherigen Modal-Analyse zugeordnet wurde, muss man den
    % Benutzer durch zwei entspr. Eingabe-Aufforderungen entscheiden lassen, welchen aktuellen Moden die beiden betroffenen Moden
    % zugeordnet werden sollen (denn er kann sich die Moden visuell in SAP2000 anschauen und eine vernünftige Zuordnung treffen):
    zeilenidx_changesmatrix_mode_i_minus_1 = find(arg.comp.modes.changes(:,3)==ModeNr_akt_i);
    fprintf(2,['\n Natural modes %d and %d of the previous modal analysis were both assigned to the current mode %d\n',...
        'by the "check_eigenmodes" algorithm in step %d!\n',...
        'As a result, the automated assignment must be considered a failure.\n Please take a look at the mode shapes in SAP2000 and define a corresponding assignment',...
        ' for the two affected modes according to the two following prompts!\n'],...
        arg.comp.modes.changes(zeilenidx_changesmatrix_mode_i_minus_1,2),ModeNr_akt_i_minus_1,ModeNr_akt_i,arg.info.nummer)
    % Ggf. kurze akustische Warnung einstreuen, dass jetzt
    % eine Eingabe erfolgen muss, bis das Programm
    % weiterläuft...
    if arg.info.sound == 0.5 || arg.info.sound == 1
        try
            hupe('gong');
        catch
            disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
        end
    end
    % "tic-toc"-Beziehung aufbauen
    t_local = tic;
    % Und ggf. eine kurze (informative)
    % Mail rausschicken
    if isfield(arg.info,'mail')
        % Inhalt der Mail schreiben
        arg.info.mail.content = sprintf(['ATTENTION:\n',...
            'For the current calculation in step ',num2str(arg.info.nummer),'\n',...
            'the CAAP tool requires a user-input\n',...
            'due to an unclear mode-change assignment!']);
        % Mail rausschicken
        send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
            arg.info.mail.subject,arg.info.mail.content)
    end
    % Zwei While-Schleifen, so lange, bis für beide Moden der vorherigen Modal-Analyse was eingetippt wurde, was sich in eine Zahl (Skalar) überführen lässt
    flag_1 = 0; % Noch keine verwertbare Eingabe für den ersten Mode aus Schritt (i-1)
    flag_2 = 0; % Noch keine verwertbare Eingabe für den zweiten Mode aus Schritt (i-1)
    while ~flag_1
        % Eingabe-Aufforderung
        eingabestring_1 = input(sprintf('Please enter the corresponding CURRENT mode number for mode %d from the previous modal analysis in step %d\n: ',...
            arg.comp.modes.changes(zeilenidx_changesmatrix_mode_i_minus_1,2),(arg.info.nummer-1)),'s');
        % (Ausgabe der Unterbrechungszeit erfolgt sinnvollerweise erst nach Abschluss der zweiten Eingabe!)
        % Eingabe verarbeiten
        if ist_typ(str2double(eingabestring_1),'int')
            % Super Eingabe!
            flag_1 = 1;
            % arg.comp.modes.changes füttern
            arg.comp.modes.changes(zeilenidx_changesmatrix_mode_i_minus_1,3) = str2double(eingabestring_1);
        end
    end
    while ~flag_2
        % Eingabe-Aufforderung
        eingabestring_2 = input(sprintf('Now please also enter the corresponding CURRENT mode number for the\n mode %d from the previous modal analysis in step %d: ',...
            ModeNr_akt_i_minus_1,(arg.info.nummer-1)),'s');
        % Eingabe verarbeiten
        if ist_typ(str2double(eingabestring_2),'int')
            % Super Eingabe!
            flag_2 = 1;
            % arg.comp.modes.changes füttern
            arg.comp.modes.changes = [arg.comp.modes.changes; [ModeNr_akt_initial ModeNr_akt_i_minus_1 str2double(eingabestring_2)]];
        end
    end
    % Ausgabe der Unterbrechungszeit
    % (relevant, falls man die Eingabe-Aufforderung erst
    % Stunden später bemerkt hat)
    sec_local = toc(t_local); % [s]
    disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
    hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
    disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
end
end


%% Eigenvektor des aktuellen Modes in seiner initialen Form auslesen und auf die maximale Translation normieren
function PHI_akt_1_norm = sub_get_phi_akt_1_norm(arg,ModeNr_akt_initial)
% Zeilenindizes zum relevanten Modalanalyse-LF identifizieren
Idzs_logical_richtiger_LF_logical = strcmp(arg.comp.erg.schritt_0.JointDisplacements.Werte(:,2),arg.info.name_modal);
% Relevante Knotenverformungen auslesen
Modalerg_1 = arg.comp.erg.schritt_0.JointDisplacements.Werte(Idzs_logical_richtiger_LF_logical,:);
% Indizes der Zeilen in den modalen Knoten-Verformungen herausfinden, die sich auf
% den jew. aktuellen Mode beziehen
indizes_Mode_akt_Erg_1 = find(cellfun(@str2num,Modalerg_1(:,5)) == ModeNr_akt_initial);
% Entsprechende Modalergebnisse dieser Modalform extrahieren
Modalerg_1_von_Mode_akt = Modalerg_1(indizes_Mode_akt_Erg_1,:);
% Nur die Knotentranslationen dieses Modes auswählen
v_Bezugsmode_akt_1 = cellfun(@str2num,Modalerg_1_von_Mode_akt(:,6:8));
% Diesen jew. Eigenvektor auf die maximale Verschiebungskomponente
% (richtungsübergreifend!!!) normieren;
% dadurch ist die größte Komponente nun immer +1!!!
    % >> Zwischenschritt: Betraglich maximale Verschiebung
    %    vorzeichengerecht ermitteln, sodass nach der Normierung
    %    v_max immer = +1 ist!!!
    %{
    Hinweis: 
    -> "unique(...)", falls exakt dieser maximale Wert mehrfach auftritt 
    -> und abs(...), falls dieser Wert einmal positiv und einmal
       negativ auftritt (z. B. bei einer antimetrischen Eigenform);
       dass hierbei dann mit dem positiven und nicht mit dem
       negativen skaliert wird, spielt insofern keine Rolle, als ja
       ohnehin noch einmal die komplette PHI-Matrix dann mit -1
       skaliert zusätzlich untersucht wird!
    %}
    v_massg_PHI_akt_1 = unique(v_Bezugsmode_akt_1(abs(v_Bezugsmode_akt_1)==max(max(abs(v_Bezugsmode_akt_1))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
    % Tritt der betraglich maximale Wert positiv UND negativ auf,
    % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
    % sich bezieht, gewählt wird dann einfach der positive
    if length(v_massg_PHI_akt_1) == 2
        v_massg_PHI_akt_1 = unique(abs(v_massg_PHI_akt_1));
    end
    % (Ende: Zwischenschritt) >>
% Eigenvektor final normieren
PHI_akt_1_norm = v_Bezugsmode_akt_1 / v_massg_PHI_akt_1;
end


%% Prüfen, ob sich ein nicht gechangester oder klar zuordenbarer Mode stark verändert hat durch Kontrolle: Signifikante Verformungen in bisher verformungsloser oder zum. -armer Richtung dazugekommen?
function sub_check_mode_change(arg,ModeNr_akt_initial,PHI_akt_1_norm,PHI_akt_i_norm)
% -> Überprüfen, ob der aktuell betrachtete Mode in seiner Form "i-1"
% in einer Richtung "praktisch keine Verformungen" aufwies, jetzt aber
% schon (mittels Schleife über alle drei kartesischen Richtungen)!
flag_mode_change = 0; % Vorbelegung
for i_R = 1:3
    % Prüfen, ob der aktuell betrachtete NORMIERTE MODE in seiner INITIALEN
    % FORM in der aktuellen Richtung "praktisch keine Verformungen aufweist":
    if max(max(abs(PHI_akt_1_norm(:,i_R)))) < 0.01
        % Dann prüfen, ob dies in der neuen (i-ten) Form der Fall ist
        if max(max(abs(PHI_akt_i_norm(:,i_R)))) > 0.2 % hier nochmal abs(...), da ja das Vorzeichen der Verformungsanteile keine Bedeutung hat
            % Wenn ja: Dann hätte sich der Mode insgesamt so stark geändert
            % (wenngleich er bei der changes-Betrachtung zugeordnet wurde),
            % dass hier von einem SYSTEMWECHSEL gesprochen werden muss!
            flag_mode_change = 1; % Entsprechende Warn-Flagge setzen
            break % Richtungs-Schleife kann verlassen werden, der Beweis in einer Richtung reicht aus!
        end
    end
end

% -> Im Falle einer deutlichen Veränderung des Modes: Warnung (ggf. kann
% man ja hier auch einen Breakpoint setzen!!!)
% Dann kann der Benutzer sich überlegen, ob der Mode trotzdem korrekt zugeordnet wurde 
% (je nach Fall: ist von Mode-changes betroffen oder nicht)
if flag_mode_change
    % Prüfen, ob dieser Mode im aktuellen Schritt von einem Mode-Switch
    % betroffen ist
    if isempty(arg.comp.modes.changes) || ~any(ismember(arg.comp.modes.changes(:,1),ModeNr_akt_initial))
        % Fall: Nein, er hat dieselbe Nummer wie im letzten Schritt
        % << Ermittlung der Mode-Nummer des letzten Schrittes, je nachdem, ob der
        %    Mode in einem weiter zurückliegenden Schritt einem Switch unterlag, oder nicht:
        if isempty(arg.comp.modes.changes_old) || ~any(ismember(arg.comp.modes.changes_old(:,1),ModeNr_akt_initial))
            ModeNr_akt_i_minus_1 = ModeNr_akt_initial;
        else
            ModeNr_akt_i_minus_1 = arg.comp.modes.changes_old(arg.comp.modes.changes_old(:,1)==ModeNr_akt_initial,3);
        end % (Ende: Ermittlung der Mode-Nummer des letzten Schrittes)
        % -> Warnung:
        fprintf(1,['\n Attention: Mode ',num2str(ModeNr_akt_i_minus_1),' from step ',num2str(arg.info.nummer-1),...
            ' shows significant changes in step ',num2str(arg.info.nummer),' compared to its initial form\n',...
            '(even though it was assigned to itself again)!\n',...
            '-> Please check after completing the current calculation and then, if in doubt,\n',...
            'carry out a new calculation in order to be able to directly take into account any\n',...
            'other modes that may only become relevant later (think about modal sign carefully)!\n'])
    else
        % Fall: Ja, er unterliegt einem Mode-Switch
        % -> Aktuelle und vorherige Mode-Nummer auslesen
        ModeNr_akt_i_minus_1 = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==ModeNr_akt_initial,2);
        ModeNr_akt_i = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==ModeNr_akt_initial,3);
        % -> Warnung:
        fprintf(1,['\n Attention: Mode ',num2str(ModeNr_akt_i_minus_1),' from step ',num2str(arg.info.nummer-1),','...
            ' which was assigned to mode ',num2str(ModeNr_akt_i),' in step ',num2str(arg.info.nummer),'\n',...
            ' shows clear changes compared to its initial form!\n',...
            '-> Please check after completing the current calculation and then, if in doubt,\n',...
            'carry out a new calculation in order to be able to directly take into account any\n',...
            'other modes that may only become relevant later (think about modal sign carefully)!\n'])
    end
end
end


%% Analysieren, ob "das Vorzeichen" der Eigenform in der betrachteten Richtung positiv oder negativ ist (anhand der betraglich größten Verschiebung) als Referanz für eine Kontrolle im nächsten Adaptionsschritt
function [vz,joint,Idx_R_Beben] = sub_get_direction(arg,erg_i_minus_1,ModeNr_akt_i,ModeNr_akt_initial)
% Relevante Daten zusammenstellen
Zeilenidzs_richtiger_Mode = strcmp(erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(:,5),[num2str(ModeNr_akt_i),'.']);
Daten_relevant = erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(Zeilenidzs_richtiger_Mode,[1 5:8]); % Spalte 1: Knotennummern, Spalte 5: Mode-Nr., Spalten 6-8: u1-, u2- & u3-Verschiebung

% Herausfinden, in welcher kartesischen Richtung die aktuell betrachtete
% Eigenform berücksichtigt werden soll
% << HINWEIS: Bei Berücksichtigung in mehreren Richtungen (MITTLERWEILE JA MÖGLICH!)
%    wird DIE RICHTUNG als "am wichtigsten" eingestuft, die in den richtungsbezogenen
%    Mode-Angaben früher genannt wird (um so z. B. einen Basismode in X-Richtung, der 
%    an dritter Stelle auch in Y-Richtung berücksichtigt und dort ggf. erst im Zuge
%    der Berechnung relevant wird, auf die X-Richtung zu beziehen!!!).
%    Bei "Gleichstand" (z. B. in zwei Richtungen berücksichtigt und jew. an zweiter Stelle
%    aufgeführt) gewinnt die höherrangige Richtung (Rp > Rs, Rs > Rt), logisch! >>
% Schleife über alle berücksichtigten Bebenrichtungen
nummer_bisher_minimal = []; % leer vorbelegen
for i_Richtg = 1:size(arg.comp.d_earthquake,2)
    % Prüfen, ob der aktuell untersuchte Mode in dieser Richtung überhaupt
    % angesetzt wurde
    if ismember(ModeNr_akt_initial,abs(arg.comp.modes.(arg.comp.d_earthquake{1,i_Richtg})))
        % Wenn ja: Richtungsbezogene "Platznummer" merken und den Richtungsindex 
        % ggf. überschreiben (wenn akt. Nummer kleiner als die bisher kleinste)
        nummer = find(abs(arg.comp.modes.(arg.comp.d_earthquake{1,i_Richtg}))==ModeNr_akt_initial);
        if i_Richtg == 1
            % Bei der ersten (ggf. einzigen) Richtung gibt es keine
            % vorherige Nummer (eventuell aber halt auch bei der zweiten,
            % wenn der Mode in der ersten Richtung nicht angesetzt wurde,
            % * s. u.)
            Idx_R_Beben = arg.comp.d_earthquake{2,i_Richtg}; % Index gem. Zuordnung: 1 -> 'X', 2 -> 'Y', 3 -> 'Z'
            nummer_bisher_minimal = nummer;
        elseif isempty(nummer_bisher_minimal) || nummer < nummer_bisher_minimal  % nur bei "echt kleiner" (* oder wenn der Mode in der/den bisher analysierten Richtung(en) gar nicht angesetzt wurde), sonst bleibt es bei dem bisherigen (höherrangingen) Richtungsindex!
            Idx_R_Beben = arg.comp.d_earthquake{2,i_Richtg}; % Index gem. Zuordnung: 1 -> 'X', 2 -> 'Y', 3 -> 'Z'
            nummer_bisher_minimal = nummer;
        end
    end
end
        
% Translationen aller FE-Knoten in dieser Richtung als Zahlenvektor
% extrahieren
v_R_Beben = cellfun(@str2num,Daten_relevant(:,(2+Idx_R_Beben))); % Spalte 3 (= 2+1) bei 'X', 4 (= 2+2) bei 'Y' & 5 (= 2+3) bei 'Z'
% Betragliche Verschiebungswerte
betrag_v_R_Beben = abs(v_R_Beben);

% Knotenindex des Knotens mit der max. betraglichen Verschiebung in dieser
% Richtung identifizieren
% -> Aber nur, sofern die maximale Verformung in dieser Richtung nicht
%    nahezu 0 ist, gemessen an der maximalen Verformung in den beiden anderen
%    Richtungen: Grenzwert -> mind. 10 % davon!
%    (Könnte relevant werden bei Moden, die erst später signifikante Ver-
%    formungen in dieser Bebenrichtung aufweisen und nur deshalb in dieser 
%    von Anfang an berücksichtigt werden!!!)
     % << Zwischenschritt: "Sonstige" Verformungen (in den beiden weiteren
     % Richtungen) auslesen
     switch Idx_R_Beben
         case 1
             v_R_sonstig = cellfun(@str2num,Daten_relevant(:,[4 5]));
         case 2
             v_R_sonstig = cellfun(@str2num,Daten_relevant(:,[3 5]));
         case 3
             v_R_sonstig = cellfun(@str2num,Daten_relevant(:,[3 4]));
     end
     betrag_v_R_sonstig = abs(v_R_sonstig);
     % Ende: Zwischenschritt
if max(betrag_v_R_Beben) > 0.1 * max(max(betrag_v_R_sonstig))
    % Dann: Den Zeilenindex mit der maximalen Verformung in der
    % betrachteten Richtung ermitteln
    Zeilenidx_max = find(betrag_v_R_Beben == max(betrag_v_R_Beben));
    % Falls es mehr als einen Knoten mit der max. Verschiebung geben
    % sollte, einfach den ersten auswählen
    Zeilenidx_max = Zeilenidx_max(1);

    % Knotennummer und Vorzeichen der maximalen Verschiebung in der
    % betrachteten Richtung ermitteln
    joint.name = Daten_relevant{Zeilenidx_max,1}; % Knotennummer
    joint.knot_index = Zeilenidx_max; % Knoten-Index bezogen auf alle FE-Knoten
    vz = v_R_Beben(Zeilenidx_max)/betrag_v_R_Beben(Zeilenidx_max); % 1 oder -1!
else
    joint.name = '';
    joint.knot_index = 0;
    vz = 0; % DANN KANN JA KEIN VORZEICHEN SINNVOLL AUSGEWERTET WERDEN!!!
end
end


%% Analysieren, ob sich "das Vorzeichen" der Eigenform in der Richtung, in der er angesetzt wurde (oder bei mehreren: in der "relevantesten" Richtung), im Vergleich zur initialen (vom Benutzer in SAP2000 angeschauten) Form geändert hat
function SF = sub_check_direction(arg,erg_i_minus_1,ModeNr_akt_i,i_mode)
% => Untersuchung in zwei Schritten:
%    1.) Analysieren, ob sich "das Vorzeichen" der Eigenform in der betrachteten Richtung im Vergleich ZUR VORHERIGEN MODALANALYSE geändert hat
%        (anhand der Verschiebung eines repräsentativen Knotens mit in der in der "(i-1). Form" betraglich größten Verschiebung in Bebenrichtung)
%    2.) Multiplikation dieses "lokalen" Richtungswechsel-Faktors (zwischen
%        Schritt (i-1) und (i)) mit dem globalen Faktor des Schrittes (i-1)

% => Schritt 1: Analysieren, ob sich "das Vorzeichen" der Eigenform in der betrachteten Richtung im Vergleich ZUR VORHERIGEN MODALANALYSE geändert hat
% Relevante Daten zusammenstellen
Zeilenidzs_richtiger_Mode = strcmp(erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(:,5),[num2str(ModeNr_akt_i),'.']);
Daten_relevant = erg_i_minus_1.JointDisplacements.Werte.(arg.info.name_modal_old)(Zeilenidzs_richtiger_Mode,[1 5:8]); % Spalte 1: Knotennummern, Spalte 5: Mode-Nr., Spalten 6-8: u1-, u2- & u3-Verschiebung
Idx_Richtung = arg.comp.modes.kontrollinfos.Idx_Richtung((arg.info.nummer-1),i_mode);

% Überprüfen, ob die Verschiebung des Knotens mit der betraglich maximalen
% Verschiebung der aktuell betrachteten Eigenform in ihrer "(i-1). Form" dieselbe
% Richtung, also dasselbe Vorzeichen aufweist, wie in der AKTUELLEN ("i.") Form
% -> Vorzeichen der Verschiebung dieses Knotens in der Form der VORHERIGEN MODAL-ANALYSE (im Schritt i-1) der akt. Eigenform
vz_v_kontrolle_i_minus_1 = arg.comp.modes.kontrollinfos.vz((arg.info.nummer-1),i_mode);
% -> Verschiebung dieses Knotens in der AKTUELLEN FORM (im aktuellen Adaptionsschritt (i)) der akt. Eigenform
v_kontrolle_i = str2double(Daten_relevant(arg.comp.modes.kontrollinfos.joint.knot_index((arg.info.nummer-1),i_mode),Idx_Richtung+2)); % 3. Spalte: u1, 4. Spalte: u2, 5. Spalte: u3
% Überprüfung, ob es einen Vorzeichenwechsel des aktuellen Modes zwischen
% Schritt (i-1) und (i) gegeben hat:
if v_kontrolle_i * vz_v_kontrolle_i_minus_1 >= 0
    % Fall: Gleiches Vorzeichen (entweder beide negativ oder beide positiv)
    % -> Skalierungsfaktor des vorherigen Schrittes (i-1) bleibt erhalten
    SF_lokal_i_minus_1_zu_i = 1;
else
    % Fall: Vorzeichenwechsel!!!
    % -> Skalierungsfaktor des vorherigen Schrittes (i-1) wird "invertiert"
    SF_lokal_i_minus_1_zu_i = -1;
end

% => Schritt 2: Multiplikation dieses "lokalen" Richtungswechsel-Faktors (zwischen Schritt (i-1) und (i)) mit dem globalen Faktor des Schrittes (i-1)
SF = SF_lokal_i_minus_1_zu_i * arg.comp.modes.SF(arg.info.nummer-1,i_mode);
end

function [modell,arg] = MAIN_CAAP(modell,arg,varargin)
%   #######################################################################
%   Complete Automated Adaptive Pushover (caap)
%
%   Für Stabtragwerke
%
%   Es gibt folgende Möglichkeiten:
%   1. NICHT-adaptive PushOver-Berechnung
%   2. Schrittweise manuelle adaptive PushOver-Berechnung
%   3. Automatische adaptive PushOver-Berechnung
%   4. Modifiziertes AMI-Verfahren mit konstanten Spektralbeschleunigungs-
%      inkrementen in der Bezugs-EF
%   5. Modifiziertes AMI-Verfahren mit optimierten Spektralbeschleunigungs-
%      inkrementen in der Bezugs-EF, heißt: mit "Max-Berechnungen" und anschl.
%      Korrektur-Schritten; bei negativen Spektralbeschleunigungsinkrementen
%      wird für den verbleibenden Restbereich bis zum Performance-Zustand
%      kurz noch auf das AMI-Verfahren mit konstantem DELTA_S_a_B gewechselt!
%   => 4. & 5. jew. nur automatisch adaptiv!
%
%   Eingabeargumente in arg.info: (allg. "Informationen")
%
%   sap_path (erforderlich)             - Pfad zur "SAP2000.exe"
%   [string]
%
%
%   sap_file (erforderlich)             - Pfad zur Modell-Datei ($2k)
%   [string]
%
%
%   export_file_name (optional)         - Name vom automatischen Export (xml)
%   [string]
%                                         Default: 'Auto_Export'
%
%
%   name_vert (erforderlich)            - Name des nichtlinearen Lastfalls
%   [string]                              der ständigen vertikalen Lasten, 
%                                         der als Initialschritt dient
%
%
%   name_modal (erforderlich)           - Lastfall-Name der initialen Modalanalyse
%   [string]
%
%
%   name_pushover (erforderlich)        - Lastfall-Name der initialen PushOver-Analyse
%   [string]
%
%
%   procedure (optional)                - Angabe, welches Verfahren
%   [string]                              angewendet werden soll
%                                           ~ 'standard'
%                                           ~ 'ami_c'
%                                           ~ 'ami_o'
%
%                                         Default: 'standard'
%
%
%   console (optional)                  - Sind detaillierte Ausgaben
%   [false | true]                        gewünscht?
%   [0 | 1]
%
%                                         Default: 1
%
%
%   sound (optional)                    - Ist ein akkustisches Signal
%   [0 | 0,5 | 1]                         am Ende der Berechnung gewünscht?
%                                           ~ 0: Nein
%                                           ~ 0,5: Ja, aber nur kurz ("Hupe" bei Erfolg)
%                                           ~ 1: Ja (Ausschnitt aus dem Steigerlied bei Erfolg)
%                                           -> Bei nicht erfolgreicher Berechnung erklingt in
%                                              den Fällen 0,5 & 1 ein kurzes Trauer-Jingle!
%
%                                         Default: 1
%
%
%   mail (optional)                     - Ist eine informative Mailbenachrichtigung im Falle
%   (eigene Unterstruktur)                einer erforderlichen Benutzereingabe gewünscht?
%                                         => Wenn ja: Entsprechende Substruktur mit folgenden
%                                            Feldern aufbauen:
%                                           - "mailadress": Angabe der Sender- und Empfänger-
%                                             Mailadresse als String, z. B. 'mustermann@uni-wuppertal.de'
%                                           - "name": Angabe des Namens des zu verwendenden Mail-Accounts
%                                             als String, z. B. 'mustermann'
%                                           - "password": Angabe des Passwortes des zu verwendenden Mail-
%                                             Accounts als String, z. B. 'Passwort123'
%                                           - "smtp_server": Angabe der Bezeichnung des zu verwendenden
%                                             SMTP-Servers als String, z. B. 'mail.uni-wuppertal.de'
%
%                                         Hinweis: Die beiden weiteren, zur Anwendung des Werkzeugs 
%                                         "send_automated_mail" erforderlichen Felder "subject"
%                                         (Mail-Betreff) und "content" (Mail-Inhalt) werden später 
%                                         im ersten Fall von der caap_check_varargin-Routine bzw.
%                                         im zweiten Fall "am Entstehungsort" der Eingabeaufforderung
%                                         angelegt und mit Inhalt gefüllt.
%
%
%   Eingabeargumente in arg.comp: (konkrete Berechnungsparameter)
%
%   nl_steps (optional)                 - Multiple States der nichtlinearen
%   [1x2 - Array]                         PushOver-Analysen [Min Max]
%
%                                         Default: [10 100]
%
%
%   d_tol (optional)                    - Wenn keine Konvergenz gefunden wurde
%   [float]                               und eine Verdreifachung der Total Steps
%                                         (welche dann auch gleich der neuen Anzahl
%                                         der zul. Null-Steps gesetzt wird), 
%                                         erfolglos blieb:
%                                         Toleranz um ein Delta "d_tol" [-]
%                                         anpassen (erhöhen)
%                                         -> Wert 0 heißt: Keine Anpassung
%
%                                         Default: 0
%
%
%   adaptiv (optional)                  - Soll die Berechnung adaptiv
%   [false | true]                        erfolgen?
%   [0 | 1]                               (im Fall "standard" interessant,
%                                         allerdings bei Lastverteilung 
%                                         'mass' unterbunden;
%                                         modifiziertes AMI-Verf. ergibt
%                                         nur adaptiv Sinn; nicht adaptiv 
%                                         wird mit Warnung abgefangen)
%
%                                         Default:
%                                         -> im Fall 'standard': false
%                                         -> im Fall 'ami_c'/'ami_o': true
%
%
%   k_loc (optional)                    - Lokaler Grenzwert für Knick in
%   [float]                               der PushOver-Kurve; nur relevant
%   0 <= k_loc <= 1                       im Fall 'standard' oder 'ami_o'!
%                                         (Nähere Erläuterungen dazu in der
%                                         Funktion caap_analyze_pushover;
%                                         Info: Durch die Eingabe einer 0
%                                         wird das Kriterium deaktiviert.)
%
%                                         Default: 0.9
%
%
%   k_glob (optional)                   - Globaler Grenzwert für kontinuier-
%   [float]                               liche Steifigkeitsänderung in der
%   0 <= k_glob <= 1                      PushOver-Kurve bezogen auf den
%                                         letzten Referenz-Zustand; nur 
%                                         relevant im Fall 'standard' oder
%                                         'ami_o'!
%                                         (Nähere Erläuterungen dazu in der
%                                         Funktion caap_analyze_pushover;
%                                         Info: Durch die Eingabe einer 0
%                                         wird das Kriterium deaktiviert.)
%
%                                         Default: 0.9
%
%
%   delta_s_a_b (optional, für 'ami_c'): - Spektralbeschleunigungsinkrement
%   [float]                               des Bezugsmodes (fester Wert für
%   (i. Allg. aber auch sinnvoll bei      sämtliche Adaptionsschritte)
%   'ami_o' für den Fall, dass
%   später negative Spektralinkremente    Default: 0.01 [m/s²]
%   auftreten: -> 'ami_o_zu_ami_c')
%
%
%   auto_run (optional)                 - Soll die adaptive Berechnung
%   [false | true]                        vollautomatisch mit den initialen
%   [0 | 1]                               Bedingungen durchgeführt werden?
%                                         (im Fall "standard" interessant;
%                                         modifiziertes AMI-Verf. ergibt
%                                         nur vollautomatisiert Sinn; nicht
%                                         vollautomatsich wird mit Warnung
%                                         abgefangen)
%
%                                         Default:
%                                         -> im Fall 'standard': false
%                                         -> im Fall 'ami_c'/'ami_o': true
%
%   algodec (optional)                  - Soll dem Algorithmus bei kritischen
%   [false | true]                        Mode-Selbstzuordnungen im Zweifel
%   [0 | 1]                               mehr Entscheidungsgewalt gegeben
%                                         werden (sinnvoll bei nächtlichen
%                                         Berechnungen z. B.)?
%
%                                         Default: false bzw. 0
%
%
%   check (optional)                    - Soll ein wirklicher Erdbeben-NW
%   [false | true]                        geführt werden?
%   [0 | 1]                               Frage stellt sich eigentlich nur
%                                         im Fall "standard", wo dann eine
%                                         PP-Ermittlung durchgeführt wird.
%                                         Das modifizierte AMI-Verfahren
%                                         beinhaltet immer einen NW!
%
%                                         Default:
%                                         -> im Fall 'standard': false
%                                         -> im Fall 'ami_c'/'ami_o': true
%
%
%   vi (optional*)                      - Soll nach der KSM-Berechnung
%   [false | true]                        der Variationsindex "VI"
%   [0 | 1]                               auf Basis der Veränderung des
%   (*nur sinnvoll/möglich bei nicht      Bezugsmodes ermittelt werden, um
%   adaptiver 'standard'-Pushover-Ber.    um einschätzen zu können, ob
%   mit 'check', also bei einer              eine adaptive Berechnung sinnvoll
%   "klassischen" Ber. nach der KSM-M.)   (gewesen) wäre?
%
%                                         Default: false
%
%
%   load_pattern (optional)             - Lastverteilung
%   [string]                              (nur relevant im Fall 'standard')
%                                         Mögliche Proportionalitäten:
%                                           ~ Masse - 'mass'
%                                           ~ Monomodalform - 'modal'
%                                           ~ Masse & Monomodalform - 'mass_modal'
%
%                                         Default: 'mass'
%
%
%   push_load_ref (optional)            - Angabe, worauf sich die Pushover-
%   [string]                              Punktlasten beziehen sollen
%                                           ~ 'frames': sämtliche (System- & FE-)Knoten
%                                              werden belastet; reines ‚frame -Tragwerk erf.
%                                           ~ 'joints': sämtliche System-, aber keine FE-Knoten
%                                              werden belastet; alle Elementtypen sind möglich
%
%                                         Default: 'frames'
%
%
%   d_earthquake (erforderlich)         - Bebenrichtungen, die zu
%   [String]                              berücksichtigen sind
%                                         (Angabe in der Form 'YX' oder
%                                         'YXZ', wobei immer der erste Buch-
%                                         stabe die primäre und alle weiteren 
%                                         die sekundäre Bebenrichtung angeben!)
%
%
%   modes (erforderlich)*               - Richtungsbezogen zu
%   [struct]                              berücksichtigende Eigenformen
%                                         Angabe für jede in d_earthquake def.
%   *außer im Fall: Verfahren             Bebenrichtung, z. B.
%    'standard', Lastverteilung            ~ modes.Y = [1 3 -4]
%    'mass' und arg.comp.check = 0,       ~ modes.X = [-4]
%    sprich: keine Transf. der            WICHTIG: In der primären
%    Pushover-Kurve notw.                 Bebenrichtung MUSS der
%    => Bei arg.comp.check = 1 reicht     Bezugs-Mode "B" vorne stehen.
%       die Angabe bez. der prim.         -> Beim Standard-Pushover-Verf. 
%       Bebenrichtung!                       darf bzw. kann in jeder Beben-
%                                            richtung nur EIN MODE berück-
%                                            sichtigt werden! Das VZ bestimmt
%                                            darüber, ob die jew. Lastver-
%                                            teilung IN Richtung der jew.
%                                            Eigenform wirkt oder entgegen.
%                                         -> Beim modifizierten AMI-Verf. 
%                                            repräsentieren die VZ die alpha-
%                                            Faktoren von Norda! Hierbei
%                                            darf jeder Mode mittlerweile
%                                            auch In MEHREREN RICHTUNGEN
%                                            berücksichtigt werden.
%
%
%   sign_factors (nur erforderlich im   - Bebenrichtungsbezogen zu definierende
%   Fall: "standard" & "mass")            Angabe, ob die jew. Lastverteilung
%   [1 x n_Bebenrichtungen]-Array         in positiver oder negativer globaler
%   (Werte 1 oder -1)                     Koordinatenrichtung wirken soll
%
%
%   dir_factor (optional)               - Wenn Multidirektional: Überlagerungsfaktoren
%   [1xN - Array]                         Dabei steht der Faktor für die
%   1 <= N <= 3                           primäre Bebenrichtung vorne!
%
%                                         Default: [1 0.3 0.3]
%
%
%   xi_0 (optional):                    - Grundwert der Systemdämpfung [%];
%   [float]                               default: 5 %
%
%
%   hb (erforderlich)                   - Hystereseverhalten
%   [String]                              'A', 'B' oder 'C'
%
%
% Eingabeargumente in arg.rs: (Steuerparameter zur Ermittlung des Antwortspektrums 
%                              mittels "caap_el_accel_response_spectrum",
%                              im Falle einer "Standard"-Berechnung MIT Nw
%                              ODER einer Ber. nach dem mod. AMI-Verfahren)
%
%   standard (optional)                 - Normative Quelle des Antwortspektrums,
%   [String]                              aktuell möglich: 
%                                          - 'ec8-1' (default)
%                                          - 'ec8-1_de'
%
%
%   a_g (ggf. erforderlich):            - Horizontale Bemessungsbodenbeschleunigung [m/s²];
%   [float]                               benötigt für die Bebenrichtungen 'X' & 'Y'
%
%
%   a_vg (ggf. erforderlich):           - Vertikale Bemessungsbodenbeschleunigung [m/s²];
%   [float]                               benötigt für die Bebenrichtung 'Z'
%
%
%   S (ggf. erforderlich):              - Bodenparameter (in Abh. der Baugrundklasse &
%   [float]                               des Antwortspektrentyps);
%                                         benötigt für horizontale Antwortspektren
%
%
%   T_BCD (erforderlich):               - drei Kontrollperioden T_B, T_C & T_D [s] (als floats);
%   [1x3]-Arry mit floats                 ebenfalls abhängig von der Baugrundklasse & vom 
%                                         Antwortspektrentyp
%
%
%   dT (optional):                      - Auflösung der T-Achse [s];
%   [float]                               default: 0,01 s
%
%
%   T_max (optional):                   - Obergrenze der T-Achse [s];
%   [float]                               default: 4 s
%
%
%   T_min (optional):                   - Untergrenze der T-Achse [s];
%   [float]                               default: 0 s
%
%
%   varargin: Alle übrigen Eingaben werden ignoriert!
%
%
%   #######################################################################

% HINWEIS: Bei Problemen, die Soundfiles abzuspielen, mal mittels dem Aufruf
% "info = audiodevinfo" prüfen, ob Matlab entspr. Output-Devices erkennt;
% falls er unter info.output ein leeres struct zurückliefert, mal in den
% Systemeinstellungen das Ausgabegerät überprüfen. WAS BEI MIR (Dominik)
% ZULETZT GEHOLFEN HAT:
% => Im "cmd"-Fenster von Windows 'hdwwiz.cpl' eingeben, das Audiodevice
%    "Realtek(R) Audio" einmal deaktivieren und dann wieder aktivieren!


%% Block 0

% Berechnung schon fertig?
if isfield(arg.info,'finish') && arg.info.finish == 1
    error('The calculation is already finished!')
end

% arg-Struktur beim ersten Programmdurchlauf "auf Herz und Nieren" prüfen
% (hinsichtlich der Eingaben) und bei späteren Durchläufen einige
% Anpassungen vornehmen
arg = caap_check_varargin(arg);


%% Block 1
% Sicherungskopie des Modells erstellen
[sap_filepath,sap_name,sap_ext] = fileparts(arg.info.sap_file);
copyfile(arg.info.sap_file,[sap_filepath '\BACKUP_' sap_name '_schritt_' num2str(arg.info.nummer) sap_ext])

% LoadCase Namen generieren
arg = caap_generate_lc_names(arg);

% Ggf. (im Fall einer adaptiven Berechnung und wenn "arg.info.console" gleich 1 gesetzt wurde vom Benutzer)
% kurze Info, dass (und um wie viel Uhr) ein neuer (und welcher) Schritt nun begonnen wird
if arg.comp.adaptive == 1 && arg.info.console == 1
    % Vorarbeit: Kurz den aktuellen Zeitpunkt ermitteln
    zeitpkt = clock;
    zeitpkt_str = cell(1,5);
    for i_Wert = 1:5
        if length(num2str(zeitpkt(i_Wert))) == 1
            zeitpkt_str{i_Wert} = ['0',num2str(zeitpkt(i_Wert))];
        else
            zeitpkt_str{i_Wert} = num2str(zeitpkt(i_Wert));
        end
    end
    % Ausgabe
    fprintf(1,['\n\n\n -------------------------------------------------------------------------------\n',...
               '   Begin: Adaption step %d (Time: %s.%s.%s - %s:%s)\n',...
               ' -------------------------------------------------------------------------------\n\n'],...
                arg.info.nummer,zeitpkt_str{3},zeitpkt_str{2},zeitpkt_str{1},zeitpkt_str{4},zeitpkt_str{5})
end


%% Block 2
% Initialberechnung durchführen?
if arg.info.nummer == 1
    % Modell einlesen
    modell = caap_read_sap_file(arg.info.sap_file);
    
    % Modell checken
    modell = caap_check_model(modell,arg);
    
    % Vorbereitungen
    [modell, arg] = caap_prepare(modell,arg);
    
    % Auto-Export-Tabelle initial schreiben
    modell = caap_write_auto_export(modell,arg,'initial');
    
    % Zu rechnende Lastfälle definieren
    run_analysis = {'Yes','Yes','No'}; % Vertikallasten: ja, Modal-Analyse: ja, Pushover-Analyse: nein
    load_case_names = {arg.info.name_vert,arg.info.name_modal,arg.info.name_pushover};
    for i_case = 1:1:size(load_case_names,2)
        [i_LC, ~, ~] = find(strcmp(modell.LoadCaseDefinitions.Case(:,1),load_case_names{i_case}));
        modell.LoadCaseDefinitions.RunCase(i_LC) = run_analysis(i_LC);
    end
    
    % Modell rechnen (Lastfälle Vertikallasten & daran anschließende erste Modal-Analyse)
    caap_run_sap(modell,arg,'orc');
    
    % Initiale Ergebnisse, die später im Zuge der Zwischenberechnung
    % überschrieben werden, zunächst unter arg.comp.erg.schritt_0
    % abspeichern
    arg.comp.erg.(['schritt_' num2str(arg.info.nummer-1)]) = caap_read_sap_file(arg.info.export_file);
    % << Kurze Zwischenprüfung, ob die Berechnung des Lastfalls der
    % ständigen Lasten erfolgreich war und die modale Analyse demnach
    % erfolgreich gestartet/durchgeführt werden konnte:
    [modell,arg] = caap_check_calc_success(modell,arg);
    % Wenn erfolgreich:
    if arg.info.erfolg == 1
        % -> Prüfen, ob dies direkt der Fall war oder erst mit
        %    einem/mehreren weiteren Versuch(en) mit erhöhter
        %    Fehlertoleranz!
        % Wenn ja: Dann ist alles gut (nichts zu tun)!
        % Wenn nein:
        if arg.info.versuche_bis_erfolg > 1
            % Dann müssen die Ergebnisse der letzten (erfolgr.)
            % Berechnung erstmal neu eingeladen und damit die
            % Ergebnisse der zunächst erfolglosen Berechnung
            % "sauber" überschrieben werden!
            arg.comp.erg.(['schritt_' num2str(arg.info.nummer-1)]) = caap_read_sap_file(arg.info.export_file);
        end
    else
        % Wenn nicht erfolgreich: Ende der Berechnung
        error(['The initial calculation was not successful even after attempts to increase the maximum ',...
               'number of steps to be performed and (if desired) to increase the error tolerance several times! ',...
               'The calculation must therefore be aborted!'])
    end
    % Ende: Zwischenprüfung >>
    % Initiale Ergebnisse zusätzlich unter arg.comp.erg.schritt_1
    % abspeichern
    arg.comp.erg.schritt_1 = arg.comp.erg.schritt_0;
end


%% BLock 3
if arg.info.nummer ~= 1
    % Auto-Export-Tabelle updaten für LoadCase PushOver
    modell = caap_write_auto_export(modell,arg,'update_push');
end

% Kontrolle der (aktuellen) Eigenformen hinsichtlich der jew. "Richtung"
% ("positiv" oder "negativ" im Vergleich zur jew. initialen Form) und
% bezüglich möglicher "mode changes"
if ~(strcmp(arg.info.procedure,'standard') && strcmp(arg.comp.load_pattern,'mass'))
    arg = caap_check_eigenmodes(arg);
end

% Im allerersten Schritt (bei arg.info.nummer ==1):
% Knoten lokalisieren
if arg.info.nummer ==1
    arg = caap_locate_nodes(arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]),arg);
end

% Lastverteilung ermitteln...
arg = caap_pushover_pointloads(arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]),arg); % max(arg.info.nummer-1),1): im ersten Schritt natürlich 1, im zweiten dann 1, im dritten 2 usw.
% ** im Fall des Wechsels von "ami_o" zu "ami_c", wenn nämlich im Fall von
% "ami_o" IM AKTUELLEN ADAPTIONSSCHRITT negative maximale Spektralbe-
% schleunigungsinkremente vorlagen, noch die Pointloads des letzten
% Pushover-Lastfalls löschen, den letzten Pushover- & Modalanalyse-Lastfall
% löschen und die Lastfall-Namen anpassen:**
if isfield(arg.info,'ami_o_zu_ami_c') && arg.info.ami_o_zu_ami_c == arg.info.nummer % die zweite Überprüfung ist wichtig, damit die entspr. Korrektur NUR in dem EINEN Schritt erfolgt, indem die negativen Spektralbeschl.-inkr. aufgetreten sind!
    [modell,arg] = caap_edit_ami_o_to_ami_c(modell,arg);
end
% ...und die neuen Lasten ins Modell schreiben
modell = caap_write_pointloads(modell,arg);

% "Alten" (aktuellen) PushOver-Lastfall rechnen: Yes
[i_pushover_old, ~, ~] = find(strcmp(modell.LoadCaseDefinitions.Case(:,1),arg.info.name_pushover_old));
modell.LoadCaseDefinitions.RunCase(i_pushover_old) = {'Yes'};

% Im Falle einer "ami_o"-Berechnung: min & max num states anpassen
if strcmp(arg.info.procedure,'ami_o')
    arg = caap_edit_min_and_max_num_state_stepwise(arg,modell);
end

% HAUPTUNTERSUCHUNG
% Modell rechnen
%{
=> Im Fall "standard" und "ami_o":
        Pushover-Analyse "bis zum Ende" -> "Max-Berechnung", d. h. konkret
        bis "v_target" (im Fall "standard") bzw. bis "S_a_n_max_von_i" 
        (im Fall "ami_o");
        diese "Max-Berechnung" wird im Zweifel später im Zuge der
        "Zwischenberechnung" noch einmal korrigiert (nach vorne hin)
=> Im Fall "ami_c":
        Pushover-Analyse für entspr. kleines spektrales
        Beschleunigungsinkrement (keine spätere Korrektur der Schrittweite)
%}
caap_run_sap(modell,arg,'orc');

% Ergebnisse einlesen & aufbereiten
arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]) = caap_read_sap_file(arg.info.export_file);

% Im ersten Programmdurchlauf beim modifizierten AMI-Verfahren (egal ob "ami_c" oder "ami_o"):
% Initiale, nicht adaptive Pushover-Kurve abspeichern
if arg.info.nummer == 1 && arg.comp.adaptive == 1 && any(strcmp(arg.info.procedure,{'standard','ami_o'})) % beim "ami_c"-Verfahren ist der erste Durchlauf nur das allererste Segment -> ergibt keine "Pushover-Kurve"
    arg = caap_build_pushover(arg.comp.erg.schritt_1,arg,'initial');
end


%% Block 4
% Adaptive Berechnung?
if arg.comp.adaptive == 1
    
    % PRÜFEN, OB NEUER ADAPTIONS-SCHRITT ERFORDERLICH
    % -> ERGEBNIS-ANALYSE (je nach Verfahren)
    switch arg.info.procedure
        case {'standard','ami_o'}
            % Untersuchung der Pushover-Kurve 
            % (dahingehend, ob bzw. wie weit man "übers Ziel" hinausgeschossen
            % ist im Hinblick auf die definierten adaptiven Grenzbedingungen)
            [arg,modell] = caap_analyze_pushover(arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]),arg,modell);

            % Weitere Sonderüberprüfung im Falle des "ami_o"-Verfahrens:
            % Prüfen, ob das maximale Spektralbeschleunigungsinkrement des
            % Bezugsmodes in primärer Bebenrichtung geringer war als 0,5 %
            % des bisherig maximalen:
            if strcmp(arg.info.procedure,'ami_o') && arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1) < 0.005 * max(arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(:,1))
                % Dann kann man auch aufhören!
                arg.comp.new_step = 0;
                % Informative Ausgabe
                fprintf(1,'\n The maximum spectral acceleration increment of the reference mode in the primary earthquake direction\n was less than 0.5 percent of the previous maximum increment of %.2f m/s² in step %d!\n',max(arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(:,1)),arg.info.nummer);
                fprintf(1,' One reason for this could be an increment that is minimally negative and therefore set to 0.\n');
                fprintf(1,' No further AMI step is therefore carried out.\n');
            end

            % Wenn ein neuer Grenzzustand identifiziert wurde (und beim
            % "ami_o"-Verf. der Inkrementschritt des Basismodes in primärer
            % Richtung noch "relevant" war), interessiert keinen Menschen,
            % ob die "Max-Berechnung" darüber hinaus erfolgreich war oder
            % nicht, aber:
            % Wenn KEIN neuer Grenzzustand identifiziert wurde und/oder beim 
            % "ami_o"-Verfahren die maximale Spektralbeschl. des Basismodes
            % in primärer Bebenrichtung erreicht wurde und somit KEIN WEITERER
            % Adaptionsschritt erforderlich ist:
            if arg.comp.new_step == 0
                % -> Prüfen, ob die letzte "Max-Berechnung" überhaupt
                % erfolgreich war, bzw. wenn nicht (bis zu vier mal) neu
                % versuchen, mit erhöhter Fehlertoleranz erfolgreich durch-
                % zuführen!
                %{
                Denn sonst könnte es ja sein, dass die letzte Max-Ber. von
                DELTA_kk = 8 cm bis 15 cm gehen sollte, aber aufgrund einer
                gescheiterten Gleichgewichtsiteration schon bei 8,5 cm
                abgebrochen wurde, sodass nur deshalb (in dem Zuwachs von
                0,5 cm) kein neuer Grenzzustand "entstanden" ist. Dann muss
                diese zunächst durch Erhöhung der Fehlertoleranz wiederholt
                werden, und dann nochmal geschaut werden, ob jetzt ein neuer
                Grenzzustand identifiziert werden kann.
                %}
                [modell,arg] = caap_check_calc_success(modell,arg);
                % Wenn erfolgreich:
                if arg.info.erfolg == 1
                    % -> Prüfen, ob dies direkt der Fall war oder erst mit
                    %    einem/mehreren weiteren Versuch(en) mit erhöhter
                    %    Fehlertoleranz!
                    % Wenn ja: Dann ist alles gut (nichts zu tun)!
                    % Wenn nein:
                    if arg.info.versuche_bis_erfolg > 1
                        % Dann müssen die Ergebnisse der letzten (erfolgr.)
                        % Berechnung erstmal neu eingeladen und damit die
                        % Ergebnisse der zunächst erfolglosen Berechnung
                        % "sauber" überschrieben werden!
                        arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]) = caap_read_sap_file(arg.info.export_file);
                        % Und die Pushover-Kurvenanalyse muss natürlich
                        % wiederholt werden!
                        [arg,modell] = caap_analyze_pushover(arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]),arg,modell);
                        % Nun kann es eben sein, dass arg.comp.new_step doch
                        % nicht mehr = 0 ist! ...
                    end
                % Wenn NICHT erfolgreich:
                else
                    % -> Dann bleibt es eben bei "arg.comp.new_step = 0" in
                    %    Kombination mit "arg.info.erfolg = 0", sprich:
                    %    Der Erdbeben-Nachweis ist gescheitert!
                end
            end
        case 'ami_c'
            % Überprüfung, ob der aktuelle/letzte Inkrementschritt
            % erfolgreich durchgeführt werden konnte (Logfile prüfen!),
            % bzw. wenn nicht (bis zu vier mal) neu versuchen, diesen
            % mit erhöhter Fehlertoleranz erfolgreich durchzuführen!
            [modell,arg] = caap_check_calc_success(modell,arg);
            % -> Wenn ja: (egal ob direkt oder erst im 2., 3. oder 4. Anlauf)
            %    Überprüfen, ob die maximalen modalen Spektral-
            %    beschleunigungen erreicht wurden (wäre wenn bei allen
            %    Moden gleichzeitig der Fall!)
                 if arg.info.erfolg == 1
                     
                     % Prüfen, ob:
                     % 1.) S_a_n_von_i etwa = S_a_n_max_von_i ? (wenn auch numerisch nie exakt gleich)
                     % -> Exemplarisch anhand des Bezugsmodes prüfen und
                     %    zwar dadurch, dass man so gerade noch unter
                     %    S_a_n_max_von_i liegt und im nächsten Schritt mit
                     %    DELTA_S_a_B zu weit laufen würde.
                     % 2.) ODER (wenn diese Bedingung am Ende des letzten
                     %    Schrittes zwar noch nicht erfüllt war aber)
                     %    INNERHALB der Funktion caap_pushover_pointloads
                     %    bei mindestens einem Mode ein negativer Wert für
                     %    DELTA_S_a_n_max herausgekommen ist, sprich man
                     %    also mit der NEUEN (geringeren) maximalen
                     %    Spektralbeschleunigung und der aus dem letzten
                     %    Schrtitt vorhandenen doch schon zu weit (bzw.
                     %    weit genug) gelaufen ist -> Dann wird in der o. g.
                     %    Routine arg.info.finish auf 1 gesetzt (und die
                     %    aktuelle i-te Berechnung in eine "0"-Berechnung
                     %    überführt).
                     if arg.comp.s_a_n.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1) + arg.comp.delta_s_a_b > arg.comp.s_a_n_max_i.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1) || arg.info.finish == 1
                         % Fall: Nachweis erfüllt! Ende der Berechnung,
                         % also kein weiterer Adaptionsschritt
                         % (arg.info.finish wird somit weiter unten autom.
                         % auf 1 gesetzt!)
                         arg.comp.new_step = 0;
                         % Entsprechende Ausgabe erfolgt in Block 6 (s. u.)!
                     else
                         % Fall: Es geht noch weiter!
                         arg.comp.new_step = 1;
                     end
                     
            % -> Wenn nein: 
            %    Dann ist der Nachweis (global) gescheitert und es kann
            %    kein Performance-Zustand erreicht werden!
                 else
                     % Fall: Nachweis nicht erfüllt! Ende der Berechnung
                     arg.info.finish = 1;
                 end
    end
    
    
    %% Block 5
    % Neuer Berechnungsschritt erforderlich?
    if arg.comp.new_step == 1

        % ÜBERPRÜFUNG UND GGF. INFORMATIVE ZWISCHENAUSGABE ZU NEU RELEVANT GEWORDENEN MODEN
        % -> Im Fall des AMI-Verfahrens (egal ob "ami_c" oder "ami_o")
        % könnte es jetzt für den Anwender interessant sein, im Falle neu
        % relevant gewordener Moden (bei denen M_eff_Rrelevant plötzlich 
        % > 5% ist) genau darüber informiert zu werden, um die Berechnung 
        % ggf. abbrechen und mit dem entspr. Mode von Anfang an berücksich-
        % tigend neu zu starten!
        if any(strcmp(arg.info.procedure,{'ami_c','ami_o'}))
            arg = caap_analyze_modal_participating_mass_ratios(arg);
        end

        % ZWISCHENBERECHNUNG
        % => Im Fall "standard" und "ami_o":
        % Den letzten PushOver-LC anpassen (je nach Verfahren)
        switch arg.info.procedure
            case 'standard'
                % Dann die Zielverschiebung anpassen (sodass nun nicht mehr
                % "übers Ziel hinausgeschossen", sondern der gefundene
                % Grenzzustand exakt angesteuert wird)
                [i_pushover_old, ~, ~] = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),arg.info.name_pushover_old));
                modell.Case0x2DStatic20x2DNonlinearLoadApplication.TargetDispl(i_pushover_old,1) = {strrep(mat2str(arg.comp.v_target(arg.info.nummer)),'.',',')};
            case 'ami_o'
                % Dann die (inkrementelle) Lastverteilung (Point Loads),
                % die ja "Full Load" gerechnet wird, an DELTA_vec_P_korr
                % anpassen (ANNAHME: LoadCase- und LoadPattern-Name der
                % PushOver-Ber. stimmen überein!)
                % (1) Alte Point Loads im Modell löschen
                modell = caap_delete_pointloads(modell,arg);
                % (2) Neue Point Loads ins Modell schreiben
                modell = caap_write_pointloads(modell,arg); % Holt sich mit "arg.comp.f_Matrix_akt" autom. die aktuellen (richtigen) Joint Loads und mit "arg.info.name_pushover_old" autom. den richtigen LF!
        end

        % Und bei nicht voll-automatischer adaptiver 
        % Berechnung einen neuen Vergleichslastfall erstellen      
        if any(strcmp(arg.info.procedure,{'standard','ami_o'})) && arg.comp.auto_run == 0
            % -> Entspr. neuen Pushover-Vergleichslastfall definieren für die
            %    spätere benutzerseitige (visuelle) Auswertung/Beurteilung
            % LoadCase PushOver-Vergleich erstellen
            modell = caap_delete_LC(modell,'PushOver_Vergleich','pushover_vergleich');
            modell = caap_create_new_LC(modell,arg,arg.info.name_pushover_old,'PushOver_Vergleich','pushover_vergleich');
        end
        
        % => In allen Fällen ("standard", "ami_c" & "ami_o"):
        % Neuen modalen Lastfall definieren
        modell = caap_create_new_LC(modell,arg,arg.info.name_modal_old,arg.info.name_modal_new,'modal');
          
        % Auto-Export-Tabelle updaten für LoadCase Modal
        modell = caap_write_auto_export(modell,arg,'update_modal');
          
        % Nächsten LoadCase Pushover vorbereiten (also für den nächsten Adaptionsschritt i+1) 
        modell = caap_create_new_LC(modell,arg,arg.info.name_pushover_old,arg.info.name_pushover_new,'pushover');
          
        % Neuen PushOver-Lastfall rechnen: No
        [i_pushover_new, ~, ~] = find(strcmp(modell.LoadCaseDefinitions.Case(:,1),arg.info.name_pushover_new));
        modell.LoadCaseDefinitions.RunCase(i_pushover_new) = {'No'};

        % Im Falle einer "ami_o"-Berechnung: min & max num states anpassen
        if strcmp(arg.info.procedure,'ami_o')
            arg = caap_edit_min_and_max_num_state_stepwise(arg,modell);
        end
        
        % Modell rechnen
        %{
        => Im Fall "standard" und "ami_o":
        korrigierten letzten Pushover-LF und daran anschl. neue Modalanalyse
        => Im Fall "ami_c":
        Lediglich neue Modalanalyse anknüpfend an die letzte (aktuelle)
        Pushover-Analyse der Hauptuntersuchung (nicht korrigiert)
        %}
        caap_run_sap(modell,arg,'orc');
        
        % Ergebnisse einlesen & aufbereiten
        arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]) = caap_read_sap_file(arg.info.export_file);
        
        % Im Fall "standard" und "ami_o":
        if any(strcmp(arg.info.procedure,{'standard','ami_o'}))
            % A) Prüfen, ob Korrekturberechnung erfolgreich war (Logfile prüfen!)
            %    bzw. wenn nicht (bis zu vier mal) neu versuchen, diese mit
            %    erhöhter Fehlertoleranz erfolgreich durchzuführen!
            [modell,arg] = caap_check_calc_success(modell,arg);
            % Wenn erfolgreich:
            if arg.info.erfolg == 1
                % -> Prüfen, ob dies direkt der Fall war oder erst mit
                %    einem/mehreren weiteren Versuch(en) mit erhöhter
                %    Fehlertoleranz!
                % Wenn ja: Dann ist alles gut (nichts zu tun)!
                % Wenn nein:
                if arg.info.versuche_bis_erfolg > 1
                    % Dann müssen die Ergebnisse der letzten (erfolgr.)
                    % Berechnung erstmal neu eingeladen und damit die
                    % Ergebnisse der zunächst erfolglosen Berechnung
                    % "sauber" überschrieben werden!
                    arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]) = caap_read_sap_file(arg.info.export_file);
                end
                % Wenn NICHT erfolgreich:
            else
                % Dann ist der Erdbeben-NW gescheitert & "arg.comp.erfolg = 0"
                % steht wirklich für den endgültigen Misserfolg der finalen
                % (gescheiterten) Berechnung.
                % -> Ende Gelände!
                arg.info.finish = 1;
            end
            % B) Prüfen, ob Korrekturberechnung erfolgreich war (Logfile prüfen!),
            %    bzw. wenn nicht (bis zu vier mal) neu versuchen, diese mit
            %    erhöhter Fehlertoleranz erfolgreich durchzuführen!

        end
        
        % Voll automatische adaptive Berechnung und kein Berechnungsabbruch
        % gefordert?
        if arg.comp.auto_run == 1 && arg.info.finish == 0
            % Dann eine Instanz höher gehen,
            arg.info.instanz = arg.info.instanz + 1;
            
            % PushOver-Kurve zusammenbauen...
            arg = caap_build_pushover(arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]),arg,'');
            
            % ... und die MAIN_CAAP-Routine sich selbst aufrufen lassen
            % und diese noch einmal komplett durchlaufen
            [modell,arg] = MAIN_CAAP(modell,arg);
        end
        
    else
        % Sonst (kein weiterer Step): Ende Gelände!
        arg.info.finish = 1;
        % Im Fall des "AMI_o"-Verfahrens noch die letzte (aktuelle)
        % Lastverteilungsmatrix archivieren (wird sonst immer im Zuge des
        % neuen Korrekturschrittes gemacht, der aber ja jetzt im letzten
        % Schritt nicht mehr erforderlich war)
        if strcmp(arg.info.procedure,{'ami_o'})
            arg.comp.f_matrix(:,:,arg.info.nummer) = arg.comp.f_matrix_akt;
        end

    end % Ende If new_step

else
    % Sonst (keine adaptive Ber.): Ende!
    arg.info.finish = 1;
    % Und: Prüfen, ob die eine (nicht-adaptive) Pushover-Analyse überhaupt
    % erfolgreich war, bzw. wenn nicht (bis zu vier mal) neu versuchen, 
    % diese mit erhöhter Fehlertoleranz erfolgreich durchzuführen!
    [modell,arg] = caap_check_calc_success(modell,arg);
    % Wenn erfolgreich:
    if arg.info.erfolg == 1
        % -> Prüfen, ob dies direkt der Fall war oder erdst mit
        %    einem/mehreren weiteren Versuch(en) mit erhöhter
        %    Fehlertoleranz!
        % Wenn ja: Dann ist alles gut (nichts zu tun)!
        % Wenn nein:
        if arg.info.versuche_bis_erfolg > 1
            % Dann müssen die Ergebnisse der letzten (erfolgr.)
            % Berechnung erstmal neu eingeladen und damit die
            % Ergebnisse der zunächst erfolglosen Berechnung
            % "sauber" überschrieben werden
            arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]) = caap_read_sap_file(arg.info.export_file);
        end
    end

end % Ende If adaptiv


%% Block 6
% Nur auf der ersten (untersten) Instanz Daten verarbeiten,
% Modell öffnen und Ausgaben tätigen
if arg.info.instanz == 1
    
    % PushOver-Kurve zusammenbauen
    arg = caap_build_pushover(arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]),arg,'');
    
    % War es die letzte Berechnung?
    if arg.info.finish == 1
        
        % Ggf. jetzt (erst) beginnen, die Konsolausgaben zu speichern, 
        % wenn das NICHT auf Skriptebene bereits initiiert wurde
        if ~strcmp(get(0,'Diary'),'on') % Überprüfung des "diary"-Status
            % Flagge setzen
            flag_diary_skriptebene = 0;
            % txt-Datei mit Konsol-Ergebnissen löschen, wenn bereits vorhanden
            if exist('Ergebnisse_Konsole.txt', 'file')==2
                diary off
                delete('Ergebnisse_Konsole.txt');
            end
            % Nun eine neue Datei anlegen & beginnen, die Konsole "aufzunehmen"
            diary Ergebnisse_Konsole.txt
        else
            % Flagge setzen
            flag_diary_skriptebene = 1;
        end
        
        % Ausgaben und ggf. Postprocessing (NW etc.) je nach Verfahren
        switch arg.info.procedure
            case 'standard'
                if arg.info.erfolg == 1
                    % Rechnung fehlerfrei, nur Ausgabe
                    fprintf('The target displacement of %d m in node %d was achieved in the last calculation step!\n',arg.comp.v_grenz,str2double(arg.comp.kk));
                  else
                    % Rechnung NICHT fehlerfrei, nur Ausgabe
                    fprintf(2,'\n The target displacement of %d m in node %d was NOT reached in the last calculation step!\n',arg.comp.v_grenz,str2double(arg.comp.kk));
                end
                
                % Wenn Ausgabe verlangt
                if arg.info.console == 1
                    % PushOver-Kurve plotten...
                    arg = caap_plot_pushover_curve(modell,arg);
                    % ...und speichern
                    savefig(gcf,[sap_filepath,'\Pushoverkurve.fig'])
                end
                
                if arg.comp.check == 1
                    % PP suchen
                    % -> Kapazitätsspektrum aufbauen
                    arg = caap_CS_ATC40(modell,arg);
                    % -> PP-Ermittlung
                    % --Zwischenschritt: Prüfen, ob die primäre
                    % Bebenrichtung horizontal oder vertikal ist
                    switch arg.comp.d_earthquake{1,1}
                        case {'X','Y'}
                            arg.rs.richtung = 'horizontal';
                        case 'Z'
                            arg.rs.richtung = 'vertikal';
                    end
                    % --(Ende: Zwischenschritt)--
                    arg = caap_CSM_determine_PP(modell,arg);

                    % Bei erfolgreicher PP-Ermittlung:
                    if arg.comp.pp.erfolg == 1
                        % (A) Neue (finale) Berechnung zum Performance-Zustand
                        % Hinweis: In dieser Funktion werden alle Pushover-
                        % Lastfälle zu den späteren Adaptionsschritten bzw.
                        % Segmenten, nach demjenigen, in dem der PP liegt,
                        % gelöscht und das DELTA v_target dieses betroffenen
                        % Lastfalls so angepasst, dass v_ges im Kontrollkn.
                        % AM ENDE dieses Lastfalls bzw. Segments (sprich zum 
                        % Beispiel in Schritt 50/50, nicht in dem Schritt, wo
                        % der PP vorher lag) genau v_kk entspricht und die
                        % Schnittgrößen im Tragwerk dann exakt zum
                        % Performance-Zustand korrespondieren!!!
                        [modell,arg] = caap_final_performance(modell,arg);

                        % (B) Ggf. Irregularitätsindex ermitteln
                        if arg.comp.vi == 1 % Randbemerkung: Wert 1 bzw. true nur möglich bei 'procedure' = 'standard', 'check' = 1 & 'adaptiv' = false durch "caap_check_varargin"
                            % Dafür zunächst eine neue Modalanalyse
                            % durchführen
                            % -> Neuen modalen Lastfall definieren
                            modell = caap_create_new_LC(modell,arg,arg.info.name_modal_old,arg.info.name_modal_new,'modal');
                            % -> Auto-Export-Tabelle updaten für LoadCase Modal
                            modell = caap_write_auto_export(modell,arg,'update_modal');
                            % -> Modell rechnen
                            caap_run_sap(modell,arg,'orc');
                            % -> Ergebnisse einlesen & aufbereiten
                            arg.comp.erg.('modalanalyse_im_performance_zustand') = caap_read_sap_file(arg.info.export_file);
                            % -> Mögliche Vorzeichenwechsel der Eigenformen und Mode-Switches identifizieren
                                    % << Zwischenschritt: Dafür kurz so tun,
                                    % als sei die letzte Modalanalyse im
                                    % "Step 2" erfolgt, da aber der Aufruf
                                    % der "ceck eigenmodes"-Routine sonst
                                    % am Anfang von Schritt 3 erfolgt wäre,
                                    % muss man die Schritt-Nr.-bezogenen
                                    % Ergebnisse temporär umspeichern (für
                                    % einen korrekten Zufriff)
                                    arg.info.nummer = 2;
                                    arg.comp.erg.schritt_1_backup = arg.comp.erg.schritt_1;
                                    arg.comp.erg.schritt_1 = arg.comp.erg.modalanalyse_im_performance_zustand;
                                    arg.info.name_modal_old_backup = arg.info.name_modal_old;
                                    arg.info.name_modal_old = arg.info.name_modal_new;
                                    % Ende Zwischenschritt >>
                            arg = caap_check_eigenmodes(arg);
                                    % Ergebnisse wieder speichern wie vorher
                                    arg.comp.erg.schritt_1 = arg.comp.erg.schritt_1_backup;
                                    arg.comp.erg = rmfield(arg.comp.erg,'schritt_1_backup');
                                    arg.info.name_modal_old = arg.info.name_modal_old_backup;
                                    arg.info = rmfield(arg.info,'name_modal_old_backup');
                            % Irregularitätsindex ermitteln...
                            arg = caap_determine_vi(arg);
                            % ...und ausgeben
                            fprintf('\n The variation index, which was determined based on the change in the reference mode (initial number: %d) \n in the primary earthquake direction (%s), is around %d percent in this case!\n',...
                                    abs(arg.comp.modes.(arg.comp.d_earthquake{1,1})(1,1)),arg.comp.d_earthquake{1,1},round(arg.comp.vi_wert));
                            % Modell öffnen ohne zu rechnen
                            caap_run_sap(modell,arg,'o');
                        end
                    end
                end

            case {'ami_c','ami_o'}
                % Zwischenschritt: Letzte maßgebende maximale
                % Spektralbeschleunigung des Bezugsmodes ermitteln
                if arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(end,1) ~= 0
                    % Normalfall
                    s_a_B_max = arg.comp.s_a_n_max_i.(arg.comp.d_earthquake{1,1})(end,1);
                else
                    % Es gab INNERHALB der letzten Berechnung (in
                    % caap_pushover_pointloads) ein negatives maximales
                    % Spektralbeschleunigungsinkrement
                    % -> Dann ist die letzte Berechnung eine
                    % "0"-Berechnung gewesen, die "nicht zählt"!
                    s_a_B_max = arg.comp.s_a_n_max_i.(arg.comp.d_earthquake{1,1})(end-1,1);
                end
                if arg.info.erfolg == 1
                    % Nachweis erbracht, nur Ausgabe...
                    disp(' '); % Leerzeile einfügen
                    fprintf('The seismic design check was successful with a final spectral acceleration of %d m/s^2\n (maximum value: %d) of the reference mode %d in the global %s direction!\n',...
                                arg.comp.s_a_n.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1),s_a_B_max,abs(arg.comp.modes.(arg.comp.d_earthquake{1,1})(1)),arg.comp.d_earthquake{1,1});
                    fprintf('This corresponds to a mp displacement (of node %s) of %d m\n and a base shear of %d kN in the %s direction.\n',...
                                arg.comp.kk,arg.comp.pushoverkurve.gesamt(end,1),arg.comp.pushoverkurve.gesamt(end,2),arg.comp.d_earthquake{1,1});
                    % und ggf. akkustische Eskalation
                    if arg.info.sound == 0.5
                        try
                            hupe('zug');
                        catch
                            fprintf(2,'Unfortunately the jingle could not be played!\n')
                        end
                    elseif arg.info.sound == 1
                        try
                            [y,Fs] = audioread('jingle_caap_success.mp3');
                            sound(y,Fs)
                        catch
                            fprintf(2,['Unfortunately the jingle could not be played!\n',...
                                       'Possibly, enter "hdwwiz.cpl" in the Windows "cmd" window, deactivate "Realtek(R) Audio" once and then activate it again!'])
                        end
                    end
                else
                    % Nachweis NICHT erbracht, nur Ausgabe...
                    disp(' '); % Leerzeile einfügen
                    fprintf(2,'\n The seismic design check failed, since the final maximum spectral acceleration\n of %d m/s^2 with respect to the reference mode %d in the global %s direction was not reached\n (and thus also all other max. mod. spectral accelerations)!\n',...
                                s_a_B_max,abs(arg.comp.modes.(arg.comp.d_earthquake{1,1})(1)),arg.comp.d_earthquake{1,1});
                    % und ggf. Trauer-Jingle
                    if ismember(arg.info.sound,[0,0.5])
                        try
                            [y,Fs] = audioread('jingle_caap_fail.mp3');
                            sound(y,Fs);
                        catch
                            fprintf(2,'Unfortunately the jingle could not be played!\n')
                        end
                    end
                end

                % Kurze Überprüfung, ob ein Mode in einer Bebenrichtung
                % angesetzt wurde, in der er IN KEINEM AMI-Schritt einen
                % nennenswerten Anteil hatte
                caap_check_relevance(arg)
                
                % Wenn Ausgabe verlangt
                if arg.info.console == 1
                    % PushOver-Kurve plotten...
                    arg = caap_plot_pushover_curve(modell,arg);
                    % ...und speichern
                    savefig(gcf,[sap_filepath,'\Pushoverkurve.fig'])
                end
                
                % Modell öffnen ohne zu rechnen
                caap_run_sap(modell,arg,'o');
        end
    
    % Nein, es war noch nicht die letzte Berechnung
    else
        % Wenn Ausgabe verlangt
        if arg.info.console == 1
            % PushOver-Kurve plotten
            arg = caap_plot_pushover_curve(modell,arg);
        end
        
        % Modell öffnen ohne zu rechnen
        caap_run_sap(modell,arg,'o');
    end
    
    % In jedem Fall, wenn Ausgaben stattfinden sollen:
    if arg.info.console == 1
        % Ausgabe der durchgeführten Schritte
        if arg.comp.adaptive == 1
            if arg.comp.auto_run == 0
                ausgabe_str = ['Step ' num2str(arg.info.nummer) ' of the manually adaptive calculation finished.'];
            elseif arg.comp.auto_run == 1
                ausgabe_str = ['The automatic adaptive calculation was carried out with ' num2str(arg.info.nummer) ' step/s.'];
            end
            disp(ausgabe_str)
        end
    end
    
    % Ggf. jetzt (bereits) aufhören, die Konsolausgaben zu speichern,
    % wenn das NICHT auf Skriptebene (also außerhalb der CAAP-Main Function
    % und damit später) erfolgen soll
    if ~flag_diary_skriptebene
        % Aufhören, die Konsole "aufzunehmen" und das aufgenommene in die
        % entsprechende txt-Datei schreiben, wenn man NICHT in einer
        % Berechnung mit mehreren Lastkombinationen ist, wo die
        % Konsolausgaben sinnigerweise auf Skriptebene gespeichert werden!
        diary off
    end
    
    % Daten speichern
    % Namen vorbereiten
    if arg.comp.adaptive == 1 && arg.comp.auto_run == 1
        save_name = '_adaptive_automated_last_step';
    elseif arg.comp.adaptive == 1 && arg.comp.auto_run == 0
        save_name = '_adaptive__last_step';
    else
        save_name = '';
    end
    % Abspeichern der "arg"- & der "modell"-Variablen, je nach Fall:
    % Berechnung EINER bestimmten Lastkombination oder Schleife über
    % verschiedene Lastkombinationen (mit entspr. Unterordner
    % "Lastkombi__k"):
    if contains(sap_filepath,'Lastkombi')
        % "arg"-, "erg"- & "modell"-Struktur speichern
        save([sap_filepath '\arg_' sap_name save_name],'arg');
        save([sap_filepath '\modell_' sap_name save_name],'modell');
    else
        % "arg"-, "erg"- & "modell"-Struktur speichern
        save(['arg_' sap_name save_name],'arg');
        save(['modell_' sap_name save_name],'modell');
    end
    
else
    % Sonst: Eine Ebene herunterschrauben
    arg.info.instanz = arg.info.instanz - 1;

end

end
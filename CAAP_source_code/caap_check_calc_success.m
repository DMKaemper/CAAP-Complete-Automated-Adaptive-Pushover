function [modell,arg] = caap_check_calc_success(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_check_calc_success(modell,arg)
%
%   Prüft, ob die letzte durchgeführte Berechnung fehlerfrei durchgelaufen
%   ist.
%   Wenn nicht, wird zunächst EIN MAL die Anzahl der zul. Total Steps ver-
%   dreifacht und die Anzahl der zul. Null-Steps auf denselben Wert gesetzt
%   (damit es daran auch nicht scheitert) und dann werden (im Falle von 
%   "arg.comp.d_tol ungleich 0) vier (!!!) weitere Versuche mit einer neuen,
%   jew. um arg.comp.d_tol erhöhten Konvergenztoleranz durchgeführt bevor als
%   neue (von August 2022) ENDGÜLTIGE ULTIMA RATIO die Anzahl der Pushover-
%   schritte (hart) auf mind. 2 und max. 5 gesetzt wird.
%   Bleibt auch dieser Schritt erfolglos, wird ein endgültiges
%   Scheitern dieser Berechnung ausgesprochen.
%
% >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
% => Ausnahme/Zusätzlicher Zwischenschritt (seit dem 09.08.2022):
%    Bei nicht erfolgreicher letzter Berechnung wird im Fall des "ami_o"-
%    Verfahrens zusätzlich geprüft, ob das maximale Knotenlastinkrement des
%    aktuellen Schrittes kleiner ist als 1 % des bisherigen Maximums:
%    Dann (bei sehr kleinen Lastinkrementen) wird zunächst noch versucht,
%    die Anzahl der "nl_steps" auf einen gewissen Anteil "n" der eigentlich
%    gewünschten herunterzusetzen, da häufig ein Gleichgewichts-Iterations-
%    problem NUR darin besteht, z. B. 20 Pushover-Schritte bei einem sehr
%    sehr kleinen DELTA P-Vektor durchzuführen (im Zuge der Korrektur-
%    Berechnung des "ami_o"-Verfahrens)!!!
%    -> Der entspr. Faktor "n", mit dem der Min- & MaxNumState reduziert
%       wird (gem. Min/MaxNumState_neu = Min/MaxNumState / n), ergibt sich
%       aus einer Benutzereingabe, die verlangt wird!
% <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

% Es wurde bisher ein Versuch unternommen, diese Berechnung durchzuführen.
counter = 1;

% Wir tun zu Beginn mal so, dass die Berechnung nicht erfolgreich war!
flag_erfolg = 0;
do_again = 1; % sprich: man muss nochmal "ran"

% Übergeordnete "While"-Schleife, bis man nicht nochmal "ran" muss bzw. darf
while do_again == 1
    %% Log_file scannen
    log_file = caap_scan_logfile(arg);
    % Fall: Alles tutti!
    if log_file.n_error == 0 && log_file.n_warning == 0
        % Berechnung war erfolgreich...
        flag_erfolg = 1;
        % ...und muss demnach nicht neu durchgeführt werden.
        do_again = 0;
    % Fall: Es ist NICHT alles tutti!
    else
        %% -> Wurden Fehler gefunden?
        if log_file.n_error > 0
            error('According to the LOG file, there must have been serious errors. Please check!')
        end
        %% -> Oder wurden Warnungen gefunden?
        if log_file.n_warning > 0
            % Wenn ja:
            % => Gibt es bei den Warnungen eine, dass in einem Lastfall...
            %  (1) die Null und/oder Total Steps erreicht wurden, sprich:
            %      Es gab wirklich gescheiterte Lastfälle?
            %  (2) ODER die Struktur "unstable" bzw. "ill conditioned" ist?: 
            %      Dann liegt ein instabiler oder zumindest indifferenter
            %      Gleichgewichtszustand vor und es wird BEIM ERSTEN AUFTRETEN
            %      EINES SOLCHEN STABILITÄTSPROBLEMS eine entsprechende
            %      Warnung in die Konsole geschrieben!
            %      Im weiteren Berechnungsverlauf (wenn "arg.info.flag_ill_-
            %      conditioned_or_unstable" dann 1 ist) wird darauf nicht mehr geachtet!
            [~,flag_null_oder_totalsteps,flag_ill_conditioned_or_unstable] = find_loadcases_failed(modell,log_file);
            % => Zwischenabfrage, ob Fall (2) ERSTMALIG vorliegt (sprich: "flag_ill_conditioned_or_unstable" = 1 & arg.info.flag_ill_conditioned_or_unstable existiert noch nicht!)
            if flag_ill_conditioned_or_unstable && ~isfield(arg.info,'flag_ill_conditioned_or_unstable')
                % -> Dann die Information, dass es jetzt eine "ill
                %    conditioned bzw. unstable"-Warnung bereits gab,
                %    für den nächsten Pushover-Schritt merken!
                arg.info.flag_ill_conditioned_or_unstable = 1;
                % -> Dann kann man IMMER davon ausgehen, dass der letzte
                %    Pushover-Lastfall zu einem indifferenten bzw. instabilen
                %    Gleichgewicht geführt hat!
                if arg.info.nummer == 1
                    lc_unstable = arg.info.name_pushover;
                else
                    lc_unstable = [arg.info.name_pushover,'__',num2str(arg.info.nummer)];
                end
                % -> Informative, warnende Ausgabe über diesen Umstand bzw. diese Maßnahme ausgeben
                fprintf(2,['\n ATTENTION: The calculation of the load case %s resulted in an indifferent or \n',...
                    'unstable state of equilibrium!\n'],lc_unstable)
            end
            % => Bzw.: Gibt es das Feld "flag_nullberechnung" in "arg.comp",
            %    welches anzeigt, dass zuletzt (also im aktuellen Schritt)
            %    eine "0-Berechnung" durchgeführt wurde. Dann ist selbst das
            %    Erreichen der Null oder Total Steps unkritisch und der
            %    Schritt insgesamt als erfolgreich einzustufen!
            if isfield(arg.comp,'flag_nullberechnung')
                flag_nullberechnung = 1;
            else
                flag_nullberechnung = 0;
            end
            % (A) NEIN, DIE MAX NULL oder TOTAL STEPS WURDEN NICHT ERREICHT
            %     ODER IM AKTUELLEN SCHRITT WURDE EINE 0-BERECHNUNG DURCHGEFÜHRT
            %     (Dann sind die Warnungen in jedem Fall unkritisch!)
            if ~flag_null_oder_totalsteps || flag_nullberechnung
                % Berechnung war erfolgreich...
                flag_erfolg = 1;
                % ...und muss demnach nicht neu durchgeführt werden.
                do_again = 0;
                % (B) JA! Es gab (mind.) einen Lastfall (im Zweifel ist es der
                %     letzte gerechnete!!!), der gescheitert ist, da die zul.
                %     Anzahl an Null oder Total Steps erreicht wurde!
            else
                % Wenn es bisher nur die erste "ganz normale" Berechnung gab:
                if counter == 1
                    % Dann erstmal die Warnungen einzeln auf ihren Inhalt prüfen
                    [indizes_LCs_failed,~] = find_loadcases_failed(modell,log_file);
                    % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                    % Ausnahme/Zusätzliche Zwischenüberprüfung (wie oben beschrieben):
                    % Liegt eine (verm. "Korrektur-")Berechnung des "ami_o"-Verfahrens mit IN
                    % DIESEM SCHRITT sehr kleinen Lastinkrementen vor, bei der GENAU EIN
                    % (nämlich der letzte) LOAD CASE die Null oder Total Steps erreicht hat?
                    if strcmp(arg.info.procedure,{'ami_o'}) && (max(max(abs(arg.comp.f_matrix_akt))) / max(max(max(abs(arg.comp.f_matrix))))) < 0.01 && length(indizes_LCs_failed) == 1
                        % Fall: AMI-Verfahren mit optimierten Spektralbeschleunigungsinkrementen
                        %       und sehr sehr kleinen Lastinkrementen im letzten (gescheiterten) Lastfall
                        % -> Gescheiterten Pushover-Lastfall auslesen
                        lc_failed = modell.Case0x2DStatic40x2DNonlinearParameters.Case{indizes_LCs_failed};
                        % -> Informative, warnende Ausgabe über diesen Umstand bzw. diese Maßnahme ausgeben
                        fprintf(2,['\n ATTENTION: The calculation of the load case %s was not successful and the load increments were so small,\n',...
                            'that the number of nonlinear steps of min. %s and max. %s should be reduced!\n'],lc_failed,arg.comp.min_num_state_stepwise{indizes_LCs_failed},arg.comp.max_num_state_stepwise{indizes_LCs_failed})
                        fprintf(2,['Please define a factor "n" by which the two above-mentioned limit values are to be reduced\n',...
                            '(e.g. 2 for halving).\n',...
                            'Note: The floor function is used, i.e. 2 is used for MinNumState / n = 2.1!\n'])
                        % ---Benutzereingabe:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                        % "tic-toc"-Beziehung aufbauen
                        t_local = tic;
                        % Und ggf. eine kurze (informative)
                        % Mail rausschicken
                        if isfield(arg.info,'mail')
                            % Inhalt der Mail schreiben
                            arg.info.mail.content = sprintf(['ACHTUNG:\n',...
                                'The CAAP tool requires a user input for the current\n',...
                                'calculation in step ',num2str(arg.info.nummer),'\n',...
                                'for a reduction of the minimum and maximum\n', ...
                                'number of "nonlinear steps" of a failed\n',...
                                'AMI load case with very small load increments!']);
                            % Mail rausschicken
                            send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                                arg.info.mail.subject,arg.info.mail.content)
                        end
                        % While-Schleife, so lange, bis was eingetippt wurde, was sich in
                        % eine Zahl (Skalar) überführen lässt
                        flag_Faktor_ok = 0; % Noch keine verwertbare Eingabe
                        while ~flag_Faktor_ok
                            % Eingabe-Aufforderung - ggf. mit akustischer Warnung
                            if arg.info.sound == 0.5 || arg.info.sound == 1
                                try
                                    hupe('gong');
                                catch
                                    disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                                end
                            end
                            % Eingabe-Aufforderung
                            eingabestring = input(sprintf('Reduction factor (acc. to MinNumState_new = MinNumState / n, MaxNumState analogously): n = '),'s');
                            % Eingabe verarbeiten
                            if ist_typ(str2double(eingabestring),'int')
                                % Super Eingabe!
                                flag_Faktor_ok = 1;
                                % n auswerten
                                n = str2double(eingabestring);
                            end
                        end
                        % Ausgabe der Unterbrechungszeit
                        % (relevant, falls man die Eingabe-Aufforderung erst
                        % Stunden später bemerkt hat)
                        sec_local = toc(t_local); % [s]
                        disp(['The input interrupted the calculation for ',num2str(sec_local),' s!'])
                        hms_local = [floor(sec_local/3600),floor(rem(sec_local,3600)/60),floor(rem(rem(sec_local,3600),60))];
                        disp(['This corresponds to ',num2str(hms_local(1)),' h, ',num2str(hms_local(2)),' m and ',num2str(hms_local(3)),' s.'])
                        % ---Ende:-Benutzereingabe:----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                        % -> "nl_steps" für den gescheiterten Pushover-Lastfall (mit den sehr kleinen Lastinkrementen)
                        %    auf etwa (1/n)*100 % reduzieren (ERLÄUTERUNG ZUM HINTERGRUND/ZUR MOTIVATION: s. o., Zeile 15 ff.!!!),
                        %    mindestens aber natürlich einen Schritt rechnen!
                        nl_steps_lc_failed = max(floor([str2double(arg.comp.min_num_state_stepwise{indizes_LCs_failed}) str2double(arg.comp.max_num_state_stepwise{indizes_LCs_failed})] / n),1); % Anwendung des "floor"-Befehls deshalb, da bei 21 Schritten 2,1 nicht möglich sind, sondern dann 2 durchgeführt werden sollen!
                        % -> Informationen an arg-Struktur übergeben
                        if isfield(arg.comp,'nl_steps_lc_failed')
                            % Wenn bereits reduzierte nl steps zu (alten)
                            % anderen gescheiterten LFen vorliegen: aktuelle
                            % Informationen anhängen
                            anz_lc_failed_bisher = size(arg.comp.nl_steps_lc_failed,1);
                            arg.comp.nl_steps_lc_failed{anz_lc_failed_bisher+1,1} = nl_steps_lc_failed;
                            arg.comp.nl_steps_lc_failed{anz_lc_failed_bisher+1,2} = lc_failed;
                        else
                            % Ansonsten: Entsprechendes Feld "nl_steps_lc_failed"
                            % in "arg.comp" erzeugen
                            arg.comp.nl_steps_lc_failed = {nl_steps_lc_failed,lc_failed};
                        end
                        % Modell rechnen
                        caap_run_sap(modell,arg,'orc')
                        % Anzahl der durchgeführten Berechnungen um 1 erhöhen
                        counter = counter + 1;
                        % <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                        % Ansonsten (weiterhin im Fall "counter == 1"), wie oben beschrieben,
                        % erstmal an der Anzahl der jew. Lastfall-bezogenen zulässigen Total
                        % und Null-Steps "herumschrauben"
                        % Gescheiterte Lastfälle identifizieren
                    else
                        % Schleife über alle gescheiterten Lastfälle
                        for i_LC_failed = 1:length(indizes_LCs_failed)
                            % Aktuellen Load Case auslesen
                            index_LC_failed = indizes_LCs_failed(i_LC_failed);
                            % Neue maximale "Total-Steps"-Anzahl ermitteln und ins "modell" schreiben
                            totalsteps_alt = str2double(modell.Case0x2DStatic40x2DNonlinearParameters.MaxTotal{index_LC_failed});
                            totalsteps_neu = totalsteps_alt * 3;
                            modell.Case0x2DStatic40x2DNonlinearParameters.MaxTotal(index_LC_failed) = {mat2str(totalsteps_neu)};
                            % Neue maximale "Null-Steps"-Anzahl ermitteln und ins "modell" schreiben
                            nullsteps_neu = totalsteps_neu;
                            modell.Case0x2DStatic40x2DNonlinearParameters.MaxNull(index_LC_failed) = {mat2str(nullsteps_neu)};
                        end
                        % Neuen Berechnungsversuch auf jeden Fall starten, da man
                        % hier innerhalb des "if counter == 1"-Falls ist und es somit
                        % definitiv nicht schon 6 gescheiterte Versuche gab:
                        % Warnung ausgeben
                        fprintf(2,['There were convergence problems with LoadCase %s (attempt %s).\n',...
                            'The number of total steps is increased from %s to %s (tripled!)\n',...
                            'and the number of null steps is set to the same value.\n'],...
                            modell.Case0x2DStatic40x2DNonlinearParameters.Case{index_LC_failed},...
                            num2str(1),...
                            mat2str(totalsteps_alt),...
                            mat2str(totalsteps_neu))
                        % Modell rechnen
                        caap_run_sap(modell,arg,'orc')
                        % Anzahl der durchgeführten Berechnungen um 1 erhöhen
                        counter = counter + 1;
                    end
                % Wenn counter == 2 (sprich: es gab bisher schon zwei gescheiterte
                % Berechnungen und man würde jetzt die Fehlertoleranz
                % um d_tol erhöhen), d_tol aber gleich 0 ist:
                % Direkt zur "ULTIMA RATIO" übergehen!
                elseif counter == 2 && arg.comp.d_tol == 0
                    % Da keine Erhöhung der Fehlertoleranz gewünscht wurde,
                    % springt man automatisch in den Anwendungsfall der "ULTIMA
                    % RATIO", zum. sofern die "Null bzw. Total steps" das
                    % Problem waren:
                    % Gescheiterte Lastfälle identifizieren
                    [indizes_LCs_failed,~] = find_loadcases_failed(modell,log_file);
                    % Nonlinear steps für alle gescheiterten Lastfälle
                    % auf mind. 2 und max. 5 setzen!
                    modell.Case0x2DStatic40x2DNonlinearParameters.MinNumState(indizes_LCs_failed) = {'2'};
                    modell.Case0x2DStatic40x2DNonlinearParameters.MaxNumState(indizes_LCs_failed) = {'5'};
                    % Modell rechnen
                    caap_run_sap(modell,arg,'orc')
                    % Abschließend noch für den nächsten Schritt die Anzahl der
                    % durchgeführten Berechnungen um 1 erhöhen
                    counter = counter + 1;
                    % Und, was noch viel wichtiger ist:
                    do_again = 0; % Man war ja bereits bei der "ULTIMA RATIO", also gibt es trotz counter < 6 keinen weiteren Schritt!
                % ANSONSTEN:
                % a) Wenn es bisher noch nicht insges. 6 und damit "4 weitere Berechnungen"
                % (letztere mit jew. erhöhter Fehlertoleranz) gab:
                % Alle Warnungen einzeln auf Inhalt prüfen und die entsprechenden Lastfall-
                % bezogenen Iterationsfehlertoleranzen erhöhen.
                % b) Wenn es aber genau 6 waren: In den Fall "ULTIMA RATIO" übergehen
                % und die nonlinear steps der gescheiterten Lastfälle auf mind. 2 und
                % max. 5 setzen!
                elseif counter <= 6
                    % Gescheiterte Lastfälle identifizieren
                    [indizes_LCs_failed,~] = find_loadcases_failed(modell,log_file);
                    % Prüfen, ob obiger Fall a) oder b) vorliegt
                    if counter < 6
                        % Fall a): Es gibt noch (mind.) einen weiteren Schritt mit Erhöhung der Fehlertoleranz
                        % Schleife über alle gescheiterten Lastfälle
                        for i_LC_failed = 1:length(indizes_LCs_failed)
                            % Aktuellen Load Case auslesen
                            index_LC_failed = indizes_LCs_failed(i_LC_failed);
                            % Neue Fehlertoleranz ermitteln und ins "modell" schreiben
                            tol_alt = str2double(strrep(modell.Case0x2DStatic40x2DNonlinearParameters.ItConvTol{index_LC_failed},',','.'));
                            tol_neu = tol_alt + arg.comp.d_tol;
                            modell.Case0x2DStatic40x2DNonlinearParameters.ItConvTol(index_LC_failed) = {strrep(mat2str(tol_neu),'.',',')};
                            % Warnung ausgeben
                            fprintf(2,['There were convergence problems with LoadCase %s (attempt %s).\n',...
                                'The iteration convergence tolerance is increased from %s to %s.\n'],...
                                modell.Case0x2DStatic40x2DNonlinearParameters.Case{index_LC_failed},...
                                num2str(counter),...
                                strrep(mat2str(tol_alt),'.',','),...
                                strrep(mat2str(tol_neu),'.',','))
                        end
                    elseif counter == 6
                        %  Fall b): Es kommt zur Anwendung der "ULTIMA RATIO"
                        % Nonlinear steps für alle gescheiterten Lastfälle
                        % auf mind. 2 und max. 5 setzen!
                        % -> Reduzierte "nl_steps" definieren
                        nl_steps_lc_failed = [2 5];
                        % -> Informationen an arg-Struktur übergeben und Warnung(en) ausgeben
                        %    in Schleife über alle gescheiterten Lastfälle
                        for i_LC_failed = 1:length(indizes_LCs_failed)
                            % Aktuellen Load Case auslesen
                            index_LC_failed = indizes_LCs_failed(i_LC_failed);
                            lc_failed = modell.Case0x2DStatic40x2DNonlinearParameters.Case{index_LC_failed};
                            % Warnung ausgeben
                            fprintf(2,['There were convergence problems with LoadCase %s (attempt %s).\n',...
                                'The nonlinear steps have been reduced to a minimum of 2 and a maximum of 5.\n',...
                                'Please check whether these few pushover steps are justified\n',...
                                'by the brevity of the current step!\n'],...
                                modell.Case0x2DStatic40x2DNonlinearParameters.Case{index_LC_failed},...
                                num2str(counter))
                            % "arg.comp.nl_steps_lc_failed" mit den neuen,
                            % reduzierten nl steps füttern
                            if isfield(arg.comp,'nl_steps_lc_failed')
                                % Wenn bereits reduzierte nl steps zu (alten)
                                % anderen gescheiterten LFen vorliegen:
                                % aktuelle Informationen anhängen
                                anz_lc_failed_bisher = size(arg.comp.nl_steps_lc_failed,1);
                                arg.comp.nl_steps_lc_failed{anz_lc_failed_bisher+1,1} = nl_steps_lc_failed;
                                arg.comp.nl_steps_lc_failed{anz_lc_failed_bisher+1,2} = lc_failed;
                            else
                                % Ansonsten: Entsprechendes Feld "nl_steps_lc_failed"
                                % in "arg.comp" erzeugen
                                arg.comp.nl_steps_lc_failed = {nl_steps_lc_failed,lc_failed};
                            end
                        end
                    end
                    % Modell rechnen
                    caap_run_sap(modell,arg,'orc')
                    % Abschließend noch für den nächsten Schritt die Anzahl der
                    % durchgeführten Berechnungen um 1 erhöhen
                    counter = counter + 1;
                % ANSONSTEN, wenn es also 4 "weitere" Berechnungen gab:
                else
                    % Bei "counter ==7": Ende Glände!
                    do_again = 0;
                end
            end
        end
    end
end


%% Abschließende "Auswertungen"
% 1.) Auswertung, ob Berechnung (jetzt insgesamt, also final) erfolgreich
%     (unabh. davon, ob direkt oder erst nach einem/mehreren weiteren
%     Versuch(en))
if flag_erfolg
    arg.info.erfolg = 1;
    % 2.) Wenn ja: Zusätzliche Ausgabe der Versuche, um später zu wissen,
    %              ob der Erfolg direkt erzielt wurde oder erst mit einem/mehreren
    %              weiteren Versuch(en), z. B. mit erhöhter Fehlertoleranz!
    arg.info.versuche_bis_erfolg = counter;
else
    arg.info.erfolg = 0;
end

end



%% Sub-Routine zur Identifikation der gescheiterten Lastfälle

function [indizes_LCs_failed,flag_null_oder_totalsteps,flag_ill_conditioned_or_unstable] = find_loadcases_failed(modell,log_file)

% Vorbelegungen
indizes_LCs_failed = [];
flag_null_oder_totalsteps = 0;
flag_ill_conditioned_or_unstable = 0;
% Schleife über alle identifizierten Warnungen
for i_warning = 1:1:log_file.n_warning
    lok_warning = strsplit(log_file.warnings.(['warning_' num2str(i_warning)]),'\\n');
    % Maximale Anzahl an Null- oder Total-Steps erreicht oder "schlecht konditionierte Steifigkeitsmatrix"?
    index_null = strfind(lok_warning,'MAXIMUM NUMBER OF NULL STEPS REACHED');
    index_total = strfind(lok_warning,'MAXIMUM NUMBER OF TOTAL STEPS REACHED');
    index_ill_or_unstable = strfind(lok_warning,'STRUCTURE IS UNSTABLE OR ILL-CONDITIONED');
    if max(~cellfun(@isempty,index_null)) == 1 || max(~cellfun(@isempty,index_total)) == 1
        % flag setzen
        flag_null_oder_totalsteps = 1;
        % LoadCase dazu herausfinden
        index_case = strfind(lok_warning,'CASE');
        index_case = find(~cellfun(@isempty,index_case));
        loadcase = lok_warning{index_case};
        loadcase = strsplit(loadcase,' ');
        loadcase = loadcase{end};
        % Index des LoadCases ermitteln
        index_LC = find(strcmp(upper(modell.Case0x2DStatic40x2DNonlinearParameters.Case(:)),loadcase)); % "upper"-Befehl wichtig, da z. B. "Push_Y__12" bei einer Warnung von SAP2000 mit "PUSH_Y__12" bez. wird!!!
        % Index speichern
        indizes_LCs_failed = [indizes_LCs_failed; index_LC];
    elseif max(~cellfun(@isempty,index_ill_or_unstable))
        % flag setzen und fertig!
        flag_ill_conditioned_or_unstable = 1;
    end
end

end
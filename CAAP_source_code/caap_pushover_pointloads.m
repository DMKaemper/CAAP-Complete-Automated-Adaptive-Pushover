function arg = caap_pushover_pointloads(erg,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_pushover_pointloads(erg,arg)
%   
%   Funktion zur Ermittlung der Lastverteilung
%   ACHTUNG: Schreiben der Lastverteilung ins modell mittlerweile
%   outgesourct an caap_write_pointloads, bei "ami_c" bzw. "ami_o" ggf. 
%   noch mit vorgeschaltetem Aufruf von caap_delete_pointloads!!!
%
%   Fall "standard":
%   Mögliche Lastverteilungen, Proportionalität zu
%       - Masse: 'mass'
%       - monomodal: 'modal'
%       - Masse & monomodal: 'mass_modal'
%   UND im Fall "ami_c" bzw. "ami_o":
%       - Masse & multimodal sowie multidirektional nach dem
%         modifizierten AMI-Verfahren
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% MAIN Function
% Ergebnisse sortieren
erg = caap_sort_field(erg,'JointDisplacements','OutputCase');

% Lastverteilung je nach Verfahren
switch arg.info.procedure
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% "Standard"-Pushover-Verfahren
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    case 'standard'
        % Hier gibt es drei verschiedene Optionen der Lastverteilung
        switch arg.comp.load_pattern
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% massenproportional
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'mass'
                % Knotenmassen aufbereiten
                m_lok = sub_get_massen(erg,arg);

                % Kraftkomponenten mit Nullen vorbelegen
                F = zeros([size(m_lok,1),3,4]);
                
                % Schleife über alle Translationen
                for i_bebenrichtung = 1:1:size(arg.comp.d_earthquake,2)
                    F(:,arg.comp.d_earthquake{2,i_bebenrichtung},arg.comp.d_earthquake{2,i_bebenrichtung}) = ...
                        arg.comp.sign_factors(i_bebenrichtung) * m_lok(:,arg.comp.d_earthquake{2,i_bebenrichtung}) /...
                        sum(m_lok(:,arg.comp.d_earthquake{2,i_bebenrichtung}));
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% modalformproportional
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'modal'
                % Kraftkomponenten vorbelegen
                F = zeros([size(arg.comp.joint_lastverteilung.Werte,1),3,4]);
                
                % Liegenden Vektor der bebenrichtungsbezogenen
                % Vorzeichenfaktoren vorbelegen
                arg.comp.sign_factors = zeros(1,size(arg.comp.d_earthquake,2));
                
                % Schleife über alle Bebenrichtungen
                for i_bebenrichtung = 1:1:size(arg.comp.d_earthquake,2)
                    
                    % Initiale Modenummer der aktuell betrachteten Eigenform
                    % auslesen (mit Vorzeichen)
                    ModeNr_akt_1_mit_VZ = arg.comp.modes.(arg.comp.d_earthquake{1,i_bebenrichtung});
                    
                    % --Zwischenschritt: Mode-Nr. des richtungsbezogenen
                    % Modes ggf. korrigieren, wenn es "Mode-Switches"
                    % gab und dieser Mode davon betroffen ist --
                    % (I) Fall: Es gab BISHER KEINE derartigen Vertauschungen
                    % ODER sie betreffen den aktuellen Mode nicht.
                    if isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_1_mit_VZ),arg.comp.modes.changes(:,1)))
                        % Dann entspricht die aktuelle Mode-Nummer aus dem initialen
                        % Adaptionsschritt 1 derjenigen im aktuellen Schritt i.
                        ModeNr_akt_i_ohne_VZ = abs(ModeNr_akt_1_mit_VZ);
                    % (II) Fall: Es gab BEREITS MINDESTENS EINE derartige Vertauschung
                    %            und der aktuell betrachtete Mode ist hiervon betroffen.
                    else
                        % Dann die neue Nummer (des aktuellen Adaptionsschrittes i) entsprechend abspeichern
                        ModeNr_akt_i_ohne_VZ = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==abs(ModeNr_akt_1_mit_VZ),3);
                    end
                    % --Ende: Zwischenschritt--
                    
                    % Vorzeichen (wichtig für die Frage: Soll der Lastvektor
                    % in Richtung des korresp. PHI-Vektors wirken oder genau entgegengesetzt?)
                    arg.comp.sign_factors(i_bebenrichtung) = ModeNr_akt_1_mit_VZ / abs(ModeNr_akt_1_mit_VZ);
                    
                    % Skalierungsfaktor des modalen "Vorzeichen-Faktors"
                    % zur Korrektur möglicher EF-"Richtungswechsel" durch den
                    % Eigenwertlöser zw. der aktuellen und initialen Eigenform
                    % des aktuell betrachteten Modes
                    SF = arg.comp.modes.SF(arg.info.nummer,i_bebenrichtung); % i_bebenrichtung = "i_mode_initial" gem. caap_check_eigenmodes.m, line 270 (wo arg.comp.modes.SF zugeordnet und entspr. abgespeichert wird)
                    
                    % Nun den richtungsbezogenen PHI-Vektor der akt. Modalform ermitteln
                    modal_erg = sub_get_mode(erg,arg.info.name_modal_old,ModeNr_akt_i_ohne_VZ);
                    
                    if ~ist_typ(modal_erg,'logical')
                        % Verformungen rausschreiben
                        % Translationen (Rotationen werden nicht benötigt)
                        v = cellfun(@str2num,modal_erg(:,6:8));
                                                
                        % Schleife über alle Translationen
                        for i_komponente = 1:1:3
                            F(:,i_komponente,arg.comp.d_earthquake{2,i_bebenrichtung}) = ...
                                (arg.comp.sign_factors(i_bebenrichtung) * SF) * v(:,i_komponente) /...
                                abs(sum(v(:,arg.comp.d_earthquake{2,i_bebenrichtung})));
                        end
                    end
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% massen- & modalformproportional
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'mass_modal'
                % Knotenmassen aufbereiten
                m_lok = sub_get_massen(erg,arg);

                % Kraftkomponenten mit Nullen vorbelegen
                F = zeros([size(m_lok,1),3,4]);
                
                % Liegenden Vektor der bebenrichtungsbezogenen
                % Vorzeichenfaktoren vorbelegen
                arg.comp.sign_factors = zeros(1,size(arg.comp.d_earthquake,2));
                
                % Schleife über alle Bebenrichtungen
                for i_bebenrichtung = 1:1:size(arg.comp.d_earthquake,2)
                    
                    % Initiale Modenummer der aktuell betrachteten Eigenform
                    % auslesen (mit Vorzeichen)
                    ModeNr_akt_1_mit_VZ = arg.comp.modes.(arg.comp.d_earthquake{1,i_bebenrichtung});
                    
                    % --Zwischenschritt: Mode-Nr. des richtungsbezogenen
                    % Modes ggf. korrigieren, wenn es "frequency shifts"
                    % gab und dieser Mode davon betroffen ist --
                    % (I) Fall: Es gab BISHER KEINE derartigen Vertauschungen
                    % ODER sie betreffen den aktuellen Mode nicht.
                    if isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_1_mit_VZ),arg.comp.modes.changes(:,1)))
                        % Dann entspricht die aktuelle Mode-Nummer aus dem initialen
                        % Adaptionsschritt 1 derjenigen im aktuellen Schritt i.
                        ModeNr_akt_i_ohne_VZ = abs(ModeNr_akt_1_mit_VZ);
                    % (II) Fall: Es gab BEREITS MINDESTENS EINE derartige Vertauschung
                    %            und der aktuell betrachtete Mode ist hiervon betroffen.
                    else
                        % Dann die neue Nummer (des aktuellen Adaptionsschrittes i) entsprechend abspeichern
                        ModeNr_akt_i_ohne_VZ = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==abs(ModeNr_akt_1_mit_VZ),3);
                    end
                    % --Ende: Zwischenschritt--
                    
                    % Vorzeichen (wichtig für die Frage: Soll der Lastvektor
                    % in Richtung des korresp. PHI-Vektors wirken oder genau entgegengesetzt?)
                    arg.comp.sign_factors(i_bebenrichtung) = ModeNr_akt_1_mit_VZ / abs(ModeNr_akt_1_mit_VZ);
                    
                    % Skalierungsfaktor des modalen "Vorzeichen-Faktors"
                    % zur Korrektur möglicher EF-"Richtungswechsel" durch den
                    % Eigenwertlöser zw. der aktuellen und initialen Eigenform
                    % des aktuell betrachteten Modes
                    SF = arg.comp.modes.SF(arg.info.nummer,i_bebenrichtung); % i_bebenrichtung = "i_mode_initial" gem. caap_check_eigenmodes.m, line 270 (wo arg.comp.modes.SF zugeordnet und entspr. abgespeichert wird)
                    
                    % Nun den richtungsbezogenen PHI-Vektor der akt. Modalform ermitteln
                    modal_erg = sub_get_mode(erg,arg.info.name_modal_old,ModeNr_akt_i_ohne_VZ);
                    
                    if ~ist_typ(modal_erg,'logical')
                        % Verformungen rausschreiben
                        % Translationen (Rotationen werden nicht benötigt)
                        v = cellfun(@str2num,modal_erg(:,6:8));
                        
                        % Schleife über alle Translationen
                        for i_komponente = 1:1:3
                            F(:,i_komponente,arg.comp.d_earthquake{2,i_bebenrichtung}) = ...
                                (arg.comp.sign_factors(i_bebenrichtung) * SF) * (v(:,i_komponente) .* m_lok(:,i_komponente)) /...
                                abs(sum((v(:,arg.comp.d_earthquake{2,i_bebenrichtung}) .* m_lok(:,arg.comp.d_earthquake{2,i_bebenrichtung}))));
                        end
                    end
                end
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Modifizierttes AMI-Verfahren 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case {'ami_c','ami_o'}

        % <<Zwischenschritt: Eventuell vorh. hor./vert. Antwortspektren aus
        %   vorherigem Adaptionsschritt löschen:
        if isfield(arg.rs,'s_a_horizontal')
            arg.rs = rmfield(arg.rs,'s_a_horizontal');
        elseif isfield(arg.rs,'s_a_vertikal')
            arg.rs = rmfield(arg.rs,'s_a_vertikal');
        end
        % (Ende: Zwischenschritt)>>

        % Ermittlung der maximalen modalen Spektralbeschleunigungsinkremente
        arg = sub_DELTA_S_a_n_max(arg,erg); % läuft in Schleife über alle Bebenrichtungen, und untergeordnet in einer weiteren Schleife über alle dort zu berücksichtigenden Moden (die sich auf die initiale Modal-Analyse beziehen)
        %{
        Hinweis:
        Bei dem modifizierten AMI-Verfahren (egal ob "ami_c" oder "ami_o")
        ist es bekanntermaßen so, dass die verschiedenen Moden
        INNERHALB eines Berechnungsschrittes wenn alle gleichzeitig
        ihre maximale Spektralbeschleunigung erreichen würden.
        => Nun kann jedoch ZWISCHEN zwei Adaptionsschritten der Fall eintreten,
           dass die neue maximale Spektralbeschleunigung des aktuellen (neuen)
           Schrittes KLEINER ist ls die letzte tatsächliche (gilt ebenfalls für
           beide Verfahren gleichermaßen). Dies muss jedoch bzw. wird i. Allg.
           NICHT BEI ALLEN MODEN gleichzeitig auftreten, da es eben ZWISCHEN
           zwei Adaptionsschritten davon abhängt, wie sich die neuen maximalen
           Spektralbeschleunigungen ergeben/entwickeln (ist unabh. voneinander).
        %}
        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % << Zwischenschritt:
        %    Prüfen, ob das Spektralbeschleunigungsinkrement EINES (beliebigen)
        %    Modes in EINER betrachteten Bebenrichtung negativ ist:
        for i_bebenrichtung = 1:1:size(arg.comp.d_earthquake,2)
            if any(arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,i_bebenrichtung})(arg.info.nummer,:) < 0)
                % Offenbar liegt der SONDERFALL vor, bei dem mindestens eine
                % der neu ermittelten maximalen modalen Spektralbeschleunigungen
                % geringer ist, als die letzte vorhandene!
                % Dann: Umgang hiermit je nach Fall "ami_c" oder "ami_o"
                switch arg.info.procedure
                    case 'ami_c'
                        % Dann war der letzte Berechnungsschritt offenbar doch
                        % schon "ausreichend", obwohl für alle Moeden n galt:
                        % S_a_n^(i-1) + lambda_n^(i-1) * DELTA_S_a_B <= S_a_n,max^(i-1)
                        % -> Das muss dann an einer deutlich reduzierten
                        %    maximalen Spektralbeschleunigung S_a_n,max^(i) des
                        %    betroffenen Modes liegen!
                        % Daher nun alle maximalen Spektralbeschleunigungsinkremente
                        % auf 0 setzen (und damit eine "0"-Rechnung provozieren);
                        % ist algorithmisch einfacher als an dieser Stelle einen
                        % Berechnungsabbruch zu erzeugen!
                        % => Dann aber direkt auch in allen Bebenrichtungen
                        % eine "0"-Rechnung erzwingen:
                        for i_R = 1:1:size(arg.comp.d_earthquake,2)
                            arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,i_R})(end,:) = 0;
                        end
                        % Und arg.info.finish für spätere Überprüfung in der MAIN
                        % function auf 1 setzen (damit er nach dieser "0"-Runde
                        % nicht wieder zu dem Schluss kommt: Ick dreh noch n
                        % Ründchen...)
                        arg.info.finish = 1;
                        % Warnung ausgeben
                        fprintf(2,['\n Attention: A negative maximum spectral acceleration increment (at least one) was detected in step ',num2str(arg.info.nummer),'!\n',...
                            'Now that the calculation is finished, please check whether the other modes are close enough to their maximum spectral acceleration!\n'])
                        % "if-Abfrage" abbrechen
                        break
                    case 'ami_o'
                        % Dann wird das Verfahren auf "ami_c" umgestellt,
                        % sprich es wird von nun an für das letzte "Rest-
                        % stück" bis zum Erreichen des Performance Zustandes
                        % ein konstantes Spektralbeschleunigungsinkrement
                        % für den Bezugsmode angesetzt.
                        arg.info.procedure = 'ami_c';
                        % Darüber hinaus muss der letzte
                        % Berechnungsschritt wiederholt werden, also:
                        % arg.info.nummer um 1 reduzieren
                        arg.info.nummer = arg.info.nummer - 1;
                        % Die alten Point Loads des letzten Pushover-Lastfalls müssen in
                        % der MAIN-Routine gelöscht werden (aber eben NUR für den betr.
                        % Schritt), dafür wird nun eine Erkennungsvariable mit der
                        % betroffenen (wieder aktuellen alten) Schritt-Nummer belegt:
                        arg.info.ami_o_zu_ami_c = arg.info.nummer;
                        % Ein bisschen was zusätzlich aufbereiten
                        [arg,erg] = sub_edit_ami_o_zu_ami_c(arg);
                end
            end
        end
        % Ende: Zwischenschritt >>
        % --------------------------------------------------------------------------------------------------------------------------------------------------

        % Knotenmassen aufbereiten
        m_lok = sub_get_massen(erg,arg);

        % Kraftkomponenten mit Nullen vorbelegen
        F = zeros([size(m_lok,1),3,4]);
        
        % Richtungsbezogene Matrizen mit knoten- und wirkungsrichtungs-
        % bezogenen Knotenlasten (Erg. je einer best. Summe in der Best.-gl.
        % von DELTA vec P_max) aufbauen
        % (Schleife über alle Bebenrichtungen)
        for i_bebenrichtung = 1:1:size(arg.comp.d_earthquake,2)
            
            % Aktuelle Bebenrichtung auslesen
            R_akt = arg.comp.d_earthquake{1,i_bebenrichtung};
            
            % << Zwischenschritt: Aktuelle Mode-Nummer des Bezugsmodes der
            %    betrachteten Richtung bestimmen
            % (I) Fall: Es gab BISHER KEINE FREQUENCY-SHIFTS
            %           ODER sie betreffen den Bezugsmode nicht.
            if isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(arg.comp.modes.(R_akt)(1)),arg.comp.modes.changes(:,1)))
                % Dann entspricht die Bezugsmode-Nummer aus dem initialen
                % Adaptionsschritt 1 derjenigen im aktuellen Schritt i.
                ModeNr_B_i_R_akt_ohne_VZ = abs(arg.comp.modes.(R_akt)(1));
            % (II) Fall: Es gab BEREITS MINDESTENS EINEN FREQUENCY-SHIFT
            %            und der Bezugsmode ist hiervon betroffen.
            else
                % Dann die neue Nummer (des aktuellen Adaptionsschrittes i) entsprechend abspeichern
                ModeNr_B_i_R_akt_ohne_VZ = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==abs(arg.comp.modes.(R_akt)(1)),3); % kein abs()-Befehl notw., da in arg.comp.modes.changes nur Integer-Werte stehen!
            end
            % (Ende: Zwischenschritt)>>
            
            % Verschiedene modale Informationen/Werte/Vektoren für alle Moden
            % ermitteln, die in der akt. Richtung berücksichtigt werden sollen,
            % und daraus den entspr. Anteil an "DELTA vec P_max von i und k" ermitteln
            % (Schleife über alle in der akt. Richtung relevanten Moden; zunächst
            % bezogen auf die initiale Modal-Analyse, deren Nummern in arg.comp.modes.R stehen)
            %{
            HINWEIS:
            Grundsätzlich kann es im Zuge einer adaptiven Berechnung 
            Vertauschungen von Moden geben, wenn deren Eigenfrequenzen nah
            beieinander liegen und irgendwann plötzlich die ehemals
            kleinere größer ist als die andere.
            -> Erstmal prüfen, ob es überhaupt irgendwelche Vertauschungen gab/gibt,
            wenn ja: Feld "changes" existiert in "arg.comp.modes"
            -> Ist dies der Fall: Dann als nächstes prüfen, ob man die jeweilige
            Mode-Nummer in der ersten Spalte von arg.comp.modes.changes findet,
            was bedeutet, dass dieser Mode (dessen Nummer "ModeNr_akt_1" sich auf
            die initiale Modal-Analyse im bzw. vor dem ersten Adaptionsschritt bezieht)
            nun (oder eben schon seit einigen Schritten, egal!) eine neue Nummer 
            ModeNr_akt_i hat, die wiederum dann in der dritten Spalte von
            "arg.comp.modes.changes" zu finden ist!
            %}
            for i_Mode = 1:length(arg.comp.modes.(R_akt))
                % Vorarbeit 1: Mode-Nummer der aktuell betrachteten Eigenform
                %              bezogen auf die INITIALE Modal-Analyse (Schritt 1)
                %              auslesen -> ZUNÄCHST MIT VZ!
                ModeNr_akt_1_mit_VZ = arg.comp.modes.(R_akt)(i_Mode);
                % Vorarbeit 2: Mode-Nummer der aktuell betrachteten Eigenform
                %              bezogen auf die LETZTE Modal-Analyse (Schritt i)
                %              auslesen -> OHNE VZ!
                % -> Prüfen, ob es bisher Mode-Vertauschungen gab & wenn ja,
                %    ob dies den aktuellen Mode betrifft und wenn auch das
                %    zutrifft: Auswertung dieser Vertauschungsinformationen.
                % (I) Fall: Es gab BISHER KEINE derartigen Vertauschungen
                %           ODER sie betreffen den aktuellen Mode nicht.
                if isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_1_mit_VZ),arg.comp.modes.changes(:,1)))
                    % Dann entspricht die aktuelle Mode-Nummer aus dem initialen
                    % Adaptionsschritt 1 derjenigen im aktuellen Schritt i.
                    ModeNr_akt_i_ohne_VZ = abs(ModeNr_akt_1_mit_VZ);
                % (II) Fall: Es gab BEREITS MINDESTENS EINE derartige Vertauschung
                %            und der aktuell betrachtete Mode ist hiervon betroffen.
                else
                    % Dann die neue Nummer (des aktuellen Adaptionsschrittes i) entsprechend abspeichern
                    ModeNr_akt_i_ohne_VZ = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==abs(ModeNr_akt_1_mit_VZ),3); % kein abs()-Befehl notw., da in arg.comp.modes.changes nur Integer-Werte stehen!
                end
                
                % (A.1) Modaler Vorzeichenfaktor "VZ" (hier: Faktor 1 oder -1)
                % Dieser ergibt sich aus der Vorgabe der initialen Mode-Nummer
                VZ = ModeNr_akt_1_mit_VZ / abs(ModeNr_akt_1_mit_VZ);
                % Hinweis: "VZ" wird nach der Ermittlung von beta_n und
                % DELTA_S_a_n weiter unten dann zum "Vorzeichen- und
                % Korrelationsfaktor" alpha_n_von_k verrechnet!!!
                                
                % (A.2) Skalierungsfaktor des modalen "Vorzeichen-Faktors"
                % zur Korrektur möglicher EF-"Richtungswechsel" durch den
                % Eigenwertlöser zw. der aktuellen und initialen Eigenform
                % des aktuell betrachteten Modes
                SF = arg.comp.modes.SF(arg.info.nummer,abs(arg.comp.modes.unique(:))==abs(ModeNr_akt_1_mit_VZ)); % Die Werte werden in "caap_check_eigenmodes" wirklich bezogen auf arg.comp.modes.unique bezogen zugeordnet!
                
                % (B) Richtungsbezogener modaler Anteilfaktor 
                % (Das Vorzeichen wird später durch "abs"-Befehl ignoriert; Wert bezieht
                % sich immer auf AKTUELLE ModeNr., sprich bezogen auf die letzte Modal-Analyse)
                beta_n = beta_n_von_i_von_R_akt(arg,erg,i_bebenrichtung,ModeNr_akt_i_ohne_VZ);
                
                % (C) Modales Spektralbeschleunigungsinkrement ermitteln,
                % je nach Fall des mod. AMI-Verfahrens: mit konst. oder optimierten DELTA S_a_B^(i)
                % (bezieht sich auf AKTUELLE ModeNr., sprich bezogen auf die letzte Modal-Analyse)
                switch arg.info.procedure
                    case 'ami_c'
                        % Bei dem modifizierten AMI-Verfahren mit konstanten
                        % Spektralbeschleunigungsinkrementen des Bezugsmodes
                        % ergeben sich die modalen spektralen Schrittweiten
                        % immer aus dem benutzerseitig vorgegebenen (fixen)
                        % Grundwert für die Bezugseigenform "B"
                        % (1) Aktuelles (i-tes) maximales Spektralbeschleu-
                        %     nigungsinkrement für den aktuell betrachteten
                        %     sowie den Bezugs-Mode auslesen
                              DELTA_S_a_n_max = arg.comp.delta_s_a_n_max_i.(R_akt)(arg.info.nummer,i_Mode);
                              DELTA_S_a_B_primaer_max = arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1); % MUSS SICH IMMER AUF DEN BEZUGSMODE DER PRIMÄREN BEBENRICHTUNG BEZIEHEN! (Sonst würden im letzten AMI-Schritt nicht alle Moden in allen "Richtungs-Summen" ihre max. modale Spektralbeschl. erreichen!) 
                        % (2) Aktuellen (i-ten) intermodalen Skalierungsfaktor
                        %     für den aktuell betrachteten Mode bestimmen
                              lambda_n_von_i = DELTA_S_a_n_max / DELTA_S_a_B_primaer_max;
                              % Falls DELTA_S_a_B_max = 0 
                              % (Im Fall eines negativen Spektralinkrementes DELTA_S_a_n_max
                              %  werden ja alle modalen Inkremente künstlich auf 0 gesetzt!)
                              if isnan(lambda_n_von_i)
                                  lambda_n_von_i = 0;
                              end
                        % (3) Aktuelles (i-tes) modales Spektralbeschleuni-
                        %     gungsinkrement für den aktuell betrachteten
                        %     Mode über den festen Grundwert der Bezugs-
                        %     eigenform und den intermodalen Skalierungs-
                        %     faktor bestimmen
                              DELTA_S_a_n = lambda_n_von_i * arg.comp.delta_s_a_b;
                        % (4) Mithilfe dieses Spektralbeschleunigungsinkre-
                        %     ments den neuen Punkt (S_d_n_i|S_a_n_i) für
                        %     das modale Kapazitätsspektrum ermitteln und
                        %     entspr. abspeichern (rein informativ!!!)
                        %     (passiert bei "ami_o" später innerhalb von
                        %     "caap_analyze_pushover"!!!)
                        DELTA_S_d_n = DELTA_S_a_n / (arg.comp.omega_n_von_i.(R_akt)(arg.info.nummer,i_Mode))^2;
                        if arg.info.nummer == 1
                            arg.comp.s_a_n.(R_akt)(arg.info.nummer,i_Mode) = DELTA_S_a_n;
                            arg.comp.s_d_n.(R_akt)(arg.info.nummer,i_Mode) = DELTA_S_d_n;
                        else
                            arg.comp.s_a_n.(R_akt)(arg.info.nummer,i_Mode) = arg.comp.s_a_n.(R_akt)(arg.info.nummer-1,i_Mode) + DELTA_S_a_n;
                            arg.comp.s_d_n.(R_akt)(arg.info.nummer,i_Mode) = arg.comp.s_d_n.(R_akt)(arg.info.nummer-1,i_Mode) + DELTA_S_d_n;
                        end
                      case 'ami_o'
                            % -> Wert des maximalen Spektralinkrements
                            %    liegt bereits vor und muss lediglich
                            %    ausgelesen werden!
                            DELTA_S_a_n = arg.comp.delta_s_a_n_max_i.(R_akt)(arg.info.nummer,i_Mode);
                end
                
                % (D) Modaler "Vorzeichen- und Korrelationsfaktor" alpha_n_von_k
                % Frequenzen und modale effektive Dämpfungen des NUN RICHTUNGSABHÄNGIGEN
                % BEZUGSMODES sowie des aktuell betrachteten Modes zusammentragen
                f_n = [arg.comp.omega_n_von_i.(R_akt)(arg.info.nummer,1)/(2*pi),arg.comp.omega_n_von_i.(R_akt)(arg.info.nummer,i_Mode)/(2*pi)];
                xi_eff_n = [arg.comp.xi_n_eff.(R_akt)(arg.info.nummer,1),arg.comp.xi_n_eff.(R_akt)(arg.info.nummer,i_Mode)]/100; % in der cqc-Routine werden dimensionslose Dämpfungsmaße benötigt
                % rho-Matrix der Kreuzkorrelation dieser beiden Moden bestimmen
                rho_matrix = cqc(f_n,xi_eff_n);
                % Inkremente der Fundamentschübe des richtungsabhängigen Bezugsmodes
                % sowie des aktuell betrachteten Modes (bez. der aktuellen Bebenrichtung)
                % ermitteln
                % -> DELTA Fb_R_akt,B
                Meff_R_akt_B = (beta_n_von_i_von_R_akt(arg,erg,i_bebenrichtung,ModeNr_B_i_R_akt_ohne_VZ))^2;
                switch arg.info.procedure
                    case 'ami_c'
                        if arg.info.nummer == 1
                            DELTA_S_a_B = arg.comp.s_a_n.(R_akt)(arg.info.nummer,1); % aktueller, RICHTUNGSABHÄNGIGER Bezugsmode: DELTA aus dem 1. Wert und 0 (in diesem Fall) in der 1. Spalte von arg.comp.s_a_n.(R_akt) bestimmen!
                        else
                            DELTA_S_a_B = arg.comp.s_a_n.(R_akt)(arg.info.nummer,1) - arg.comp.s_a_n.(R_akt)(arg.info.nummer-1,1); % aktueller, RICHTUNGSABHÄNGIGER Bezugsmode: DELTA aus dem i-ten und (i-1)-ten Wert in der 1. Spalte von arg.comp.s_a_n.(R_akt) bestimmen!
                        end
                    case 'ami_o'
                        DELTA_S_a_B = arg.comp.delta_s_a_n_max_i.(R_akt)(arg.info.nummer,1); % aktueller, RICHTUNGSABHÄNGIGER Bezugsmode in der 1. Spalte von arg.comp.s_a_n.(R_akt)!
                end
                DELTA_Fb_R_akt_B = Meff_R_akt_B * DELTA_S_a_B;
                % -> DELTA Fb_R_akt_n
                DELTA_Fb_R_akt_n = beta_n^2 * DELTA_S_a_n;
                % Resultierendes Fundamentschubinkrement aus der CQC-Überlagerung
                % dieser beiden modalen Fundamentschubinkremente bestimmen
                DELTA_Fb_CQC_Bn = sqrt([DELTA_Fb_R_akt_B DELTA_Fb_R_akt_n] * rho_matrix * [DELTA_Fb_R_akt_B; DELTA_Fb_R_akt_n]);
                % Linearen Korrelationsfaktor für die Korrelation zwischen
                % diesen beiden Moden ermitteln
                korrelationsfaktor = (DELTA_Fb_CQC_Bn - 1.0 * DELTA_Fb_R_akt_B) / DELTA_Fb_R_akt_n;
                % Abfangen, dass der "korrelationsfaktor" nicht NaN ist,
                % auch wenn DELTA_Fb_R_akt_n = 0
                if isnan(korrelationsfaktor)
                    if i_Mode == 1 % => In der MAIN-Function wird mittlerweile auch bei "ami_o" geprüft, ob DELTA_S_a_B_max(i) in primärer Bebenrichtung etwa 0 ist und dann die Ber. abgebrochen!
                        % Im Fall des Bezugsmodes: Trotzdem 1 als
                        % Korrelationsfaktor ansetzen (muss ja von der
                        % Theorie her 1 sein, ist hier nur NaN bei einem
                        % Spektralinkrement von 0, dann macht aber die
                        % Skalierung mit 1 nichts kaputt)
                        korrelationsfaktor = 1;
                    else
                        % Bei einem Begleitmode: Korrelationsfaktor dann einfach mit 0 überschreiben...
                        korrelationsfaktor = 0;
                        % ... und eine entspr. Warnung ausgeben:
                        fprintf(2,[('\n ATTENTION: In the current step %d, the base shear increment\n'),...
                            ('of the %d. mode was 0, so the correlation factor would have been NaN.\n'),...
                            ('It has now been set to 0.\n'),...
                            ('-> Please check whether this is justifiable!\n')],arg.info.nummer,abs(arg.comp.modes.(R_akt)(i_Mode)));
                    end
                end
                % alpha_n_von_k ermitteln und in arg-Struktur abspeichern
                alpha_n_von_k = VZ * korrelationsfaktor;
                arg.comp.alpha_n_von_k.(R_akt)(arg.info.nummer,i_Mode) = alpha_n_von_k;
                
                % (E) Richtungsbezogenen PHI-Vektor der akt. Modalform ermitteln
                % (bezieht sich auf AKTUELLE ModeNr., sprich bezogen auf die letzte Modal-Analyse)
                % und dann den jew. RICHTUNGSBEZOGENEN MODALBEITRAG zum
                % Lastinkrementvektor in die F-Matrix "einstreuen"
                modal_erg = sub_get_mode(erg,arg.info.name_modal_old,ModeNr_akt_i_ohne_VZ);
                if ~ist_typ(modal_erg,'logical')
                    % Verformungen rausschreiben
                    % Translationen
                    v = cellfun(@str2num,modal_erg(:,6:8));
                    
                    % Schleife über alle Translationen
                    for i_komponente = 1:1:3
                        F(:,i_komponente,arg.comp.d_earthquake{2,i_bebenrichtung}) = ...
                            F(:,i_komponente,arg.comp.d_earthquake{2,i_bebenrichtung}) + ... % aus den bisherigen Modalbeiträgen
                            (alpha_n_von_k * SF) * (v(:,i_komponente) .* m_lok(:,i_komponente)) * abs(beta_n) * DELTA_S_a_n; % aus dem aktuellen Modalbeitrag; abs(beta_n), damit Lasten bei alpha = 1 immer in Richtung des Eigenvektors "zeigen"!
                        %{
                            Hinweis: Die Aufsummierung der
                            richtungsbezogenen Matrizen zu einer
                            resultierenden Matrix erfolgt nach Beendigung
                            der Mode- und der Richtungsschleife (und sogar
                            außerhalb des "ami_c"- bzw. "ami_o"-Cases) 
                            unmittelbar im Anschluss (s. u.)!
                        %}
                    end
                end
            end
        end
end

% Matrizen mit Knotenlasten in allen drei Wirkungsrichtungen (3 Spalten-
% vektoren) für alle drei potenziellen Bebenrichtungen (je eine Matrix,
% ggf. "0"-Matrix) gewichtet aufsummieren zu einer resultierenden Matrix
% Schleife über alle Bebenrichtungen
for i_bebenrichtung = 1:1:size(arg.comp.d_earthquake,2)
    F(:,:,4) = F(:,:,4) + ...
        F(:,:,arg.comp.d_earthquake{2,i_bebenrichtung}) * arg.comp.dir_factor(i_bebenrichtung);
end

% >>Neue Zwischenüberprüfung ab Schritt 2 bei "standard" und "ami_o"<<
if any(strcmp(arg.info.procedure,{'standard','ami_o'})) && arg.info.nummer > 1
    % Ist F_b_max^(i) = F_b_end^(i-1) + DELTA F_b_max(i) > F_b_max,Initialkurve?
    % => Dann konnte das System F_b_max^(1) offenbar nicht aufnehmen, sodass
    %    nun F_b_max,Initialkurve < F_b_max^(1) ist
    % Vorarbeit:
    F_b_end_von_i_minus_1 = arg.comp.pushoverkurve.(['segment_',num2str(arg.info.nummer-1)])(end,2);
    DELTA_F_b_max_von_i = sum(F(:,arg.comp.d_earthquake{2,1},4));
    F_b_max_Initialkurve = arg.comp.pushoverkurve.initial(end,2);
    % Überprüfung:
    if F_b_end_von_i_minus_1 + DELTA_F_b_max_von_i > F_b_max_Initialkurve
        % WENN JA: F-Matrix so "herunterskalieren", dass nur der offenbar
        % vom System maximal aufnehmbare Fundamentschub von F_b_max_Initialkurve
        % angesteuert wird, aber nicht mehr!
        % (Sonst verlieren die optimierten Pushover-Schrittzahlen ihren Bezug
        %  und man verliert Zeit bei der Pushover-Ber. in SAP2000, weil er
        %  versucht weiterzukommen, es aber nicht schafft!)
        F = F * ((F_b_max_Initialkurve-F_b_end_von_i_minus_1)/(DELTA_F_b_max_von_i));
        % Und eine entspr. Warnung ausgeben:
        fprintf(2,[('\n ATTENTION: In the current step %d, the total base shear increment\n'),...
            ('together with the last available base shear would have led to the final value\n'),...
            ('from the first MAX calculation being exceeded. In other words:\n'),...
            ('Presumably the maximum was not reached there and the value to be controlled now\n'),...
            ('would exceed the recordable maximum again, so that the increment is scaled down\n'),...
            ('accordingly to the old MAX value as the new target.\n'),...
            ('-> If this were to be the last AMI step, this would be critical, because the\n'),...
            ('   targeted maximum would not have been reached!\n\n')],arg.info.nummer);
    end
end
% << Ende: Zwischenüberprüfung

% FUNKTIONSAUSGABE:
% NUR die resultierende Gesamtmatrix infolge der gewichteten Überlagerung
% der einzelnen Bebenrichtungsanteile
arg.comp.f_matrix_akt = F(:,:,4);

%  -> Im Falle des "AMI_k"-Verfahrens außerdem:
    % Die korrigierte (endgültige) Lastverteilung des aktuellen Schrittes 
    % archivieren (für potenzielle nachträgliche Analyse der Lastverteilungsentwicklung)
    if strcmp(arg.info.procedure,'ami_c')
        % Bei diesem Verfahren liegt hier ja bereits die adaptionsschritt-
        % bezogene endgültige Lastverteilung vor: 
        arg.comp.f_matrix(:,:,arg.info.nummer) = arg.comp.f_matrix_akt;
        % (Beim AMI-Verf. mit optimierten Inkrementen findet die Archivierung
        %  natürlich erst nach der jew. Korrektur der Lastverteilung statt!)
    end
end



%% Sub-Funktionen

% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Knotenmassen ermitteln
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function m_lok = sub_get_massen(erg,arg)
% Gesamtknotenanzahl ermitteln (aller System- und reinen FE-Knoten)
anz_Knot_ges = size(erg.AssembledJointMasses.Werte,1)-3; % die letzten drei Zeilen enthalten die Summen bezüglich der drei kartesischen Koordinatenrichtungen
% Alle m_i vorbelegen
m_lok = zeros([anz_Knot_ges,3]);
% Schleife über alle Knoten
for i_Knoten = 1:anz_Knot_ges
    % -> Im Fall "arg.comp.push_load_ref" == 'joints' Knotenmasse IMMER speichern
    % -> Im Fall "arg.comp.push_load_ref" == 'frames' Knotenmasse NUR speichern, wenn der Knoten einem Balkenobjekt zugewiesen wurde
    if strcmp(arg.comp.push_load_ref,'joints') || ~isempty(arg.comp.joint_lastverteilung.Werte{i_Knoten,5}) && isempty(strfind(arg.comp.joint_lastverteilung.Werte{i_Knoten,1},'link'))
        % Knotenmasse abgreifen und ablegen
        m_lok(i_Knoten,1:3) = cellfun(@str2num,erg.AssembledJointMasses.Werte(i_Knoten,3:5));
    end % Ende Prüfung, ob Last-Referenz Systemknoten sind oder (bei 'frame elements') ob Knoten einem Balken zugewiesen wurde
end % Ende For-Schleife Knoten
end % Ende sub_get_massen


% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Richtungsbezogenen PHI-Vektor der akt. Modalform ermitteln
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function modal_erg = sub_get_mode(erg,name_modal_old,mode_nr)
index = find(cellfun(@str2num,erg.JointDisplacements.Werte.(name_modal_old)(:,5)) == mode_nr);
if isempty(index)
    fprintf(2,'Mode %s does not exist in the LoadCase "%s" and is ignored!\n', num2str(mode_nr),name_modal_old);
    modal_erg = false;
else
    modal_erg = erg.JointDisplacements.Werte.(name_modal_old)(index,:);
end
end


% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Im Falle einer modifizierten AMI-Berechnung:
% Maximale modale Spektralbeschleunigungsinkremente aller in
% "arg.comp.modes.gesamt" hinterlegten Moden für den aktuellen
% Adaptionsschritt (i = arg.info.nummer) ermitteln
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function arg = sub_DELTA_S_a_n_max(arg,erg)
% >> Vorarbeit/Zwischenschritt:
% Ab dem zweiten Adaptionsschritt EINMAL FÜR ALLE MODEN
% "erg.ModalParticipationFactors" nach den modalen Lastfällen sortieren
if arg.info.nummer ~= 1
    erg = caap_sort_field(erg,'ModalParticipationFactors','OutputCase'); % in erg.ModalParticipationFactors separate Cell-Arrays für die versch. modalen LoadCases generieren für direkten Zugriff auf die letzte Modalanalyse
end

% Übergeordnete Schleife über alle betrachteten Bebenrichtungen
for i_Richtg = 1:size(arg.comp.d_earthquake,2)
    % -> Aktuelle Bebenrichtung auslesen (für einfacheren späteren Zugriff)
    richtung_akt = arg.comp.d_earthquake{1,i_Richtg};
    % Untergeordnete Schleife über alle in der aktuellen Richtung zu
    % berücksichtigenden Moden
    % -> Nummern beziehen sich dabei IMMER auf die INITIALE Modal-Analyse
    for i_Mode = 1:length(arg.comp.modes.(richtung_akt))
        
        % >> Zwischenschritt: Mode-Nr. auslesen
        % Aktuelle Mode-Nr. auslesen (mit "abs(...)", da das richtungsbezogene VZ hier keine Rolle spielt und die "echte" (VZ-freie) Nummer nachfolgend bei der Mode-Suche gebraucht wird)
        ModeNr_akt_initial = abs(arg.comp.modes.(richtung_akt)(1,i_Mode));
        % Nun prüfen, ob es eine Vertauschung dieses Modes im aktuellen Adaptionsschritt
        % gibt oder in einem bisherigen Schritt gab:
        %{
        -> Erstmal prüfen, ob es überhaupt irgendwelche Vertauschungen gab/gibt,
           wenn ja: Feld "changes" existiert in "arg.comp.modes"
        -> Ist dies der Fall: Dann als nächstes prüfen, ob man die jeweilige
           Mode-Nummer in der ersten Spalte von arg.comp.modes.changes findet,
           was bedeutet, dass dieser Mode (dessen Nummer "ModeNr_akt_1" sich auf
           die initiale Modal-Analyse im bzw. vor dem ersten Adaptionsschritt bezieht)
           nun (oder eben schon seit einigen Schritten, egal!) eine neue Nummer 
           ModeNr_akt_i hat, die wiederum dann in der dritten Spalte von
           "arg.comp.modes.changes" zu finden ist!
        %}
        % (I) Fall: Es gab BISHER KEINE derartigen Vertauschungen ODER
        %           sie betreffen den aktuellen Mode nicht.
        if isempty(arg.comp.modes.changes) || (~isempty(arg.comp.modes.changes) && ~ismember(abs(ModeNr_akt_initial),arg.comp.modes.changes(:,1)))
            % Dann ist die aktuelle Mode-Nummer im Adaptionsschritt 1
            % sowie im aktuellen Adaptionsschritt i identisch!
            ModeNr_akt_1 = ModeNr_akt_initial;
            ModeNr_akt_i = ModeNr_akt_initial;
            % (II) Fall: Es gab BEREITS MINDESTENS EINE derartige Vertauschung
            %            und der aktuell betrachtete Mode ist hiervon betroffen.
        else
            % Dann die bisherie Nummer als "ModeNr_akt_1" abspeichern
            % (heißt: ModeNr des "akt" Modes im ERSTEN Adaptionsschritt)
            ModeNr_akt_1 = ModeNr_akt_initial;
            % Und nun die neue/aktuelle Mode-Nummer als "ModeNr_akt_i" abspeichern
            % (heißt: ModeNr des "akt" Modes im AKTUELLEN "i-ten" Adaptionsschritt)
            ModeNr_akt_i = arg.comp.modes.changes(arg.comp.modes.changes(:,1)==abs(ModeNr_akt_1),3);
        end
        
        % >> Ermittlung des effektiven Fließpunktes (S_d_n_y_i|S_a_n_y_i)
        % und Berechnung von omega_n_eff sowie xi_n_eff
        % (je nach Anzahl der bisherigen Punkte im jew. modalen Kapazitätsspektrum)
        if arg.info.nummer == 1
            % Wenn "arg.info.nummer" = 1 ist, befindet man sich vor dem
            % ersten richtigen Pushover- bzw. Adaptionsschritt unmittelbar nach
            % der Initialberechnung (nur Vertikallasten und erste Modal-Analyse)
            T_Mode = str2double(erg.ModalParticipationFactors.Werte{strcmp(erg.ModalParticipationFactors.Werte(:,3),[num2str(abs(ModeNr_akt_i)),'.']),4}); % Eigenperiode des akt. Modes [s] (es gibt bisher nur einen modalen Lastfall!!!)
            arg.comp.omega_n_von_i.(richtung_akt)(1,i_Mode) = (2*pi) / T_Mode; % Aktuelle (d. h. auf Basis der akt. tangentialen Steifigkeit basierende) Eigenkreisfrequenz (wird später in "caap_analyze_pushover" für die Pseudospektren-Transformationsgleichung benötigt und daher in arg gespeichert)
            arg.comp.xi_n_eff.(richtung_akt)(1,i_Mode) = arg.comp.xi_0; % [%]!!!
        elseif arg.info.nummer <= 3 % bis dahin gilt nämlich: length(arg.comp.s_d_n(:,i_Mode)) < 3 (und somit einschl. 0-Pkt max. 3) und dann braucht man keine zweisegmentige Linearisierung ermitteln
            % Bei nur einem oder zwei Punkten (zusätzlich zum KS-Ursprung) im modalen Kapazitätsspektrum
            % ist der effektive Fließpunkt der Punkt (S_d_n_1|S_a_n_1) und somit omega_n_eff = omega_n_1
            % sowie xi_n_eff = xi_0 = 5%!
            arg.comp.s_d_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.s_d_n.(richtung_akt)(1,i_Mode); % 1. Punkt, also 1. Zeile in arg.comp.s_d_n
            arg.comp.s_a_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.s_a_n.(richtung_akt)(1,i_Mode); % 1. Punkt, also 1. Zeile in arg.comp.s_a_n
            % -> Zwischenschritt: omega_n_von_1 ermitteln
            T_Mode = str2double(erg.ModalParticipationFactors.Werte.(arg.info.name_modal_old)...
                {strcmp(erg.ModalParticipationFactors.Werte.(arg.info.name_modal_old)(:,3),[num2str(abs(ModeNr_akt_i)),'.']),4}); % Eigenperiode des akt. Modes [s] s (erster modaler Lastfall: "MODAL")
            arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode) = (2*pi) / T_Mode; % Aktuelle (d. h. auf Basis der akt. tangentialen Steifigkeit basierende) Eigenkreisfrequenz des akt. Modes [rad/s] (wird später in "caap_analyze_pushover" für die Pseudospektren-Transformationsgleichung benötigt und daher in arg gespeichert)
            arg.comp.xi_n_eff.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.xi_0; % [%]!!!
        else
            % Ansonsten: "Ganz normale" Ermittlung von (S_d_n_y_i|S_a_n_y_i) &
            % xi_n_eff anhand der zweisegmentigen Linearisierung
            % des Kapazitätsspektrums bis zum letzten Punkt desselbigen
            % (1) Ermittlung des effektiven Fließpunktes (S_d_n_y_i|S_a_n_y_i)
            %     auf Basis der zweisegmentigen Linearisierung des bisherigen
            %     modalen Kapazitätsspektrums (bis zum letzten Punkt) sowie der
            %     dazu korrespondierenden Hystereseenergie E_D (als Flächen-
            %     inhalt des aus der zweisegmentigen Linearisierung
            %     resultierenden Parallelogramms)
            % S_a_n_von_i_minus_1 und S_d_n_von_i_minus_1 auslesen
            % Hinweis: Man ist hier durch den obigen "elseif"-Fall
            % mindestens im Schritt 4 (sprich: es gibt immer einen
            % Vorgänger "arg.info.nummer-1")
            S_a_n_von_i_minus_1 = arg.comp.s_a_n.(richtung_akt)(end,i_Mode); % letzter Punkt korresp. zum Lastzustand i-1, da keine Vorbelegung stattfinden kann (weil man ja vorher nicht weiß, wie viele Lastzustände es geben wird); funktioniert sogar bei Wechsel von "ami_o" zu "ami_c" bei negativen Spektralbeschl.-inkr., da hier zwar schon ein S_a_n_max-Wert "zu viel" (vom nächsten, erstmal zurückgestellten Schritt) vorliegt, aber kein S_a_n-Wert!
            S_d_n_von_i_minus_1 = arg.comp.s_d_n.(richtung_akt)(end,i_Mode); % letzter Punkt korresp. zum Lastzustand i-1, da keine Vorbelegung stattfinden kann (weil man ja vorher nicht weiß, wie viele Lastzustände es geben wird); funktioniert sogar bei Wechsel von "ami_o" zu "ami_c" bei negativen Spektralbeschl.-inkr., da hier zwar schon ein S_a_n_max-Wert "zu viel" (vom nächsten, erstmal zurückgestellten Schritt) vorliegt, aber kein S_a_n-Wert!
            % << Zwischenschritt: Sicherstellen, dass man den
            % linear-elastischen Bereich verlassen hat, da sonst die
            % Ermittlung von (S_d_n_y_i|S_a_n_y_i) durch die
            % zweisegmentige Linearisierung des Spektrums i. Allg.
            % ziemlichen Quatsch liefern kann:
            if gleich((S_a_n_von_i_minus_1 / S_d_n_von_i_minus_1),(arg.comp.s_a_n.(richtung_akt)(1,i_Mode)/arg.comp.s_d_n.(richtung_akt)(1,i_Mode)),0.01)
                % Fall: Abweichung zw. (S_a_n_von_i_minus_1 / S_d_n_von_i_minus_1)
                % und dem S_a/S_d-Verhältnis für den allerersten Punkt des modalen Kapazitätsspektrums ist kleiner als 1%
                % -> Dann (S_d_n_y_i|S_a_n_y_i) ermitteln, wie im Fall
                % von weniger als drei Spektralwerten (s. o.)!
                arg.comp.s_d_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.s_d_n.(richtung_akt)(1,i_Mode); % 1. Punkt, also 1. Zeile in arg.comp.s_d_n
                arg.comp.s_a_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.s_a_n.(richtung_akt)(1,i_Mode); % 1. Punkt, also 1. Zeile in arg.comp.s_a_n
                % -> Die Hystereseenergie ist demzufolge dann = 0
                E_D = 0;
                % -> Außerdem: omega_n_von_i bestimmen (wird später
                % gebraucht für die Ermittlung von DELTA_S_d_n_i)
                T_Mode = str2double(erg.ModalParticipationFactors.Werte.(arg.info.name_modal_old)...
                    {strcmp(erg.ModalParticipationFactors.Werte.(arg.info.name_modal_old)(:,3),[num2str(abs(ModeNr_akt_i)),'.']),4}); % Eigenperiode des akt. Modes [s] s (Suffix (Index) des modalen Lastfalls = Adaptionsschritt-Nummer!)
                arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode) = (2*pi) / T_Mode; % Aktuelle (d. h. auf Basis der akt. tangentialen Steifigkeit basierende) Eigenkreisfrequenz des akt. Modes [rad/s] (wird später in "caap_analyze_pushover" für die Pseudospektren-Transformationsgleichung benötigt und daher in arg gespeichert)
            else
                % Fall: Man ist nicht mehr auf dem linear-elastischen
                % Anfangsast des modalen Kapazitätsspektrums
                % -> Jetzt WIRKLICH "ganz normale" Ermittlung von
                % (S_d_n_y_i|S_a_n_y_i) anhand der zweisegmentigen
                % Linearisierung des modalen Kapazitätsspektrums bis zum
                % letzten Punkt desselbigen
                % A_vorh berechnen
                A_vorh = trapz([0; arg.comp.s_d_n.(richtung_akt)(:,i_Mode)],[0; arg.comp.s_a_n.(richtung_akt)(:,i_Mode)]);
                % omega_n_von_i auslesen
                T_Mode = str2double(erg.ModalParticipationFactors.Werte.(arg.info.name_modal_old)...
                    {strcmp(erg.ModalParticipationFactors.Werte.(arg.info.name_modal_old)(:,3),[num2str(abs(ModeNr_akt_i)),'.']),4}); % Eigenperiode des akt. Modes [s] s (Suffix (Index) des modalen Lastfalls = Adaptionsschritt-Nummer!)
                arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode) = (2*pi) / T_Mode; % Aktuelle (d. h. auf Basis der akt. tangentialen Steifigkeit basierende) Eigenkreisfrequenz des akt. Modes [rad/s] (wird später in "caap_analyze_pushover" für die Pseudospektren-Transformationsgleichung benötigt und daher in arg gespeichert)
                % S_a_n_y_i berechnen
                arg.comp.s_a_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) = (2*A_vorh - (S_a_n_von_i_minus_1/(arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode)))^2) ...
                                                                                            / (S_d_n_von_i_minus_1 - (S_a_n_von_i_minus_1/(arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode))^2));
                % S_d_n_y_i berechnen
                arg.comp.s_d_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) = S_d_n_von_i_minus_1 - (S_a_n_von_i_minus_1 - arg.comp.s_a_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode)) ...
                                                                                            / ((arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode))^2);
                % -> Die Hystereseenergie ist nun nicht mehr = 0
                E_D = 4 * (arg.comp.s_a_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) * S_d_n_von_i_minus_1 - arg.comp.s_d_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode) * S_a_n_von_i_minus_1); % (in Anlehnung an ATC40 (1996), S. 8-15)
            end
            % >> (Ende: Zwischenschritt)
            % (2) Ermittlung der dazu korrespondierenden effektiven Dämpfung xi_n_eff
            % Maximale Dehnungsenergie
            E_So = (S_d_n_von_i_minus_1 * S_a_n_von_i_minus_1) / 2; % (in Anlehnung an ATC40 (1996), S. 8-15)
            % Äquivalentes viskoses Dämpfungsmaß
            xi_eq = 1/(4*pi) * E_D/E_So; % [-] (vgl. ATC40 (1996), Gl. 8-5a)
            % Korrekturfaktor Kappa(xi_eq) nach ATC40 (1996), Tabelle 8-1
            % -----------------------------------------------------------------------------------------------------------------------------------
            % Zwischenschritt: Prüfung, ob Hysterese-Verhalten nach ATC40 (1996), Tabelle 8-4 korrekt angegeben wurde
            % -> Vorarbeit: Definition zulässiger Angaben
            HB_zulaessig = {'A','B','C'};
            % -> Erstmal prüfen, ob überhaupt eine Angabe vorliegt
            if isfield(arg.comp,'hb')
                % -> Falls klein geschrieben: in Großbuchstaben überführen
                HB = upper(arg.comp.hb);
                % -> Dann prüfen, ob diese die zulässige Form aufweist
                if ~ismember(HB,HB_zulaessig)
                    % Fall: Angabe weist nicht die gewünschte/erf. Form auf
                    error('Information regarding the hysteresis type to be considered cannot be interpreted!')
                end
            else
                % -> Ohne Richtungsangabe kann man nichts machen!
                error('No hysteresis type to be considered was specified!')
            end
            % --(Ende: Zwischenschritt)----------------------------------------------------------------------------------------------------------
            % Vorarbeit: Notwendige Werte zusammenstellen
            S_d_y = arg.comp.s_d_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode);
            S_a_y = arg.comp.s_a_n_y_i.(richtung_akt)(arg.info.nummer,i_Mode);
            % switch/case-Untersuchung, je nach Hystereseverhalten (vgl. ATC40 (1996), Tab. 8-1)
            switch HB
                case 'A' % stabile Hystereseschleifen (hohe Energiedissipation)
                    if xi_eq <= 0.1625
                        Kappa = 1.0;
                    else
                        Kappa = 1.13 - 0.51 * ((S_a_y * S_d_n_von_i_minus_1 - S_d_y * S_a_n_von_i_minus_1) / (S_a_n_von_i_minus_1 * S_d_n_von_i_minus_1));
                    end
                case 'B' % relativ gering eingeschnürte Hystereseschleifen
                    if xi_eq <= 0.25
                        Kappa = 0.67;
                    else
                        Kappa = 0.845 - 0.446 * ((S_a_y * S_d_n_von_i_minus_1 - S_d_y * S_a_n_von_i_minus_1) / (S_a_n_von_i_minus_1 * S_d_n_von_i_minus_1));
                    end
                case 'C' % stark eingeschnürte Hystereseschleifen
                    Kappa = 0.33;
            end
            % Damit ergibt sich das effektive (Gesamt-)Dämpfungsmaß zu
            arg.comp.xi_n_eff.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.xi_0 + Kappa * xi_eq*100; % [%]!!! (vgl. ATC40 (1996), Gl. 8-8)
        end
        
        % >> Bestimmung der RICHTUNGSBEZOGENEN maximalen modalen
        % Spektralbeschleunigung S_a_n_max_i
        % (für den aktuellen Adaptionsschritt i) in Abhängigkeit des mit
        % xi_n_eff gedämpften elastischen Antwortspektrums
        % (0) Vorarbeit: i_Mode & richtung_akt an arg-Struktur übergeben, 
        %     um in "caap_el_accel_response_spectrum" die richtige modale 
        %     (eff.) Dämpfung auslesen zu können
        arg.i_Mode = i_Mode;
        arg.richtung_akt = richtung_akt;
        % (1) Prüfung, ob horizontales oder vertikales Beben angesetzt werden muss
        switch richtung_akt
            % -> Horizontal?
            case {'X','Y'}
                % arg.rs.richtung entsprechend belegen
                arg.rs.richtung = 'horizontal';
            % -> Vertikal?
            case 'Z'
                % arg.rs.richtung entsprechend belegen
                arg.rs.richtung = 'vertikal';
        end
        % (2) Mit xi_eff gedämpftes elastisches Antwortspektrum aufbauen
        arg = caap_el_accel_response_spectrum(arg);
        % (3) Nachbereitung: i_Mode & richtung_akt wieder aus arg-Struktur streichen
        % (Beide Felder wurden nur kurzzeitig gebraucht, um an
        % "caap_el_accel_response_spectrum" nur "arg" übergeben zu müssen!)
        arg = rmfield(arg,'i_Mode');
        arg = rmfield(arg,'richtung_akt');
        % (4) Transformation des gedämpften elastischen Antwortspektrums
        % Abszissentransformation des Antwortspektrums
        % Spektralbeschleunigungen (nur umspeichern)
        if strcmp(arg.rs.richtung,'horizontal')
            % Spektralbeschleunigungen des horizontalen Antwortspektrums
            RS_S_a_n_red = arg.rs.s_a_horizontal;
        else
            % Spektralbeschleunigungen des vertikalen Antwortspektrums
            RS_S_a_n_red = arg.rs.s_a_vertikal;
        end
        % Spektralverschiebungen aus den Eigenperioden T ermitteln
        RS_S_d_n_red = RS_S_a_n_red ./ (2*pi ./ arg.rs.t).^2; % Spektralverschiebungen des Antwortspektrums (via Transformation der Eigenperiodenwerte T_i)
        % (5) S_a_n_max_i als Schnittpunkt zwischen Antwortspektrum und der Geraden vom letzten Spektralpunkt (i-1) mit der Steigung omega_n^2 bestimmen
        % Flagge, dass ein Schnittpunkt gefunden wurde, hängt erstmal
        % auf Halbmast
        flag_SP = 0;
        if arg.info.nummer == 1
            % Startpunkt (0|0) temporär als ersten Punkt des Kapazitätsspektrums
            % definieren (wird am Ende des ersten Adaptionsschrittes dann mit
            % dem ersten "echten" spektralen Punkt überschrieben)
            arg.comp.s_d_n.(richtung_akt)(1,:) = zeros(1,length(arg.comp.modes.(richtung_akt)));
            arg.comp.s_a_n.(richtung_akt)(1,:) = zeros(1,length(arg.comp.modes.(richtung_akt)));
        end
        % Schleife über alle "Teilstücke" ("section") des
        % transformierten Antwortspektrums
        i_section_RS = 1; % Startwert

        % Vorbelegung
        S_a_max_neu = [];
        
        while ~flag_SP && i_section_RS <= size(RS_S_a_n_red,2)-1 % (-1, da ein Teilstück weniger als Punkte)
            %{
                  Mathematisches Problem (1. Index: "Geraden-Nummer", mit g1 = Teilstück des Antwort- und g2 = Teilstück des Kapazitätsspektrums; 2. Index: Komponente):
                  s11 + f1 * r11 = s21 + f2 * r21 (Zeile der Spektralverschiebungen, "x-Achse")
                  s12 + f1 * r12 = s22 + f2 * r22 (Zeile der Spektralbeschleunigungen, "y-Achse")
            %}
            % Parameter der zwei Geradengleichungen ermitteln
            % a) Spektralverschiebungen - Antwortspektrum
            s11 = RS_S_d_n_red(i_section_RS); % Ortsvektor-Komponente
            r11 = RS_S_d_n_red(i_section_RS + 1) - RS_S_d_n_red(i_section_RS); % Richtungsvektor-Komponente
            % b) Spektralbeschleunigungen - Antwortspektrum
            s12 = RS_S_a_n_red(i_section_RS); % Ortsvektor-Komponente
            r12 = RS_S_a_n_red(i_section_RS + 1) - RS_S_a_n_red(i_section_RS);
            % c) Spektralverschiebungen - Kapazitätsspektrum und
            % d) Spektralbeschleunigungen - Kapazitätsspektrum
            s21 = arg.comp.s_d_n.(richtung_akt)(end,i_Mode); % Ortsvektor-Komponente
            r21 = arg.comp.s_d_n.(richtung_akt)(end,i_Mode) + 1; % Richtungsvektor-Komponente: letzte bekannte Spektralverschiebung + Einheitsinkrement
            s22 = arg.comp.s_a_n.(richtung_akt)(end,i_Mode); % Ortsvektor-Komponente
            r22 = arg.comp.s_a_n.(richtung_akt)(end,i_Mode) + (arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode))^2 * 1; % Richtungsvektor-Komponente: letzte bekannte Spektralbeschleunigung + Einheitsverschiebungsinkrement mal tangentiale Steigung omega_n_von_i^2
            % Theoretischen Schnittpunkt der zunächst unendlich langen Geraden
            % ermitteln
            vec_f = 1 / (-r11*r22 + r12*r21) * [-r22 r21; -r12 r11] * [(s21 -s11); (s22 -s12)];
            % Prüfen, ob der Skalierungsfaktor des Antwortspektrum-Segments
            % zwischen 0 und 1 liegt und der Skalierungsfaktor des
            % verlängerten modalen Kapazitätsspektrums größer gleich 0 ist
            % (dann ist der theoretische auch ein praktischer Schnittpunkt)
            if 0 <= vec_f(1) && vec_f(1) <= 1 && 0 <= vec_f(2)
                % Wenn ja -> Es wurde ein tatsächlicher Schnittpunkt innerhalb der beiden
                % endlichen Teilstücke gefunden:
                % Dann muss noch ausgeschlossen werden, dass es sich dabei um
                % den Punkt (0|0) handelt:
                % -> (Theor.) Performance Punkt auswerten
                S_d_max_neu = s11 + vec_f(1) * r11;
                S_a_max_neu = s12 + vec_f(1) * r12;
                % Ursprung (0|0) des A-D-Diagramms ausschließen
                if ~(S_d_max_neu == 0 && S_a_max_neu == 0)
                    % "Modalen Performance Punkt" gefunden
                    % -> Schleife abbrechen!
                    flag_SP = 1; % Schnittpunkt gefunden!
                end
                % Alternativ prüfen, ob zwar der Skalierungsfaktor des Antwortspektrum-Segments
                % zwischen 0 und 1 liegt, ABER der Skalierungsfaktor des
                % verlängerten modalen Kapazitätsspektrums negativ ist
            elseif 0 <= vec_f(1) && vec_f(1) <= 1 && vec_f(2) < 0
                % Wenn das der Fall ist, wäre S_a_n_max kleiner als der
                % letzte S_a_n-Wert, sprich: Man wäre sogar mit dem
                % letzten Inkrement schon zu weit gelaufen und müsste
                % jetzt wieder "rückwärts laufen"!
                S_a_max_fail = s12 + vec_f(1) * r12;
                % Nun prüfen, ob die Punkte aber vielleicht annähernd
                % identisch sind (dann kann man einfach aufhören)
                    % Kurz die Spektralbeschleunigung des letzten Punktes
                    % auslesen
                    S_a_n_vorh_i_minus_1 = arg.comp.s_a_n.(richtung_akt)(end,i_Mode);
                    % Auf Ähnlichkeit prüfen
                    if gleich(S_a_max_fail,S_a_n_vorh_i_minus_1,0.01)
                        % Dann nehmen wir als S_a_max_neu einfach
                        % S_a_n_vorh_i_minus_1, um statt eines negativen
                        % DELTAs einfach ein DELTA von 0 zu haben
                        S_a_max_neu = S_a_n_vorh_i_minus_1;
                        % "Modalen Performance Punkt" gefunden
                        % -> Schleife abbrechen!
                        flag_SP = 1; % Schnittpunkt gefunden!
                    else
                        % -> Dann wird die Berechnung weitergeführt, in dem die
                        %    Schrittweite dieses Modalbeitrags auf Null gesetzt wird
                        %    für den nächsten Schritt.
                        %    Allerdings gibt es eine Warnung für den Benutzer, die
                        %    ihm die Möglichkeit gibt, zu entscheiden, ob ihm
                        %    dieses "übers Ziel hinausschießen" zu groß war. Dann
                        %    könnte er die Berechnung mit einem kleineren
                        %    DELTA_S_a_B wiederholen!
                         fprintf(2,['\n ATTENTION: In the last step %d, the intersection point for \n',...
                            'determining S_a_n_max for the mode %d with %d m/s² was still below the \n',...
                            'last available spectral value of %d m/s².\n',...
                            '-> If in doubt, please repeat the calculation with smaller DELTA S_a_B increment!\n'],arg.info.nummer,abs(arg.comp.modes.(richtung_akt)(i_Mode)),S_a_max_fail,arg.comp.s_a_n.(richtung_akt)(end,i_Mode));
                        flag_SP = 1; % Schnittpunkt mehr oder weniger gefunden!
                        S_a_max_neu = S_a_n_vorh_i_minus_1;
                    end
            end
            % Schleifenzähler ('i_section_RS') um 1 erhöhen und weiter gehts
            % mit dem nächsten RS-Teilstück
            i_section_RS = i_section_RS + 1;
        end
        % << Kleine Zwischenüberprüfung, ob ein Schnittpunkt gefunden wurde ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if isempty(S_a_max_neu)
            % Dann KANN und SOLLTE der Benutzer darüber informiert werden
            % und ihm durch plot des aktuellen Antwortspektrums mit modalem
            % Kapazitätsspektrum die Möglichkeit gegeben werden, nachzuvoll-
            % ziehen, ob es vlt. doch einen Schnittpunkt gibt und den dann
            % eingeben können; oder halt die Berechnung abzubrechen (oder
            % whatever!!!).
            % 1) Plot des Antwortspektrums und des modalen Kapazitätsspektrums
            plot(RS_S_d_n_red,RS_S_a_n_red,'-o')
            grid on
            hold on
            plot(arg.comp.s_d_n.(richtung_akt)(:,i_Mode),arg.comp.s_a_n.(richtung_akt)(:,i_Mode),'-*','color','red')
            plot([arg.comp.s_d_n.(richtung_akt)(end,i_Mode),(arg.comp.s_d_n.(richtung_akt)(end,i_Mode)+1)],...
                 [arg.comp.s_a_n.(richtung_akt)(end,i_Mode),(arg.comp.s_a_n.(richtung_akt)(end,i_Mode) + (arg.comp.omega_n_von_i.(richtung_akt)(arg.info.nummer,i_Mode))^2 * 1)])
            % "tic-toc"-Beziehung aufbauen
            t_local = tic;
            % Und ggf. eine kurze (informative)
            % Mail rausschicken
            if isfield(arg.info,'mail')
                % Inhalt der Mail schreiben
                arg.info.mail.content = sprintf(['ATTENTION:\n',...
                    'For the current calculation in step ',num2str(arg.info.nummer),' the CAAP tool\n',...
                    'requires a user-input due to a failed determination of S_a_n_max!']);
                % Mail rausschicken
                send_automated_mail(arg.info.mail.mailadress,arg.info.mail.name,arg.info.mail.password,arg.info.mail.smtp_server,...
                    arg.info.mail.subject,arg.info.mail.content)
            end
            % While-Schleife, so lange, bis was eingetippt wurde, was sich in
            % eine Zahl (Skalar) überführen lässt
            flag_S_a_max_schaetzer = 0; % Noch keine verwertbare Eingabe
            while ~flag_S_a_max_schaetzer
                % Eingabe-Aufforderung - ggf. mit akustischer Warnung
                if arg.info.sound == 0.5 || arg.info.sound == 1
                    try
                        hupe('gong');
                    catch
                        disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                    end
                end
                % Eingabe-Aufforderung
                eingabestring = input(sprintf(['In the current step %d, no maximum spectral acceleration \n',...
                    'could be determined for mode %d (initial mode %d) in the %s direction.\n',...
                    'Please look at the figure and enter an approximate S_a_n_max value if necessary (otherwise: cancel calculation): '],arg.info.nummer,ModeNr_akt_i,ModeNr_akt_1,richtung_akt),'s');
                % Eingabe verarbeiten
                if ist_typ(str2double(eingabestring),'zahl')
                    % Super Eingabe!
                    flag_S_a_max_schaetzer = 1;
                    % S_a_max_neu entsprechend belegen
                    S_a_max_neu = str2double(eingabestring);
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
        % Ende: Zwischenüberprüfung >> ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

        %  S_a_n_max_i wird unter arg.comp.s_a_n_max_i(arg.info.nummer,i_Mode) abgespeichert
        arg.comp.s_a_n_max_i.(richtung_akt)(arg.info.nummer,i_Mode) = S_a_max_neu;
        
        % >> Bestimmung des maximalen modalen Spektralbeschleunigungsinkrements
        % DELTA_S_a_n_max_i
        % (je nachdem, ob man sich im allerersten Lastzustand (ohne Vorgänger)
        %  befindet oder in einem beliebigen späteren)
        if arg.info.nummer == 1 % Im ersten Schritt kein "Vorgänger" vorhanden
            % -> Dann ist DELTA_S_a_n_max_i = S_a_n_max_i
            arg.comp.delta_s_a_n_max_i.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.s_a_n_max_i.(richtung_akt)(arg.info.nummer,i_Mode);
        else % -> Im jedem weiteren Schritt die letzte Spektralbeschleunigung S_a_n_von_i_minus_1 subtrahieren
            arg.comp.delta_s_a_n_max_i.(richtung_akt)(arg.info.nummer,i_Mode) = arg.comp.s_a_n_max_i.(richtung_akt)(arg.info.nummer,i_Mode) - arg.comp.s_a_n.(richtung_akt)(arg.info.nummer-1,i_Mode);
        end
        
    end % Ende for i_Mode = 1:length(arg.comp.modes.(richtung_akt))
end % Ende for i_Richtg = 1:size(arg.comp.d_earthquake,2)
end % Ende sub_DELTA_S_a_n_max(arg,erg)


% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Im Falle einer modifizierten AMI-Berechnung:
% Modalen Anteilfaktor für jeden in der aktuellen Richtung zu
% berücksichtigenden Mode auslesen
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function beta_n = beta_n_von_i_von_R_akt(arg,erg,i_richtung,ModeNr_akt_i)
    % Modalen Anteilfaktor des aktuell betrachteten Modes auslesen 
    % Ermittlung des korresp. Zeilenindizes in "erg.ModalParticipationFactors.Werte"
    idzs_logical_richtiger_LF = strcmp(erg.ModalParticipationFactors.Werte(:,1),arg.info.name_modal_old);
    idzs_logical_richtiger_Mode = strcmp(erg.ModalParticipationFactors.Werte(:,3),[num2str(ModeNr_akt_i),'.']);
    i_zeile = find(idzs_logical_richtiger_LF & idzs_logical_richtiger_Mode);
    % Ermittlung des korresp. Spaltenindizes in "erg.ModalParticipationFactors.Werte"
    i_spalte = 4 + arg.comp.d_earthquake{2,i_richtung}; % bei arg.comp.d_earthquake{2,i_richtung} = 1 (X-Richtung) Spalte 5, bei 2 (Y-Richtung) Spalte 6 ...
    % Nun den gesuchten Anteilfaktor auslesen
    beta_n = str2double(erg.ModalParticipationFactors.Werte{i_zeile,i_spalte});
end % Ende beta_n = beta_n_von_i_von_R_akt(arg,erg,i_richtung,ModeNr_akt_i)


% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Im Falle einer modifizierten AMI-Berechnung, WENN NEGATIVE SPEKTRALBE-
% SCHLEUNIGUNGSINKREMENTE aufgetreten sind:
% Ein paar Sachen "aufbereiten"; hat nicht unbedingt alles mit Point Loads
% zu tun, aber ist an dieser Stelle am einfachsten zu regeln und die Not-
% wendigkeit ist nunmal im Zuge der Point Load-Ermittlung aufgefallen!!!
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function [arg,erg] = sub_edit_ami_o_zu_ami_c(arg)
% Lastfallnamen neu zuweisen
arg.info.name_modal_new = arg.info.name_modal_old;
arg.info.name_modal_old = strrep(arg.info.name_modal_old,num2str(arg.info.nummer+1),num2str(arg.info.nummer));
arg.info.name_pushover_new = arg.info.name_pushover_old;
arg.info.name_pushover_old = arg.info.name_pushover_before_old;
arg.info.name_pushover_before_old = strrep(arg.info.name_pushover_before_old,num2str(arg.info.nummer),num2str(arg.info.nummer-1));
% Relevante Ergebnisse neu auslesen & nach LoadCases sortieren
erg = caap_sort_field(arg.comp.erg.(['schritt_' num2str(max((arg.info.nummer-1),1))]),'JointDisplacements','OutputCase');
% An dieser Stelle sollte man kurz den letzten Teil der
% Gesamt-Pushoverkurve löschen (weil das hier am einfachsten
% geht)
arg.comp.pushoverkurve.gesamt = arg.comp.pushoverkurve.gesamt(1:(end-size(arg.comp.pushoverkurve.(['segment_',num2str(arg.info.nummer)]),1)),:);
end

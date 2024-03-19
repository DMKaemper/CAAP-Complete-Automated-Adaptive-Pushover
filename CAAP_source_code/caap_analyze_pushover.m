function [arg,modell] = caap_analyze_pushover(erg,arg,modell)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_analyze_pushover(erg,arg,modell)
%
%   Funktion zur Analyse der PushOver-Kurve
%
%   Analysiert die jeweils letzte "Max-Berechnung" im Hinblick auf die
%   mögliche Erfüllung des globalen sowie des lokalen Grenzkriteriums.
%   Sofern beide erfüllt sind, ist die kleinere Schrittnummer maßgebend!
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% Pushover-Kurve zusammenbasteln

% Ergebnisse sortieren
erg = caap_sort_field(erg,'BaseReactions','OutputCase');
erg = caap_sort_field(erg,'JointDisplacements','OutputCase');

% Kontrollknotenverschiebungen und Fundamentschübe (Beträge!) der aktuellen
% PushOver-Kurve in der betrachteten Richtung auslesen
[F_B,v_KK] = sub_get_F_B_and_v_KK(arg,erg);

% Aktuelle Pushover-Kurvendaten der MAX-Berechnung temporär
% zwischenspeichern für die Ermittlung der optimierten "min & max num
% states" der NÄCHSTEN MAX-Berechnung (im Schritt i+1)
arg.comp.pushoverkurvendaten_maxber_tmp = [F_B,v_KK];

% >> Kurze Zwischenüberprüfung:
%    - Gibt es weniger als 2 Punkte im aktuellen Segment der Pushover-Kurve?
%       -> Dann wäre die Überprüfung des globalen und lokalen Grenzkriteriums
%          nicht möglich!
%    - UND handelt es sich dabei um KEINE "0"-Berechnung eines "ami_o"-Schrittes?
if length(F_B) < 2 && ~(strcmp(arg.info.procedure,'ami_o') && arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1) == 0)
        % FALL: Keine erfolgreiche Berechnung, obwohl DELTA S_a_n_max ungleich 0
        % Dann erstmal versuchen, die "MAX"-Berechnung zum Erfolg zu bringen 
        % (vielleicht lag es ja auch an sehr kleinen Lastinkrementen z. B. ...)
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
                % "sauber" überschrieben werden.
                arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]) = caap_read_sap_file(arg.info.export_file);
                % Ergebnisse sortieren
                erg = arg.comp.erg.(['schritt_' num2str(arg.info.nummer)]);
                erg = caap_sort_field(erg,'BaseReactions','OutputCase');
                erg = caap_sort_field(erg,'JointDisplacements','OutputCase');
                % F_B und v_KK neu auslesen
                [F_B,v_KK] = sub_get_F_B_and_v_KK(arg,erg);
            end
        % Wenn nicht erfolgreich:    
        else
             % Dann haben wir ein Problem!
             error(['An analysis of the pushover curve is only possible with at least two points!\n',...
                 'Why these are not available in the current step %d is unclear!\n',...
                 'The attempt to make the calculation of the corresponding load case successful,\n',...
                 'unfortunately failed!\n',...
                 'The calculation must now be aborted for this reason!\n'],arg.info.nummer)
        end
end
% Ende: Kurze Zwischenüberprüfung <<

% Allgemeine Überprüfung/Fallunterscheidung:
% Gibt es nun (oder ggf. noch immer) weniger als 2 Punkte im aktuellen Segment der Pushover-Kurve?
% -> Dann ist die Überprüfung des globalen und lokalen Grenzkriteriums
%    nicht möglich!
if length(F_B) < 2
    % => FALL: Es kann KEINE normale Pushoverkurven-Analyse stattfinden!
    % -> Die Frage ist nun, ob das kein Problem ist (nur dann der Fall,
    %    wenn bei der "ami_o"-Berechnung eine "0"-Berechnung in primärer 
    %    Bebenrichtung durchgeführt wurde, weil der neue maximale Spektralwert
    %    des Bezugsmodes in primärer Richtung etwa dem letzten vorhandenen
    %    Spektralwert entsprach)
    if strcmp(arg.info.procedure,'ami_o') && arg.comp.delta_s_a_n_max_i.(arg.comp.d_earthquake{1,1})(arg.info.nummer,1) == 0
        % FALL: "0"-Berechnung beim "ami_o"-Verfahren
        % Kein weiterer (neuer) Adaptionsschritt
        arg.comp.new_step = 0;

        % Erkennungsflagge dieses Falls für die spätere "check_calc_succes"-Überprüfung setzen
        arg.comp.flag_nullberechnung = 1;

        % Für alle betrachteten Moden den neuen Punkt (S_d_n_i|S_a_n_i)
        % des jew. modalen Kapazitätsspektrums abspeichern
        arg = sub_save_new_spectral_values(arg);

        % Informative Ausgabe
        fprintf(['INFO: A "0" calculation was apparently performed in step %s,\n',...
                'which will most likely be due to the fact that the new maximum\n',...
                'spectral acceleration of the reference mode in primary seismic direction was\n',...
                'approximately the last available spectral value!\n',...
                'Consequently, an analysis of the pushover curve is not possible on the one hand,\n',...
                'but, on the other hand, it is not necessary because the calculation is terminated!\n'],num2str(arg.info.nummer));

    else
        % Wenn nur 2 Punkte bei 'nicht "0"-Berechnung', dann haben wir ein Problem!
        error(['An analysis of the pushover curve is only possible with at least two points!\n',...
              'Why these are not available in the current step %d is unclear!\n',...
              'The calculation must now be aborted for this reason!\n'],arg.info.nummer)
    end
else
    % => FALL: Es kann eine normale Pushoverkurven-Analyse stattfinden!

    % Ermittlung der globalen Anfangssteifigkeit
    E_1_0 = (arg.comp.pushoverkurve.initial(2,2)-arg.comp.pushoverkurve.initial(1,2))/...
            (arg.comp.pushoverkurve.initial(2,1)-arg.comp.pushoverkurve.initial(1,1));
    
    % Vorbelegung:
    % NaN = nach dem entsprechenden Kriterium wurde kein neuer Grenzzustand gefunden
    i_glob = NaN;
    i_lok = NaN;

    % Vorab-Ermittlung sämtlicher Steifigkeiten
    E = zeros(size(F_B,1)-1,1); % Vorbelegung
    for i_punkt = 1:1:size(F_B,1)-1
        % Steigung ermitteln
        E(i_punkt,1) = (F_B(i_punkt+1,1) - F_B(i_punkt,1))/(v_KK(i_punkt+1,1) - v_KK(i_punkt,1));
    end
    
    % Nur wenn die betragliche Sekantensteifigkeit über das gesamte aktuelle Pushover-
    % Kurven-Segment ein bestimmtes Maß des Betrags der globalen Anfangssteifigkeit aufweißt,
    % soll eine (globale und lokale) Grenzzustanduntersuchung durchgeführt werden. 
    % => Aktuell ist das Maß auf 2 % festgelegt, kann aber langfrisitg auch variabel vorgegeben werden!
    if abs((F_B(end,1) - F_B(1,1))/(v_KK(end,1) - v_KK(1,1)))/abs(E_1_0) >= 0.02
        
        %% Globales Kriterium prüfen
        % => Allerdings NUR, wenn der Betrag der Anfangssteifigkeit des
        %    aktuellen Pushover-Kurven-Segments auch mindestens 10 % des
        %    Betrags der globalen Anfangssteifigkeit beträgt
        if abs(E(1))/abs(E_1_0) >= 0.1
            E_vor_glob = E(1);
            for i_punkt = 2:1:size(F_B,1)-1
                E_nach_glob = E(i_punkt);
                % ehemals: "if E_nach_glob/E_vor_glob <= arg.comp.k_glob"
                % -> Ist offens. immer von Steigungsabnahmen ausgegangen, es gibt aber auch z. T. kurze Zunahmen!
                % -> Außerdem wurde dabei immer von positiven Steigungen ausgegangen, jetzt wird auch berücksichtigt, dass es einen VZW geben kann!
                if min(abs(E_vor_glob),abs(E_nach_glob))/max(abs(E_vor_glob),abs(E_nach_glob)) <= arg.comp.k_glob % -> VZW wird natürlich nur bei der lokalen Prüfung mit geprüft!!!
                    i_glob = i_punkt;
                    break
                end
            end
        end
    
        %% Lokales Kriterium prüfen
        for i_punkt = 2:1:size(F_B,1)-1
            E_vor_lok = E(i_punkt-1);
            E_nach_lok = E(i_punkt);
            % ehemals: "if E_nach_lok/E_vor_lok <= arg.comp.k_loc"
            % -> Ist ebenfalls immer von Steigungsabnahmen ausgegangen, es gibt aber auch z. T. kurze Zunahmen!
            % -> Außerdem wurde auch hier immer von positiven Steigungen ausgegangen, jetzt wird auch berücksichtigt, dass es einen VZW geben kann!
            if min(abs(E_vor_lok),abs(E_nach_lok))/max(abs(E_vor_lok),abs(E_nach_lok)) <= arg.comp.k_loc || E_vor_lok/E_nach_lok < 0 % -> Letzteres Kriterkum ist genau (und nur!) im Falle eines VZW erfüllt!!!
                i_lok = i_punkt;
                break
            end
        end    
    end
    
    
    %% Neue Parameter
    % Maßg. Pushover-Step identifizieren, der als erstes eines der beiden
    % Kriterien erfüllt
    i_step_massg = min(abs(i_glob),abs(i_lok));
    
    % Falls keins der beiden Kriterien erfüllt wurde:
    if isnan(i_step_massg)
        
        % Kein weiterer (neuer) Adaptionsschritt
        arg.comp.new_step = 0;
        
        % Im Fall "ami_o":
        if strcmp(arg.info.procedure,'ami_o')
            % Für alle betrachteten Moden den neuen Punkt (S_d_n_i|S_a_n_i)
            % des jew. modalen Kapazitätsspektrums abspeichern
            arg = sub_save_new_spectral_values(arg);
        end
    
    % Ansonsten (es wurde also mindestens ein Kriterium erfüllt):
    else
        % Schalter für "weiteren Adaptionsschritt" auf 1 setzen
        arg.comp.new_step = 1;
        
        % Aktuelle Adaptionsschritt-Nummer "arg.info.nummer" entspricht der
        % Nummer des zugehörigen Pushover-Segments
        arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).segment = arg.info.nummer;
        
        % Weitere Infos zu der aktuellen Grenzkriterienuntersuchung abspeichern
        arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).i_step_massg = i_step_massg;
        % a) Fall: Globales Kriterium war maßgebend
        if i_step_massg == abs(i_glob)
            % Infos zu dem maßgebenden Kriterium
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).kriterium_massg = 'global';
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).v_massg = v_KK(i_glob,1);
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).Fb_massg = F_B(i_glob,1);
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_vorh_massg = min(abs(E_vor_glob),abs(E_nach_glob))/max(abs(E_vor_glob),abs(E_nach_glob));
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_grenz_massg = arg.comp.k_glob;
            % Infos zu dem NICHT maßgebenden sekundären Kriterium
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).kriterium_sek = 'lokal';
            if ~isnan(i_lok) % nur wenn Kriterium auch erfüllt (nur eben nicht maßg. gegenüber globalem Krit.)
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).v_sek = v_KK(i_lok,1); % technisch nicht möglich
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_vorh_sek = E_nach_lok/E_vor_lok; % technisch möglich aber inhaltlich Quatsch (Erg. vom letzten Schleifendurchlauf)
            else
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).v_sek = NaN;
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_vorh_sek = NaN;
            end
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_grenz_sek = arg.comp.k_loc;
            
        % b) Fall: Lokales Kriterium war maßgebend     
        else
            % Infos zu dem maßgebenden Kriterium
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).kriterium_massg = 'lokal';
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).v_massg = v_KK(i_lok,1);
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).Fb_massg = F_B(i_lok,1);
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_vorh_massg = min(abs(E_vor_lok),abs(E_nach_lok))/max(abs(E_vor_lok),abs(E_nach_lok));
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_grenz_massg = arg.comp.k_loc;
            % Infos zu dem NICHT maßgebenden sekundären Kriterium
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).kriterium_sek = 'global';
            if ~isnan(i_glob) % nur wenn Kriterium auch erfüllt (nur eben nicht maßg. gegenüber lokalem Krit.)
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).v_sek = v_KK(i_glob,1); % technisch nicht möglich
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_vorh_sek = E_nach_lok/E_vor_lok; % technisch möglich aber inhaltlich Quatsch (Erg. vom letzten Schleifendurchlauf)
            else
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).v_sek = NaN;
                arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_vorh_sek = NaN;
            end
            arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer).m_grenz_sek = arg.comp.k_glob;
        end
        
        % Vorbereitungen (und z. T. weitere Auswertungen, wie neue Spektralordinaten)
        % auf Basis des gefundenen Grenzzustands je nach Berechnungsmethode
        switch arg.info.procedure
            case 'standard'
                % Bei einer "Standard"-Pushover-Berechnung:
                % Neue Zielverschiebung für den Korrekturschritt und auch schon
                % für den darauf folgenden nächsten Schritt ermitteln
                v_step = v_KK(i_step_massg,1);
                arg.comp.v_target(arg.info.nummer) = v_step - sum(arg.comp.v_target(1:arg.info.nummer-1));
                arg.comp.v_target(arg.info.nummer+1) = arg.comp.v_grenz - sum(arg.comp.v_target(1:arg.info.nummer));
                
            case 'ami_o'
                % Bei einer modifizierten AMI-Berechnung mit optimierten 
                % Spektralbeschleunigungsinkrementen des Bezugsmodes:
                % >> Pushover-Kurve und alles, was dazugehört, bezieht sich
                %    autom. auf die primäre Bebenrichtung, da es nur zu dieser
                %    eine Pushover-Kurve gibt!!! <<
                % (1) DELTA_F_B_soll_von_i ermitteln
                % F_B_grenz_von_i (Fundamentschub im maßgebenden Grenzzustand)
                F_B_grenz_von_i = F_B(i_step_massg);
                % F_B_end_von_i_minus_1
                if arg.info.nummer == 1
                    F_B_end_von_i_minus_1 = 0;
                else
                    F_B_end_von_i_minus_1 = arg.comp.pushoverkurve.gesamt(end,2); % Spalte 2 bezieht sich auf die Fundamentschübe
                end
                % DELTA_F_B_soll_von_i
                DELTA_F_B_soll_von_i = F_B_grenz_von_i - F_B_end_von_i_minus_1;
                
                % (2) Daraus nun den Korrekturfaktor K ableiten
                % Summe_DELTA_P_Rp_j_vorh_von_i 
                % (Vorzeichengerechete Summe und damit resultierende Kraftkomponenten
                % des vorh. Lastinkrementvektors in der betrachteten Bebenrichtung)
                i_Rp = arg.comp.d_earthquake{2,1}; % 1. Spalte: primäre Bebenrichtung, 2. Zeile: zugehöriger Index (1 für 'X' / 2 für 'Y' / 3 für 'Z')!
                Summe_DELTA_P_Rp_j_vorh_von_i = sum(arg.comp.f_matrix_akt(:,i_Rp));
                % Korrekturfaktor K
                K = abs(DELTA_F_B_soll_von_i /Summe_DELTA_P_Rp_j_vorh_von_i); % MUSS vom Prinzip her immer positiv sein (eine negative Skalierung ergibt keinen Sinn), daher einfach abs(...), weil F_B pos. und v_KK negativ sein kann!
                
                % (3) Weiterverarbeitung des Korrekturfaktors
                % (3.1) "arg.comp.f_matrix_akt" korrigieren/updaten
                %{
                % Hinweis: Einfache Skalierung mit Korrektur-Quotienten
                  (DELTA_S_a_B_korr_von_i/DELTA_S_a_B_vorh_von_i) möglich,
                  da DELTA_S_a_B in jedem Summanden aller (ggf. 3) Summen
                  linear eingeht!
                %}
                arg.comp.f_matrix_akt = arg.comp.f_matrix_akt * K;
                % Außerdem: Die korrigierte (endgültige) Lastverteilung des
                % aktuellen Schrittes archivieren (für potenzielle
                % nachträgliche Analyse der Lastverteilungsentwicklung)
                arg.comp.f_matrix(:,:,arg.info.nummer) = arg.comp.f_matrix_akt;
                % Und (für die Ermittlung sinnvoller NL Steps in "caap_write_sap_file"):
                % Korrigiertes Gesamt-Fundamentschub-Inkrement des aktuellen Schrittes
                % in primärer Bebenrichtung speichern
                arg.comp.delta_f_b_korr_von_i_akt = sum(arg.comp.f_matrix_akt(:,i_Rp));
                
                % (3.2) Für alle betrachteten Moden den neuen Punkt (S_d_n_i|S_a_n_i)
                % des jew. modalen Kapazitätsspektrums abspeichern mittels Schleife 
                % über alle Bebenrichtungen und jew. untergeordnete Schleife über
                % alle richtungsbezogenen Moden
                for i_R = 1:size(arg.comp.d_earthquake,2)
                    R_akt = arg.comp.d_earthquake{1,i_R};
                    for i_Mode_R_akt_initial = 1:length(arg.comp.modes.(R_akt))
                        % DELTA_S_a_n_korr_von_i bestimmen
                        DELTA_S_a_n_korr_von_i = arg.comp.delta_s_a_n_max_i.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) * K;
                        % DELTA_S_d_n_korr_von_i daraus ableiten
                        DELTA_S_d_n_korr_von_i = DELTA_S_a_n_korr_von_i / (arg.comp.omega_n_von_i.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial))^2;
                        % Neuen Punkt im modalen Kapazitätsspektrum ermitteln
                        % -> Im ersten Berechnungsdurchlauf gibt es noch keinen Vorgänger
                        if arg.info.nummer == 1
                            arg.comp.s_a_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = DELTA_S_a_n_korr_von_i;
                            arg.comp.s_d_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = DELTA_S_d_n_korr_von_i;
                            % Danach schon!
                        else
                            arg.comp.s_a_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = arg.comp.s_a_n.(R_akt)(arg.info.nummer-1,i_Mode_R_akt_initial) + DELTA_S_a_n_korr_von_i;
                            arg.comp.s_d_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = arg.comp.s_d_n.(R_akt)(arg.info.nummer-1,i_Mode_R_akt_initial) + DELTA_S_d_n_korr_von_i;
                        end
                    end
                end
                % Korrekturfaktor abspeichern, um später den Lastfall
                % "Pushover-Vergleich" durch Einstellen des Scale Factors (1/K)
                % anzupassen (der ja auf Basis des mit K korrigierten
                % Lastvektors zunächst angelegt wird)
                arg.comp.k(arg.info.nummer) = K;
        end
    end
end

end



%% Sub-Funktionen
% Sub-Funktion zum Auslesen der Kontrollknotenverschiebungen und
% Fundamentschübe der aktuellen PushOver-Kurve in der betrachteten Richtung
function [F_B,v_KK] = sub_get_F_B_and_v_KK(arg,erg)
% Kontrollknotenverschiebungen der aktuellen PushOver-Kurve in der
% betrachteten Richtung auslesen
index_row_v = find(strcmp(erg.JointDisplacements.Werte.(arg.info.name_pushover_old)(:,1),arg.comp.kk));
index_col_v = find(strcmp(erg.JointDisplacements.Inhalt(1,:),['U' mat2str(arg.comp.d_earthquake{2,1})]));
v_KK = cellfun(@str2num,erg.JointDisplacements.Werte.(arg.info.name_pushover_old)(index_row_v,index_col_v));
% Fundamentschübe (Beträge!!!) der aktuellen PushOver-Kurve in der
% betrachteten Richtung auslesen
index_col_F = find(strcmp(erg.BaseReactions.Inhalt(1,:),['GlobalF' arg.comp.d_earthquake{1,1}]));
F_B = abs(cellfun(@str2num,erg.BaseReactions.Werte.(arg.info.name_pushover_old)(:,index_col_F)));
end

% Sub-Funktion zur Ermittlung des neuen Punktes (S_d_n_i|S_a_n_i) beim "ami_o"-Verfahren im Fall "arg.comp.new_step = 0"
function arg = sub_save_new_spectral_values(arg)
% Für alle betrachteten Moden den neuen Punkt (S_d_n_i|S_a_n_i)
% des jew. modalen Kapazitätsspektrums abspeichern mittels Schleife
% über alle Bebenrichtungen und jew. untergeordnete Schleife über
% alle richtungsbezogenen Moden
for i_R = 1:size(arg.comp.d_earthquake,2)
    R_akt = arg.comp.d_earthquake{1,i_R};
    for i_Mode_R_akt_initial = 1:length(arg.comp.modes.(R_akt))
        % DELTA_S_a_n_korr_von_i bestimmen
        DELTA_S_a_n_von_i = arg.comp.delta_s_a_n_max_i.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial);
        % DELTA_S_d_n_korr_von_i daraus ableiten
        DELTA_S_d_n_von_i = DELTA_S_a_n_von_i / (arg.comp.omega_n_von_i.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial))^2;
        % Neuen Punkt im modalen Kapazitätsspektrum ermitteln
        % -> Im ersten Berechnungsdurchlauf gibt es noch keinen Vorgänger
        if arg.info.nummer == 1
            arg.comp.s_a_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = DELTA_S_a_n_von_i;
            arg.comp.s_d_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = DELTA_S_d_n_von_i;
            % -> Danach schon!
        else
            arg.comp.s_a_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = arg.comp.s_a_n.(R_akt)(arg.info.nummer-1,i_Mode_R_akt_initial) + DELTA_S_a_n_von_i;
            arg.comp.s_d_n.(R_akt)(arg.info.nummer,i_Mode_R_akt_initial) = arg.comp.s_d_n.(R_akt)(arg.info.nummer-1,i_Mode_R_akt_initial) + DELTA_S_d_n_von_i;
        end
    end
end
end
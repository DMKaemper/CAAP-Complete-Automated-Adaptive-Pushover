function arg = caap_CS_ATC40(modell,arg)
% arg = pp_caap_CS_ATC40(modell,arg)
%
% Ziel dieser Funktion ist es, aus den Ergebnissen einer stat. nichtl.
% Pushover-Berechnung (mit SAP2000) über das "CAAP"-Tool das Kapazitäts-
% spektrum für den vorgegebenen Kontrollknoten "kk" selbst aufzubauen.
% Die Transformation der i. Allg. segmentweisen Pushover-Kurve mit
% segmentweise unterschiedlichen modalen Eigenschaften (PHI, beta, M_eff)
% muss dabei segmentweise inkrementell erfolgen!
%
%
% Input:
%
% modell        - modell-Struktur (des SAP2000-Modells)
% arg           - Argument-Struktur der CAAP-Routine
%
%
% Output:
%
% arg           - arg-Struktur wie aus der Eingabe, erweitert um das Feld
%                 "cs" unter "arg.comp"


%% Schleife über alle Pushover-Segmente
% Vorbelegung
arg.comp.cs.gesamt = [];
arg.comp.cs.zusatzinfos.beta = zeros(arg.info.nummer,1);
arg.comp.cs.zusatzinfos.phi_kk_Rp = zeros(arg.info.nummer,1);
% Schleife über alle Segmente
for i_segment = 1:arg.info.nummer % letzter Zählerwert = höchster Wert = der Anzahl der Segmente
        
    %% Zwischenschritt: Benötigte modale Ergebnisse (für das aktuelle Segment) auslesen
    %                   (aus der letzten Modal-Analyse für die akt. Steifigkeitsverteilung)
    
    % Vorarbeit: Relevante Ergebnisse auslesen
    erg = arg.comp.erg.(['schritt_' num2str(i_segment-1)]);
    
    % (A) Namen des modalen Lastfalls bestimmen
    %     Bauart des Namens untersch. je nach Fall: Segment 1 oder späteres Segment
          if i_segment == 1
              % Bei Segment 1 entspricht der Name des modalen Lastfalls
              % einfach dem Inhalt des Struktur-Feldes "name_modal"
              LF_modal = arg.info.name_modal;
          else
              % Bei Segment n > 1 heißt der modale Lastfall
              % [name_modal,'__',num2str(i_seg)]
              LF_modal = [arg.info.name_modal,'__',num2str(i_segment)];
          end
    % (B) Modaler Anteilfaktor und effektive Modalmasse des gew. Modes (in primärer Bebenrichtung)
          % Ermittlung des korresp. Zeilenindizes in "erg.ModalParticipationFactors.Werte"
          idzs_richtiger_LF = strcmp(erg.ModalParticipationFactors.Werte(:,1),LF_modal);
          idzs_richtiger_Mode = strcmp(erg.ModalParticipationFactors.Werte(:,3),[num2str(abs(arg.comp.modes.(arg.comp.d_earthquake{1,1}))),'.']);
          i_zeile = find(idzs_richtiger_LF & idzs_richtiger_Mode);
          % Ermittlung des korresp. Spaltenindizes in "erg.ModalParticipationFactors.Werte"
          i_spalte = 4 + arg.comp.d_earthquake{2,1}; % bei 1 (X-Richtung) Spalte 5, bei 2 (Y-Richtung) Spalte 6 ... Ist das wirklich immer arg.comp.d_earthquake{2,1}, also immer die erste Spalte sprich primäre Bebenrichtung???????????????????????????????????????????????????????
          % Nun den gesuchten Anteilfaktor auslesen
          beta = str2double(erg.ModalParticipationFactors.Werte{i_zeile,i_spalte});
          % Speichern in der arg-Struktur (für spätere Rücktransf. des Performance Punktes)
          arg.comp.cs.zusatzinfos.beta(i_segment) = beta;
          % Damit folgt für die effektive Modalmasse (da in SAP2000 die
          % modale Masse jew. = 1 und damit beta_schlange = beta ist):
          M_eff = beta^2;
          % Speichern in der arg-Struktur (für spätere Rücktransf. des Performance Punktes)
          arg.comp.cs.zusatzinfos.m_eff(i_segment) = M_eff;
    % (C) Eigenvektorkomponente am Kontrollknoten in primärer Bebenrichtung
          % Ermittlung des korresp. Zeilenindizes in "erg.JointDisplacements.Werte"
          idzs_richtiger_joint = strcmp(erg.JointDisplacements.Werte(:,1),arg.comp.kk);
          idzs_richtiger_LF = strcmp(erg.JointDisplacements.Werte(:,2),LF_modal);
          idzs_richtiger_Mode = strcmp(erg.JointDisplacements.Werte(:,5),[num2str(abs(arg.comp.modes.(arg.comp.d_earthquake{1,1}))),'.']);
          i_zeile = find(idzs_richtiger_joint & idzs_richtiger_LF & idzs_richtiger_Mode);
          % Ermittlung des korresp. Spaltenindizes in "erg.JointDisplacements.Werte"
          i_spalte = 5 + arg.comp.d_earthquake{2,1}; % bei 1 (X-Richtung) Spalte 6, bei 2 (Y-Richtung) Spalte 7 ...
          % Nun die gesuchte Eigenvektor-Komponente am Kontrollknoten in primärer Bebenrichtung auslesen
          phi_kk_Rp = str2double(erg.JointDisplacements.Werte{i_zeile,i_spalte});
          % Speichern in der arg-Struktur (für spätere Rücktransf. des Performance Punktes)
          arg.comp.cs.zusatzinfos.phi_kk_Rp(i_segment) = phi_kk_Rp;


    %% Ermittlung der neuen Spektralordinaten ja nach Fall: adaptiv/nicht adaptiv
    %{
      Hinweis: Betragfunktion, also abs(), da VZ von beta irgendwie willkürlich; Skalierungsfaktor von PHI kürzt sich hier bei beta * PHI nicht "sauber" heraus!
               Und selbst wenn beta korrekt ermittelt und sagen wir positiv wäre, PHI_i(mp) aber negativ, schadet die Betragsfunktion auch nicht, dann sind halt
               die Spektralordinaten IMMER positiv (unabh. von der Richtung von DELTA_kk bzw. von F_B), das ist in meinen Augen sowieso sinnvoller als negative
               Spektralverschiebungen oder -beschleunigungen anzusetzen!
    %}
    % Fall: NICHT-ADAPTIVE Berechnung
    if arg.comp.adaptive == 0
        % (1) Ermittlung der Spektralverschiebungen
        % Kontrollknotenverschiebungen auslesen
        DELTA_kk_n = arg.comp.pushoverkurve.gesamt(:,1); % 1. Spalte: Kontrollknotenverschiebungen
        % Transformation durchführen
        S_d_n = abs(DELTA_kk_n / (beta * phi_kk_Rp));
            
        % (2) Ermittlung der Spektralbeschleunigungen
        % Fundamentschübe auslesen
        F_b_n = arg.comp.pushoverkurve.gesamt(:,2); % 2. Spalte: Fundamentschübe
        % Transformation durchführen
        S_a_n = abs(F_b_n / M_eff);
    % Fall: ADAPTIVE Berechnung
    else
        % (1) Ermittlung der Spektralverschiebungen
        % Kontrollknotenverschiebungen des aktuellen Segments auslesen
        DELTA_kk_Seg_akt_n = arg.comp.pushoverkurve.(['segment_',num2str(i_segment)])(:,1); % 1. Spalte: Kontrollknotenverschiebungen
        % Letzte Kontrollknoten- und Spektralverschiebung des vorherigen Segments auslesen,
        % so es ein vorheriges Segment gibt
        if i_segment > 1
            DELTA_kk_Seg_vorherig_end = arg.comp.pushoverkurve.(['segment_',num2str(i_segment-1)])(end,1); % 1. Spalte: Kontrollknotenverschiebungen
            S_d_n_Seg_vorherig_end = arg.comp.cs.(['segment_',num2str(i_segment-1)])(end,1); % 1. Spalte: Spektralverschiebungen
        else
            DELTA_kk_Seg_vorherig_end = 0;
            S_d_n_Seg_vorherig_end = 0;
        end
        % Transformation durchführen
        S_d_n = S_d_n_Seg_vorherig_end + abs((DELTA_kk_Seg_akt_n - DELTA_kk_Seg_vorherig_end) / (beta * phi_kk_Rp));
        %{
        Hinweis: Betragfunktion, also abs(), da VZ von beta irgendwie willkürlich; Skalierungsfaktor von PHI kürzt sich hier bei beta * PHI nicht "sauber" heraus!
                 Und selbst wenn beta korrekt ermittelt und sagen wir positiv wäre, PHI_i(mp) aber negativ, schadet die Betragsfunktion auch nicht, dann ist halt
                 die Spektralverschiebung IMMER positiv (unabh. von der Richtung von DELTA_kk), na und?
        %}
        
        % (2) Ermittlung der Spektralbeschleunigungen
        % Fundamentschübe des aktuellen Segments auslesen
        F_b_n = arg.comp.pushoverkurve.(['segment_',num2str(i_segment)])(:,2); % 2. Spalte: Fundamentschübe
        % Letzten Fundamentschub und letzte Spektralbeschleunigung des vorherigen Segments auslesen,
        % so es ein vorheriges Segment gibt
        if i_segment > 1
            F_b_Seg_vorherig_end = arg.comp.pushoverkurve.(['segment_',num2str(i_segment-1)])(end,2); % 2. Spalte: Fundamentschübe
            S_a_n_Seg_vorherig_end = arg.comp.cs.(['segment_',num2str(i_segment-1)])(end,2); % 2. Spalte: Spektralbeschleunigungen
        else
            F_b_Seg_vorherig_end = 0;
            S_a_n_Seg_vorherig_end = 0;
        end
        % Transformation durchführen
        S_a_n = S_a_n_Seg_vorherig_end + abs((F_b_n - F_b_Seg_vorherig_end) / M_eff);
    end
    %{
    Abschließende Erläuterung zur m. E. zulässigen (und sinnvollen) Anwendung 
    der Betragsfunktion am Beispiel der Ermittlung der Spektralverschiebungen
    
    Zentrale Annahme dieser Transformationsgleichung ist ja, dass man sagt:
    vec V = vec V_max(eta_j) = eta_j,max * vec PHI_j = (beta_j * S_d,j) * vec PHI_j.
    Man nimmt also an bzw. unterstellt im Sinne der Transformation, dass
    der Vektor V_max nur aus dem j-ten Modalbeitrag resultiert und sich
    auch vor allem konkret aus der Rücktransformation ergäbe. Eigentlich
    liefert V_max aber einfach eine Verformungsfigur, die aus der
    Pushover-Lastverteilung (nichtl.-statisch) ermittelt wurde, sprich mit
    einer Rücktransformation aus dem Modalraum gar nichts zu tun hat.
    Dies kann jetzt bedeuten, dass DELTA_kk, als eine Komponente von V_max
    negativ ist, obwohl S_d, was immer positiv ist, und beta_j sowie 
    vec PHI_j zu einem positiven Wert geführt hätten. Dieser unbegründbare
    Vorzeichenwechsel zwischen linker & rechter Seite kommt eben daher,
    dass dieser fiktive "Rücktransformations-Zusammenhang" ja eigentlich
    faktisch nicht besteht. Demzufolge darf man aber dann m. E. auch das
    Vorzeichen von S_d bei der Transformation der Pushover-Kurve ignorieren
    und den Betrag nehmen, da Spektralverschiebungen "von Natur aus"
    positiv sind!
    
    Ähnliches gilt eben auch für die Spektralbeschleunigungen in
    Kombination mit dem Fundamentschub!
    %}


    %% Ergebnisse des aktuell betrachteten Segments an die arg-Struktur übergeben
    % 1. Segment-bezogen separat abspeichern
    arg.comp.cs.(['segment_',num2str(i_segment)]) = [S_d_n,S_a_n];
    % 2. An die bisherige Gesamt-Kurve anhängen
    arg.comp.cs.gesamt = [(arg.comp.cs.gesamt)' [S_d_n,S_a_n]']';    
end


%% Ggf.: Plot des Kapazitätsspektrums
% Prüfen, ob Plot gewünscht
if arg.info.console == 1
 
    % Figure aufmachen und "Vorarbeit"
    figure('name','Sa-Sd diagram');
    hold on;
    color_index = 1:arg.info.nummer; % letzter Zählerwert = höchster Wert = der Anzahl der Segmente
    % Segmentweise (farbig & etwas dicker) plotten
    for i_segment = 1:1:arg.info.nummer
        % Plotfarbe des aktuellen Segments
        color = arg.info.cmap(color_index(1,i_segment),:);
        % Plotten
        plot(...
            arg.comp.cs.(['segment_' num2str(i_segment)])(:,1),...
            arg.comp.cs.(['segment_' num2str(i_segment)])(:,2),...
            'Linewidth',2,'color',color)
    end
    % Gitternetz einblenden
    grid()
    % Achsen-Beschriftung & Titel hinzufügen
    % > Einheiten
    units = strsplit(modell.ProgramControl.CurrUnits{1,1},',');
    for i_unit = 1:1:size(units,2)
        units(1,i_unit) = {strrep(units{1,i_unit},' ','')};
    end
    % > Bezeichnung anwenden
    xlabel(sprintf('$S_{d,%s}~[%s]$',lower(arg.comp.d_earthquake{1,1}),units{1,2}),'interpreter','latex') % die Spektralverschiebungen haben die Längeneinheit des SAP2000-Modells selbst (i. d. R. Meter!)
    ylabel(sprintf('$S_{a,%s}~[%s]$',arg.comp.d_earthquake{1,1},'m/s^2'),'interpreter','latex')  % die Spektralbeschleunigungen haben immer die Einheit m/s² (gem. F = m*a, ich kann in SAP2000 z. B. KN vorgeben, dann rechnet er mit Tonnen und dazwischen stehen eben Beschl. in m/s²)
    title('Capacity spectrum','interpreter','latex')
    set(gca,'TickLabelInterpreter','latex')
    hold off
    
end

end

function arg = caap_CSM_determine_PP(modell,arg)
% arg = caap_CSM_determine_PP(modell,arg)
%
% Ziel dieser Funktion ist es, auf Basis eines (nachfolgend intern mit der Funktion
% "caap_el_accel_response_spectrum" ermittelten) gedämpften elastischen Antwortspektrums 
% sowie eines mit der Funktion "caap_CS_ATC40" aufgebauten Kapazitätsspektrums einen 
% zugehörigen Performance Punkt (S_d_PP | S_a_PP) mittels der KAPAZITÄTSSPEKTRUM-METHODE 
% (Capacity Spectrum Method, kurz: "CSM") nach ATC40 (1996), Kap. 8.2.2.1 zu bestimmen.
% Gemäß dieser Methode wird das in das S_a-S_d-Diagramm transformierte Antwortspektrum
% iterativ in Abhängigkeit von der effektiven Dämpfung gedämpft (und damit praktisch 
% "abgemindert", aber nicht zwangsläufig - und daher in unserem Fall auch nicht - über
% die Abminderungsfaktoren SR_a & SR_d!!!).
% Neben dem Performance Punkt selbst und der Nummer des Pushover-Segmentes,
% in dem dieser liegt (wichtig für adaptive Ber.), sowie des segmentinternen
% Lastniveaus wird außerdem die rücktransformierte Kontrollknotenverschiebung
% (im Performance Zustand) unter "arg.comp.pp" abgespeichert und darüber hinaus
% in der Konsole ausgegeben.
% => So ist das CAAP-Tool mit der Funktion "caap_final_performance" in der Lage, 
%    eine neue Pushover-Berechnung bis zu genau dieser Verschiebung durchzuführen
%    (bei adaptiven Berechnungen muss davon noch die Endverschiebung des letzten
%    Segments natürlich abgezogen werden!),sodass sämtliche Tragwerksantworten im
%    letzten Last-Schritt genau den Performance-Zustand des Tragwerks abbilden.
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
%                 "pp" unter "arg.comp"


%% Bestimmte Eingaben prüfen
% (1) Prüfung, ob Hysterese-Verhalten nach ATC40 (1996), Tabelle 8-4 korrekt
%     angegeben wurde
% -> Vorarbeit: Definition zulässiger Angaben
HB_zulaessig = {'A','B','C'};
% -> Erstmal prüfen, ob überhaupt eine Angabe vorliegt
if isfield(arg.comp,'hb')
    % -> Falls klein geschrieben: in Großbuchstaben überführen
    HB = upper(arg.comp.hb);
    % -> Dann prüfen, ob diese die zulässige Form aufweist
    if ~ismember(HB,HB_zulaessig)
        % Fall: Angabe weist nicht die gewünschte/erf. Form auf, man kann
        % aber leider keinen Hysteresetyp schätzen (default-Wert ansetzen)
        error('Information regarding the hysteresis type to be considered cannot be interpreted!')
    end
else
    % -> Ohne Hysteresetyp kann man nichts machen!
    error('No hysteresis type to be considered was specified!')
end
% (2) Prüfung, ob der erste Test-Performance Punkt (& wenn ja richtig) vorgegeben wurde
% -> Erstmal prüfen, ob hierzu überhaupt ein Strukturfeld vorliegt
if isfield(arg.comp,'pp_Test')
    % -> Dann prüfen/verifizieren, ob/dass dieses die Form [S_d_pj,S_a_pj] aufweist
    if size(arg.comp.pp_Test,1) == 1 && size(arg.comp.pp_Test,1) == 2
        % Falls ja: Zumindest die richtie Anzahl an Angaben für den ersten
        % Test-Performance Punkt liegt vor
        % -> Dann deren Inhalt/Form prüfen
        if ~ist_typ(arg.comp.pp_Test(1),'float') || ~ist_typ(arg.comp.pp_Test(2),'float')
            % Mindestens ein Wert hat eine falsche Form
            % -> Warnung ausgeben
            fprintf(2,'The first test performance point cannot be interpreted and is therefore ignored!\n')
            % -> Eingabe ignorieren/löschen
            arg.comp = rmfield(arg.comp,'pp_Test');
        end
    % -> Alternativ ist die Angabe unzulässig, es sei denn das Feld ist leer    
    elseif ~isempty(arg.comp.pp_Test)
        % Fall: Es wurde kein "ganzer" Test-Performance Punkt definiert
        % -> Warnung ausgeben
        fprintf(2,'The first test performance point must be defined in the form [S_d_pj,S_a_pj]! The specification is therefore ignored in the following!\n')
        % -> Eingabe ignorieren/löschen
        arg.comp = rmfield(arg.comp,'pp_Test');
    end
end


%% Vorarbeit
% (1) Zu allen Kapazitätsspektrums-Segmenten die zugehörige "step"-Anzahl ermitteln
      % Erst entspr. Vektor vorbelegen:
      n_segmente_vorh = arg.info.nummer; % letzter Zählerwert = höchster Wert = der Anzahl der Segmente
      n_level_vorh = zeros(n_segmente_vorh,1);
      % Nun: Schleife über alle Segmente
      for i_segment = 1:n_segmente_vorh
          n_level_vorh(i_segment) = size(arg.comp.cs.(['segment_',num2str(i_segment)]),1);
      end
      % Anzahl der Lastschritte aus der (jew.) Lastniveau-Anzahl ableiten (-1)
      n_steps_vorh = n_level_vorh - ones(size(n_level_vorh,1),1);

% (2) Spektralwerte des Kapazitätsspektrums umspeichern (für kürzeren Zugriff)
      CS_ATC40 = arg.comp.cs;


%% Unmittelbare Vorbereitung der Iteration zur PP-Ermittlung
% Flag setzen, die anzeigt: Performance Punkt (kurz PP) noch nicht gefunden
flag_PP = 0;

% Maximale Anzahl durchgeführter Iterationsschritte festlegen
max_iteration = 50;

% Vorbelegung des Iterationsschleifen-Zählers
i_iteration = 0;

% Vorbelegung des Vektors der Schätzer für die Spektralverschiebung im
% Performance Punkt 
%{
Anders als bei der Spektralbeschleunigung werden die Spektralverschiebungen
vektoriell gespeichert, um später mögliche alternierende Iterationsschritte
identifizieren zu können!
%}
S_d_pj = nan(max_iteration,1);

% Falls ein erster Test-Performance Punkt (formal korrekt) definiert wurde:
% Zum angegebenen Test-Performance Punkt korresp. Last-Segment und internes Lastniveau ermitteln (falls nicht zuordenbar: Warnung ausgeben und Angabe ignorieren!)    
if isfield(arg.comp,'pp_Test') && ~isempty(arg.comp.pp_Test) % Formal inkorrekte Definition wird oben schon abgefangen!
    % -> S_d_pj & S_a_pj auslesen
    S_d_pj(1) = arg.comp.pp_Test(1);
    S_a_pj    = arg.comp.pp_Test(2);
    % -> Übergeordnete Schleife über alle Pushover-Segmente
    for i_Segment = 1:n_segmente_vorh
        % Schauen, ob man im "i_Segment"-ten Bereich "fündig" wird
        i_level_Segment_pj_Test1 = find(gleich(S_d_pj(1),CS_ATC40.(['segment_',num2str(i_Segment)])(:,1),0.00001));
        i_level_Segment_pj_Test2 = find(gleich(S_a_pj,CS_ATC40.(['segment_',num2str(i_Segment)])(:,2),0.00001));
        % Prüfen, ob ein entspr. Lastniveau gefunden wurde
        if ~isempty(i_level_Segment_pj_Test1)
            % Nun prüfen, ob Spektralverschiebung und -beschleunigung
            % dasselbe Lastniveau liefern
            if i_level_Segment_pj_Test1 == i_level_Segment_pj_Test2
                % Dann kennt man nun das richtige Segment sowie den Segment-internen Lastniveau-Index:
                i_Segment_pj = i_Segment;
                i_level_Segment_pj = i_level_Segment_pj_Test1;
                % Schleife abbrechen
                break
            else
                % Inhaltlich inkorrekter Schätzer für den Performance Punkt
                % -> Warnung ausgeben
                fprintf(2,'The specified first test performance point is NOT an actual point of the capacity spectrum and is therefore ignored in the following!\n')
                % -> Eingabe ignorieren/löschen
                arg.comp = rmfield(arg.comp,'pp_Test');
            end
        end
    end
    % Am Ende einmal prüfen, ob überhaupt irgendwo etwas vernünftiges herausgekommen ist (und nicht in jedem Segment einfach "empty")
    if ~exist('i_Segment_pj','var')
        % Inhaltlich inkorrekter Performance Punkt Schätzer
        % -> Warnung ausgeben
        fprintf(2,'The specified first test performance point is NOT an actual point of the capacity spectrum and is therefore ignored in the following!\n')
        % -> Eingabe ignorieren/löschen
        arg.comp = rmfield(arg.comp,'pp_Test');
    end
end

% Falls KEIN erster Test-Performance Punkt definiert oder dieser eben (aufgrund
% formaler oder inhaltlicher Mängel) in den obigen Programmzeilen gelöscht wurde:
if ~isfield(arg.comp,'pp_Test') || isempty(arg.comp.pp_Test)
    % Angabe des ersten Test-Performance Punktes, da es vor Durchlauf der
    % ersten Iterationsschleife eben noch keinen letzten Schnittpunkt gibt!
    %{
    Hinweis: Der erste Punkt des Kapazitätsspektrums nach dem Punkt (0|0)
    eignet sich NICHT als Schätzer für den Performance Punkt, da genau für
    diesen der Nenner der Bestimmungsgleichung für S_d_y = 0 ist!
    %}
    % -> Daher wird zunächst der letzte Punkt des Kapazitätsspektrums bzw.
    %    letzten Kapazitätsspektrum-Segments gewählt, weil man denke ich in
    %    den meisten Fällen behaupten kann (ACHTUNG: AUSNAHMEN MÖGLICH!!!):
    %    Wenn man hiermit (mit maximaler äquivalenter viskoser Dämpfung
    %    infolge maximaler Hystereseenergie) keinen Schnittpunkt findet,
    %    dann wird man mit PP-Schätzern "weiter vorne" im Kapazitätsspektrum
    %    mit deutlich weniger Hystereseenergie vermutlich erst Recht keinen
    %    Schnittpunkt finden und kann demnach aufhören!
    i_Segment_pj = n_segmente_vorh; % letztes Pushover-Segment
    i_level_Segment_pj = n_steps_vorh(i_Segment_pj); % letztes Lastniveau innerhalb dieses letzten Segments
    S_d_pj(1) = CS_ATC40.(['segment_',num2str(i_Segment_pj)])(i_level_Segment_pj,1);
    S_a_pj    = CS_ATC40.(['segment_',num2str(i_Segment_pj)])(i_level_Segment_pj,2);
end


%% Iterative Ermittlung des Performance Punktes (mit schrittweiser Abminderung des transformierten el. Antwortspektrums) nach der Kapazitätsspektrum-Methode
% => While-Schleife, solange
% a) noch kein PP gefunden wurde, der das Grenzkriterium der Kapazitätsspektrum-Methode nach ATC40 (1996), S. 8-20 erfüllt
% b) die maximale Iterationsschritt-Anzahl noch nicht erreicht ist
while ~flag_PP && i_iteration <= max_iteration
    
    % Iterations-Zähler um 1 erhöhen
    i_iteration = i_iteration + 1;
    % Flag setzen, die anzeigt: Schnittpunkt (kurz SP) beider Kurven noch nicht gefunden
    flag_SP = 0;
    % Startwert von (im Vergleich zum untergeordneten Zähler 2 der Pushover-Segmente) übergeordnetem Zähler 1 ('i_section_RS') auf 1 setzen
    i_section_RS = 1;
    
    % JE ITERATIONSSCHRIT:

    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    % (1) Zweisegmentige Linearisierung des Kapazitätsspektrums bis zum
    %     Test-Performance Punkt
    %{
    Hintergrundinformation zur Ermittlung von A_soll:
    Es wird in jedem Iterationsschritt bis zum aktuellen Test-Performance Punkt
    integriert (mittels numerischer Integration auf Basis der Trapez-Regel),
    d. h.: bis zum letzten tats. Punkt (mit Nummer 'i_step_Segment_pj' innerhalb
    des aktuellen Kapazitätsspektrum-Segments) des Kapazitätsspektrums vor diesem
    und dann von diesem letzten "echten" Punkt bis zum genannten Test-Performance
    Punkt. Im allerersten Schritt (Sonderfall) ist der fiktive Punkt sogar ein
    echter Punkt, sodass das letzte Trapez einfach den Flächeninhalt "0" hat (was
    aber ja nichts zerschießt).
    %}
    % Anfangssteigung des Kapazitätsspektrums über Steigungsdreieck
    % zw. den Punkten 1 und 2, mit Punkt 1 = (0|0)
    k_0 = CS_ATC40.segment_1(2,2)/CS_ATC40.segment_1(2,1); % Zeile 2: Punkt 2 (Spalte 1: S_d_n, Spalte 2: S_a_n)
    % Flächeninhalt unter dem Kapazitätsspektrum bis zum Test-Performance Punkt
    % (segmentweise integrieren bis zum Segment)
    A_soll = 0; % Vorbelegung
    % Als erstes eine Schleife über alle "vollständig abzugrasenden" Segmente
    for i_Segment = 1:(i_Segment_pj - 1)
        % Beim ersten Segment kommt noch das Trapez vom Punkt (0|0) bis zum
        % ersten gespeicherten Spektralpunkt hinzu
        if i_Segment == 1
            A_soll = A_soll + trapz([0; CS_ATC40.(['segment_',num2str(i_Segment)])(:,1)],[0; CS_ATC40.(['segment_',num2str(i_Segment)])(:,2)]); % alle Zeilen: alle Punkte; Spalte 1: S_d_n, Spalte 2: S_a_n
        % Bei allen weiteren Segmenten wird allerdings das Trapez vom letzten Punkt 
        % des letzten Segments bis zum ersten Punkt des aktuellen Segments
        % nicht mit angesetzt, da diese beiden Punkte jew. identisch sind.
        % (Zwar wäre der Flächeninhalt dann eigentlich eh 0, aber sicher ist sicher.)
        else
            A_soll = A_soll + trapz(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1),CS_ATC40.(['segment_',num2str(i_Segment)])(:,2)); % alle Zeilen: alle Punkte; Spalte 1: S_d_n, Spalte 2: S_a_n
        end
    end
    % Nun als zweites das letzte Segment, in dem der Test-PP liegt, bis zu 
    % ebendiesem Punkt (S_d_pj | S_a_pj) integrieren
    A_soll = A_soll + trapz([CS_ATC40.(['segment_',num2str(i_Segment_pj)])(1:i_level_Segment_pj,1); S_d_pj(i_iteration)],...
        [CS_ATC40.(['segment_',num2str(i_Segment_pj)])(1:i_level_Segment_pj,2); S_a_pj]); % alle Zeilen bis i_level_Segment_pj: alle Punkte bis zum letzten vor dem Test-PP (Spalte 1: S_d_n, Spalte 2: S_a_n)
    % Spektralverschiebung S_d_y im effektiven Fließpunkt (y: "yielding") bestimmen
    S_d_y = (2 * A_soll - S_a_pj * S_d_pj(i_iteration)) / (k_0 * S_d_pj(i_iteration) - S_a_pj);
    % Spektralverschiebung im effektiven Fließpunkt daraus ableiten
    % (über das erste Segment der stückweise linearen Idealisierung)
    S_a_y = k_0 * S_d_y;

    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    % (2) Ermittlung des effektiven Dämpfungsmaßes xi_eff sowie (darauf
    %     aufbauend) des abgeminderten elastischen Antwortspektrums
    
    % Maximale Dehnungsenergie E_So ermitteln
    E_So = (S_d_pj(i_iteration) * S_a_pj) / 2; % (vgl. ATC40 (1996), S. 8-15)
    
    % Hystereseenergie E_D ermitteln
    % E_D darf nicht negativ sein
    % im linear-elastischen Bereich kann das auf Grund von numerischen
    % Ungenauigkeiten aber vorkommen
    E_D = max([0,4 * (S_a_y * S_d_pj(i_iteration) - S_d_y * S_a_pj)]); % (vgl. ATC40 (1996), S. 8-15)
    
    % Äquivalentes viskoses Dämpfungsmaß daraus ableiten
    xi_eq = 1/(4*pi) * E_D/E_So; % [-] (vgl. ATC40 (1996), Gl. 8-5a)
    
    % Korrekturfaktor Kappa(xi_eq) nach ATC40 (1996), Tabelle 8-1
    switch HB
        case 'A' % stabile Hystereseschleifen (hohe Energiedissipation)
            if xi_eq <= 0.1625
                Kappa = 1.0;
            else
                Kappa = 1.13 - 0.51 * ((S_a_y * S_d_pj(i_iteration) - S_d_y * S_a_pj) / (S_a_pj * S_d_pj(i_iteration)));
            end
        case 'B' % relativ gering eingeschnürte Hystereseschleifen
            if xi_eq <= 0.25
                Kappa = 0.67;
            else
                Kappa = 0.845 - 0.446 * ((S_a_y * S_d_pj(i_iteration) - S_d_y * S_a_pj) / (S_a_pj * S_d_pj(i_iteration)));
            end
        case 'C' % stark eingeschnürte Hystereseschleifen
            Kappa = 0.33;
    end
    
    % Damit ergibt sich das effektive (Gesamt-)Dämpfungsmaß zu
    arg.comp.xi_eff = arg.comp.xi_0 + Kappa * xi_eq*100; % [%]!!! (vgl. ATC40 (1996), Gl. 8-8)
    
    % Aufbau des gedämpften elastischen Antwortspektrums  
    arg = caap_el_accel_response_spectrum(arg);
    
    % Transformation des gedämpften elastischen Antwortspektrums
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
    
    % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    % (3) Schnittpunkt der beiden Spektren ermitteln (im allerersten Iterationsschritt ist das Antwortspektrum noch nicht abgemindert!)
    
    % Übergeordnete Schleife über alle "Teilstücke" ("sections") des Antwortspektrums
    while ~flag_SP && i_section_RS <= size(RS_S_a_n_red,2)-1 % (-1, da ein Teilstück weniger als Punkte)
        
        % Startwert des untergeordneten Zählers 2 'i_segment_CS' immer wieder (bei jedem neuen übergeordneten
        % Schleifendurchlauf der Antwortspektrum-Schleife) auf 1 setzen!
        i_segment_CS = 1; % Zähler des Pushover-Segments (bei nicht-adaptiven Ber. immer = 1)
        
        % Untergeordnete Schleife über alle "Pushover-Segmente" ("segment") des Kapazitätsspektrums
        while ~flag_SP && i_segment_CS <= n_segmente_vorh
            
            % Startwert des untergeordneten Zählers 3 'i_section_CS' immer wieder (bei jedem neuen übergeordneten
            % Schleifendurchlauf der Kapazitätsspektrum-Segment-Schleife) auf 1 setzen!
            i_section_CS = 1; % Zähler des Pushoverschrittes bzw. "Teilstücks" INNERHALB des aktuellen Segments des segmentweise definierten (zusammengesetzten) Kapazitätsspektrums
            
            % Untergeordnete Schleife über alle "Teilstücke" ("section") des Kapazitätsspektrum-Segments
            while ~flag_SP && i_section_CS <= n_level_vorh(i_segment_CS)-1 % (-1, da ein Teilstück weniger als Punkte)
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
                s21 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,1); % Ortsvektor-Komponente
                r21 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS + 1,1) - CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,1); % Richtungsvektor-Komponente
                s22 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,2); % Ortsvektor-Komponente
                r22 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS + 1,2) - CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,2); % Richtungsvektor-Komponente
                
                % Theoretischen Schnittpunkt der zunächst unendlich langen Geraden
                % ermitteln
                vec_f = 1 / (-r11*r22 + r12*r21) * [-r22 r21; -r12 r11] * [(s21 -s11); (s22 -s12)];
                
                % Prüfen, ob die Skalierungsfaktoren beide zwischen 0 und 1 liegen
                % (dann ist der theoretische auch ein praktischer Schnittpunkt)
                if 0 <= vec_f(1) && vec_f(1) <= 1 && 0 <= vec_f(2) && vec_f(2) <= 1
                    % Wenn ja -> Es wurde ein tatsächlicher Schnittpunkt innerhalb der beiden
                    % endlichen Teilstücke gefunden:
                    % Dann muss noch ausgeschlossen werden, dass es sich dabei um
                    % den Punkt (0|0) handelt:
                    % -> (Theor.) Performance Punkt auswerten
                    S_d_PP = s11 + vec_f(1) * r11;
                    S_a_PP = s12 + vec_f(1) * r12;
                    % Ursprung (0|0) des A-D-Diagramms ausschließen
                    if ~(S_d_PP == 0 && S_a_PP == 0)
                        % Theoretischer Performance Punkt ist
                        % (höchstwahrscheinlich) auch ein faktischer (sinnvoller)
                        % -> Alle Schleifen abbrechen!
                        flag_SP = 1; % Performance Punkt gefunden!
                    else
                        % Schade, dann muss doch weiter gesucht werden:
                        % -> Untergeordneten Schleifenzähler 3
                        % ('i_section_CS') um 1 erhöhen und weiter gehts
                        % mit dem nächsten Punkt innerhalb des aktuellen
                        % CS-Segments
                        i_section_CS = i_section_CS + 1;
                    end
                else
                    % Wenn nein -> Untergeordneten Schleifenzähler 3 ('i_section_CS') um 1 erhöhen 
                    % und weiter gehts mit dem nächsten Punkt innerhalb des aktuellen CS-Segments
                    i_section_CS = i_section_CS + 1;
                end
            end
            % -> Inneren Schleifenzähler 2 ('i_segment_CS') um 1 erhöhen und weiter gehts
            % mit dem nächsten CS-Segment
            i_segment_CS = i_segment_CS + 1;
        end
        % -> Übergeordneten Schleifenzähler 1 ('i_section_RS') um 1 erhöhen und weiter gehts
        % mit dem nächsten Abschnitt des Antwortspektrums
        i_section_RS = i_section_RS + 1;
    end    
    
    % --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    % (4) Wenn ein potenzieller PP gefunden wurde: 5%-Grenzkriterium nach ATC40, S. 8-20 prüfen
    if exist('S_d_PP','var')
        % Fall: Es wurde ein potenzieller PP gefunden
        if 0.95*S_d_pj(i_iteration) <= S_d_PP && S_d_PP <= 1.05*S_d_pj(i_iteration)
            % Es wurde ein gültiger Performance Punkt gefunden!
            flag_PP = 1; 
            % Ggf. akkustische Eskalation
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
                    fprintf(2,'Unfortunately the jingle could not be played!\n')
                end
            end
        else
            % Zunächst für weitere Iterationen die Spektralverschiebung S_d_PP merken, 
            % die zumindest zu einem "erfolgreichen" Schnittpunkt korrespondiert hat
            % (konkret für den nachfolgenden "else"-Fall, und dort Fall B)
            S_d_Schnpkt = S_d_PP;
            % Nun ab dem 4. Iterationsschritt prüfen, ob sich der Algorithmus
            % in einer alternierenden Entwicklung (Wechsel) "festgefahren" hat
            %{
            Dies kann in einem "ab-ab..."-Schema zwischen S_d_pj & S_d_PP
            sein, aber auch ggf. in einem "ab-aa*-b*a..."-Schema o. ä.!!!
            %}
            % Wenn ja:   Dann mal die gemittelte Spektralverschiebung des letzten
            %            und vorletzten Schnittpunkts ermitteln und den dazu
            %            korrespondierenden nächsten tats. Punkt des
            %            Kapazitätsspektrums auslesen
            % Wenn nein: Dann einfach den letzten Schnittpunkt als neuen
            %            Schätzer für den Performance Punkt ansetzen
            if i_iteration >= 4 && gleich(S_d_pj(i_iteration-2),S_d_pj(i_iteration),0.01) && gleich(S_d_pj(i_iteration-3),S_d_pj(i_iteration-1),0.01) % Gleichheit hier anhand einer Abweichung von 1 % identifizieren!
                % Fall: Festgefahrenes Alternieren von S_d_pj & S_d_PP
                % Spektralverschiebung aus Wert des letzten Schätzers und letzten Schnittpunkts mitteln
                S_d_pj_gemittelt = (S_d_PP + S_d_pj(i_iteration)) / 2; % S_d_pj(i_iteration) ist ja aktuell noch die Spektralverschiebung des letzten Schätzers
                % Den Punkt im Kapazitätsspektrum suchen, dessen
                % Spektralverschiebung am nächsten an diesem Wert liegt
                for i_Segment = 1:n_segmente_vorh
                    % Prüfen, ob die gemittelte Spektralverschiebung in diesem Segment
                    % oder der rechts daran angrenzenden Definitionslücke liegt
                    % (letztere gibt es immer, außer im letzten Segment bei i_Segment == n_segmente_vorh)
                    if S_d_pj_gemittelt >= min(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1)) && (i_Segment == n_segmente_vorh || S_d_pj_gemittelt <= min(CS_ATC40.(['segment_',num2str(i_Segment+1)])(:,1))) % 2. Kriterium: Entweder man ist schon im letzten Segment, oder der Punkt liegt zumindest vor dem letzten Segment
                        % Fall: Gemittelter Punkt liegt IM aktuellen
                        % Segment ODER in der rechts angrenzenden Definitionslücke
                        % 1.) Segment merken (für nächsten while-Schleifendurchlauf)
                              i_Segment_pj = i_Segment;
                        % 2.) Nun prüfen, welcher der beiden Fälle hier vorliegt
                              if S_d_pj_gemittelt <= max(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1))
                                  % Fall: Der gemittelte Punkt liegt
                                  % wirklich INNERHALB dieses Segments
                                  % a) Dann den Punkt INNERHALB DIESES SEGMENTS heraussuchen,
                                  %    der am nächsten an S_d_pj liegt
                                       i_level_Segment_pj = finde_aehnlichsten(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1),S_d_pj_gemittelt);
                                  % b) Und anschließend prüfen, ob dieser Punkt VOR oder HINTER dem
                                  %    gemittelten Punkt liegt
                                       if CS_ATC40.(['segment_',num2str(i_Segment)])(i_level_Segment_pj,1) > S_d_pj_gemittelt
                                           i_level_Segment_pj = i_level_Segment_pj - 1;
                                       end
                                  % c) Jetzt beinhaltet "i_level_Segment_pj" IMMER den letzten "echten" Punkt,
                                  %    der VOR dem gemittelten Punkt liegt und die Interpolation der zum gemittelten 
                                  %    Punkt korresp. Spektralbeschleunigung kann immer gleich erfolgen
                                       S_d_links = CS_ATC40.(['segment_',num2str(i_Segment)])(i_level_Segment_pj,1);
                                       S_d_rechts = CS_ATC40.(['segment_',num2str(i_Segment)])(i_level_Segment_pj+1,1);
                                       S_a_links = CS_ATC40.(['segment_',num2str(i_Segment)])(i_level_Segment_pj,2);
                                       S_a_rechts = CS_ATC40.(['segment_',num2str(i_Segment)])(i_level_Segment_pj+1,2);
                                       S_a_pj_interpoliert = S_a_links + (S_a_rechts-S_a_links)/(S_d_rechts-S_d_links) * (S_d_pj_gemittelt - S_d_links);
                              else
                                  % Fall: Der gemittelte Punkt liegt genau
                                  % in der Definitionslücke zwischen den
                                  % Segmenten i_Segment & i_Segment + 1
                                  % a) Dann ist der letzte "echte" Punkt vor dem gemittelten in
                                  %    in dem aktuellen Segment der letzte
                                       i_level_Segment_pj = n_level_vorh(i_Segment);
                                  % b) Und die Interpolation der zum gemittelten Punkt
                                  %    korresp. Spektralbeschleunigung läuft wie folgt ab
                                       S_d_links = max(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1));
                                       S_d_rechts = min(CS_ATC40.(['segment_',num2str(i_Segment+1)])(:,1));
                                       S_a_links = max(CS_ATC40.(['segment_',num2str(i_Segment)])(:,2));
                                       S_a_rechts = min(CS_ATC40.(['segment_',num2str(i_Segment+1)])(:,2));
                                       S_a_pj_interpoliert = S_a_links + (S_a_rechts-S_a_links)/(S_d_rechts-S_d_links) * (S_d_pj_gemittelt - S_d_links); 
                              end
                        % (S_d_pj_gemittelt | S_a_pj_interpoliert) als
                        % neuen Test-PP ansetzen
                        S_d_pj(i_iteration+1) = S_d_pj_gemittelt;
                        S_a_pj = S_a_pj_interpoliert;
                        % Schleife über alle Segmente abbrechen
                        break
                    end
                end
            else
                % Fall: KEIN Alternieren von S_d_pj & S_d_PP
                % Neuen Schätzer definieren
                S_d_pj(i_iteration+1) = S_d_PP;
                S_a_pj = S_a_PP;
                % Das zugehörige Pushover-Segment sowie den Lastniveau-Index innerhalb dieses 
                % Segments (als Zusatzinfo) für die nächste Iterationsschleife merken
                %{
                Eigentlich liest man hierbei den letzten SCHRITT vor dem letzten PP aus, denn dieser liegt ja
                i. Allg. nie wirklich auf einem tats. Punkt des Kapazitätsspektrums, welcher sich einem
                konkreten Lastniveau zuordnen ließe. Allerdings entspricht der Index dieses letzten Schrittes
                genau DEM Index des letzten "echten" Lastniveaus bzw. Punktes des Kapazitätsspektrums,
                von dem aus bis zum neuen Test-Performance Punkt linear "extrapoliert" wird bei der
                Berechnung von A_soll!!!
                %}
                i_Segment_pj = i_segment_CS - 1; % -1, da dieser Wert am Ende noch einmal um 1 erhöht wurde, bis dann die while-Schleife abgebrochen wurde
                i_level_Segment_pj = i_section_CS; % (dieser wird am Ende NICHT noch einmal um 1 erhöht)                
            end
        end
    else
        % Fall: Es wurde KEIN potenzieller PP gefunden!!!
        % (sprich überhaupt kein Schnittpunkt)
        % => Nun sind zwei Fälle möglich:
        % A: Der Test-PP war der letzte Punkt des Kapazitätsspektrums (z. B.
        %    im ersten Iterationsschritt wenn der default-Schätzer verwendet
        %    wurde). Dann sind Hopfen und Malz verloren (denn dann gibt es
        %    für weiter links liegende Schätzer mit weniger Hystereseenergie
        %    erst Recht keinen Schnittpunkt)!!!
        % B: Der Test-PP war ein anderer Punkt. Dann gehen wir nun in die
        %    Mitte zwischen letztem erfolgreichem Schätzer, so es schon einen
        %    gibt (erfolgreich heißt: der einen Schnittpunkt hervorgebracht
        %    hat), und dem letzten (nun eben erfolglosen) Schätzer!
        if i_Segment_pj == n_segmente_vorh && i_level_Segment_pj == n_steps_vorh(i_Segment_pj)
            % FALL A
            % -> Ende der PP-Ermittlung (denn es geht ja jetzt nicht um einen neuen Iterationsschritt zur
            %    Erfüllung des obigen 5%-Kriteriums auf Basis des letzten Schnittpunkts als neuen PP-Schätzer)!
            i_iteration = max_iteration + 1; % Einfach so tun, als hätte man "max_iteration" schon überschritten!
        else
            % FALL B
            % -> Prüfen, ob es schon einen erfolgreichen letzten Schätzer
            %    gibt
            if exist('i_Segment_pj_schnpkt','var') && exist('i_level_Segment_pj_schnpkt','var')
                % Fall: Ja, es wurde vorher schonmal ein Schnittpunkt gefunden
                % -> Dann in die Mitte zwischen diesem und dem aktuellen
                % Schätzer gehen mit dem neuen Schätzer (Mitte heißt:
                % geometrisch bezogen auf die Spektralverschiebungen)
                % (1) Gemittelte Spektralverschiebung berechnen
                S_d_pj(i_iteration+1) = (S_d_Schnpkt + S_d_pj(i_iteration)) / 2; % S_d_pj(i_iteration) ist ja jetzt die Spektralverschiebung des aktuellen/letzten Schätzers
                % (2) Das zugehörige CS-Segment und das dort zugehörige interne
                % Lastniveau desjenigen Punktes herausfinden, der am
                % nächsten an dieser gemittelten Spektralverschiebung liegt
                % -> Schleife über alle Segmente des Kapazitätsspektrums
                for i_Segment = 1:n_segmente_vorh
                    % Prüfen, ob die gemittelte Spektralverschiebung in
                    % diesem Segment liegt
                    if S_d_pj(i_iteration+1) >= min(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1)) && S_d_pj(i_iteration+1) <= max(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1))
                        % Segment merken
                        i_Segment_pj = i_Segment;
                        % Und nun den Punkt heraussuchen, der am nächsten an
                        % S_d_pj liegt
                        i_level_Segment_pj = finde_aehnlichsten(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1),S_d_pj(i_iteration+1));
                        % Schleife über alle Segmente abbrechen
                        break
                    end
                    % (In irgendeinem Segment muss er liegen, deswegen
                    % braucht man keinen "else"-Fall!)
                end      
            else
                % Fall: Es gibt keinen bisherigen Schnittpunkt! Dann kann
                % man leider nichts machen!
                % -> Ende der PP-Ermittlung (denn es geht ja jetzt nicht um einen neuen Iterationsschritt zur
                %    Erfüllung des obigen 5%-Kriteriums auf Basis des letzten Schnittpunkts als neuen PP-Schätzer)!
                i_iteration = max_iteration + 1; % Einfach so tun, als hätte man "max_iteration" schon überschritten!
            end
        end
    end
end
% -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
% -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------   


%% Falls die iterative Ermittlung des Performance Punktes nach der Kapaztitässpektrum-Methode gescheitert ist -> Notlösung:
if ~flag_PP
    % 1.) Warnung ausgeben
    fprintf(2,sprintf('\nNo PP could be found in the "conventional way" (by means of iteration using the CSM)!\nTherefore, as an "emergency solution", an attempt is now being made to find a PP by setting all points of the capacity spectrum as test PPs one after the other. This may take a long time!!!\n'))
    % 2.) Performance Punkt versuchen zu ermitteln, indem alle Punkte des
    % Kapazitätsspektrums (nach dem Ursprung (0|0)) stumpf nacheinander als
    % Schätzer angesetzt werden
    [arg,flag_PP_notloesung,RS_S_d_n_red,RS_S_a_n_red] = sub_determine_PP_notloesung(arg,CS_ATC40,HB,n_segmente_vorh,n_level_vorh);
end


%% Zwischenschritt: Speichernamen zusammenbasteln
[sap_filepath,sap_name,~] = fileparts(arg.info.sap_file);
if arg.comp.adaptive == 1 && arg.comp.auto_run == 1
    save_name = ['adaptiv_auto_schritt_' num2str(arg.info.nummer)];
elseif arg.comp.adaptive == 1 && arg.comp.auto_run == 0
    save_name = ['adaptiv_schritt_' num2str(arg.info.nummer)];
else
    save_name = '';
end


%% Wenn PP gefunden: Zusatzinfos ermitteln & Konsolenausgabe
% Kleiner Zwischenschritt: Verwendete Einheiten auslesen
units = strsplit(modell.ProgramControl.CurrUnits{1,1},',');
for i_unit = 1:1:size(units,2)
    units(1,i_unit) = {strrep(units{1,i_unit},' ','')};
end
einheit_laengen = units{1,2}; % Längeneinheit des SAP2000-Modells selbst (i. d. R. 'm'!)
einheit_kraefte = strrep(units{1,1},'K','k'); % Krafteinheit des SAP2000-Modells selbst (i. d. R. 'kN'!); Falls es kN sind, steht dort jedoch "KN", daher strrep(...)!
einheit_beschl = 'm/s^2'; % die (Spektral-)Beschleunigungen haben immer die Einheit m/s² (gem. F = m*a, ich kann in SAP2000 z. B. KN vorgeben, dann rechnet er mit Tonnen und dazwischen stehen eben Beschl. in m/s²)

%{
Zum Performance Punkt korresp. Pushover-Segment und segmentinternen Lastniveau-Index ermitteln & Kontrollknotenverschiebung sowie Fundamentschub
im Performance Zustand ermitteln und alle relevanten Informationen im Feld "Performance_Punkt" (der arg-Struktur) speichern
%}
if flag_PP || flag_PP_notloesung % d. h., es wurde ein PP gefunden
    if flag_PP
        % FALL 1: PP über "normale" Iteration (nach der
        % Kapazitätsspektrum-Methode) ermittelt
        % Zum Performance Punkt korresp. Pushover-Segment
        i_segment_PP = i_segment_CS - 1; % -1, da dieser Wert am Ende noch einmal um 1 erhöht wird, bis dann die while-Schleife abgebrochen wird
        % Zum Performance Punkt korresp. LastSCHRITT-Index (innerhalb des Pushover-Segments)
        i_step_Segment_PP = i_section_CS; % (dieser wird am Ende NICHT noch einmal um 1 erhöht)
        % -> Performance Punkt selbst speichern unter arg.comp.pp
        arg.comp.pp.s_a_PP = S_a_PP;
        arg.comp.pp.s_d_PP = S_d_PP;
        % -> Zugehörigen Lastschritt-Index und Segment speichern unter arg.comp.pp
        arg.comp.pp.lastschritt_und_segment = [i_step_Segment_PP, i_segment_PP];
        % -> Kontrollknotenverschiebung und Fundamentschub speichern unter arg.comp.pp
        %{
        Hinweis: Betragfunktion, also abs(), bei delta_kk da VZ von beta irgendwie willkürlich; Skalierungsfaktor von PHI kürzt sich hier bei beta * PHI nicht "sauber" heraus!
                 Und selbst wenn beta korrekt ermittelt und sagen wir positiv wäre, PHI_i(mp) aber negativ, schadet die Betragsfunktion auch nicht, dann sind halt
                 die Spektralordinaten IMMER positiv (unabh. von der Richtung von DELTA_kk bzw. von F_B), das ist in meinen Augen sowieso sinnvoller als negative
                 Spektralverschiebungen oder -beschleunigungen anzusetzen!
        %}
        % Rücktransformation je nach Fall: adaptiv/nicht adaptiv
        % bzw. im Fall adaptiv je nach Fall: PP im ersten Segment oder nicht
        if arg.comp.adaptive == 0 || i_segment_PP == 1
            % Fall: Der Performance Punkt liegt im ersten (ggf. einzigen)
            % Segment
            arg.comp.pp.delta_kk_pp = abs(S_d_PP * arg.comp.cs.zusatzinfos.beta(i_segment_PP) * arg.comp.cs.zusatzinfos.phi_kk_Rp(i_segment_PP));
            arg.comp.pp.F_B = S_a_PP * arg.comp.cs.zusatzinfos.m_eff(i_segment_PP);
        else
            % Fall: Der Performance Punkt liegt in einem beliebigen Segment
            % i_segment_PP > 1
            % Hilfsgrößen auslesen
            delta_kk_Seg_vorherig_end = arg.comp.pushoverkurve.(['segment_',(num2str(i_segment_PP-1))])(end,1);
            F_B_Seg_vorherig_end = arg.comp.pushoverkurve.(['segment_',(num2str(i_segment_PP-1))])(end,2);
            S_d_Seg_vorherig_end = arg.comp.cs.(['segment_',(num2str(i_segment_PP-1))])(end,1);
            S_a_Seg_vorherig_end = arg.comp.cs.(['segment_',(num2str(i_segment_PP-1))])(end,2);
            beta_i_segment_PP = arg.comp.cs.zusatzinfos.beta(i_segment_PP);
            phi_kk_Rp_i_segment_PP = arg.comp.cs.zusatzinfos.phi_kk_Rp(i_segment_PP);
            m_eff_i_segment_PP = arg.comp.cs.zusatzinfos.m_eff(i_segment_PP);
            % Kontrollknotenverschiebung und Fundamentschub berechnen
            arg.comp.pp.delta_kk_pp = delta_kk_Seg_vorherig_end + abs((S_d_PP - S_d_Seg_vorherig_end) * beta_i_segment_PP * phi_kk_Rp_i_segment_PP); % abs(), da VZ von beta irgendwie willkürlich; Skalierungsfaktor von PHI kürzt sich hier bei beta * PHI nicht "sauber" heraus!
            arg.comp.pp.F_B = F_B_Seg_vorherig_end + (S_a_PP - S_a_Seg_vorherig_end) * m_eff_i_segment_PP;
        end
        % -> Effektives Dämpfungsmaß im Performance-Zustand speichern unter arg.comp.pp
        arg.comp.pp.xi_eff = arg.comp.xi_eff;
    end % (Im Fall 2, der PP-Ermittlung über die "Notlösung", wurden die obigen Übergaben an die "arg"-Struktur in der entspr. Subroutine bereits durchgeführt, daher ist hier kein "else"-Fall nötig!)
    % -> Konsolenausgabe
    % Leerzeile
    disp(' ');
    % Performance Punkt selbst
    disp('The following performance point was found:')
    disp(['(S_d,PP | S_a,PP) = (',num2str(arg.comp.pp.s_d_PP),' ',einheit_laengen,' | ',num2str(arg.comp.pp.s_a_PP),' ',einheit_beschl,')'])
    % sowie effektive Eigenperiode (auf Basis der Sekantensteigung von
    % omega_eff^2 bis zum PP)
    disp(['Corresponding effective eigenperiod: T_eff = ',num2str(2*pi/(sqrt(arg.comp.pp.s_a_PP/arg.comp.pp.s_d_PP))),' s.'])
    % Lastschritt und Pushover-Segment
    disp(['(Pushover segment: ',num2str(arg.comp.pp.lastschritt_und_segment(2)),', Lastschritt: ',num2str(arg.comp.pp.lastschritt_und_segment(1)),')'])
    disp(['This corresponds to a monitored displacement of ',num2str(arg.comp.pp.delta_kk_pp),' ',einheit_laengen])
    disp(['and a base shear of ',num2str(arg.comp.pp.F_B),' ',einheit_kraefte,'.'])
    % Effektive Dämpfung
    disp(['The effective damping in this step was ',num2str(arg.comp.pp.xi_eff),' %.'])  
    % arg.comp.pp.erfolg belegen
    arg.comp.pp.erfolg = 1;
else
    % Falls kein PP gefunden werden konnte:
    % Warnung ausgeben!
    fprintf(2,'No performance point was found!\n')
    fprintf(2,'If the capacity spectrum and the last reduced response spectrum intersect optically, more intermediate steps may have to be calculated for a higher resolution of the capacity spectrum!\n')
    % arg.comp.pp.erfolg belegen
    arg.comp.pp.erfolg = 0;
    % Ggf. Trauer-Jingle
    if ismember(arg.info.sound,[0,0.5])
        try
            [y,Fs] = audioread('jingle_caap_fail.mp3');
            sound(y,Fs);
        catch
            fprintf(2,'Unfortunately the jingle could not be played!\n')
        end
    end
end


%% Ggf.: Plot der drei Kurven (transf. Kapazitätsspektrum, nicht abgemindertes sowie letztes abgemindertes tranfs. Antwortspektrum) im gemeinsamen Sa-Sd-Diagramm
% Prüfen, ob Plot gewünscht
if arg.info.console == 1

    % (1) Kapazitätsspektrum plotten
    % Figure aufmachen und "Vorarbeit"
    figure('name','Sa-Sd diagram');
    hold on;
    color_index = 1:n_segmente_vorh;
    % Segmentweise (farbig & etwas dicker) plotten
    for i_segment = 1:n_segmente_vorh
        % Plotfarbe des aktuellen Segments
        color = arg.info.cmap(color_index(1,i_segment),:);
        % Plotten
        plot(...
            arg.comp.cs.(['segment_' num2str(i_segment)])(:,1),...
            arg.comp.cs.(['segment_' num2str(i_segment)])(:,2),...
            'Linewidth',2,'color',color)
    end
    
    % (2) Transformiertes Antwortspektrum plotten
    % 2a) Gestrichelter, dünner Plot des transformierten, NICHT ABGEMINDERTEN elastischen Antwortspektrums
        % << Zwischenschritt: Nicht mit xi_eff, sondern nur mit xi_0 gedämpftes transformiertes Antwortspektrum ermitteln
        % arg.comp.xi_eff zwischenspeichern
        arg_ber_xi_eff_save = arg.comp.xi_eff;
        % Jetzt so tun, als ob man ganz am Anfang (mit xi_eff = xi_0) wäre
        arg.comp.xi_eff = arg.comp.xi_0;
        % Aufbau des nur mit xi_0 gedämpften elastischen Antwortspektrums
        arg = caap_el_accel_response_spectrum(arg);
        if strcmp(arg.rs.richtung,'horizontal')
            RS_S_a_n = arg.rs.s_a_horizontal;
        else
            RS_S_a_n = arg.rs.s_a_vertikal;
        end
        % arg.comp.xi_eff wieder berichtigen
        arg.comp.xi_eff = arg_ber_xi_eff_save;
        % Spektralverschiebungen aus den Eigenperioden T ermitteln
        RS_S_d_n = RS_S_a_n ./ (2*pi ./ arg.rs.t).^2; % Spektralverschiebungen des Antwortspektrums (via Transformation der Eigenperiodenwerte T_i)
        % Ende: Zwischenschritt >>
    plot(RS_S_d_n,RS_S_a_n,'--','LineWidth',1.5,'Color',[0.6350, 0.0780, 0.1840]);
    % 2b) Plot des letzten (abgeminderten elastischen) Antwortspektrums
    plot(RS_S_d_n_red,RS_S_a_n_red,'LineWidth',2,'Color',[0.8500 0.3250 0.0980]); 
    
    % (3) Performance Punkt markieren (sofern dieser gefunden wurde)
    if flag_PP || flag_PP_notloesung % d. h., es wurde ein PP gefunden
       plot(arg.comp.pp.s_d_PP,arg.comp.pp.s_a_PP,'o','MarkerSize',8,'MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[0.9290 0.6940 0.1250]);
    end
    
    % (4) Nachbereitung
    % Gitternetz einblenden
    grid()
    % Achsen-Beschriftung & Titel hinzufügen
    xlabel(sprintf('$S_{d,%s}~[%s]$',arg.comp.d_earthquake{1,1},einheit_laengen),'interpreter','latex')
    ylabel(sprintf('$S_{a,%s}~[%s]$',arg.comp.d_earthquake{1,1},einheit_beschl),'interpreter','latex')
    title('Determination of the performance point (PP)','interpreter','latex')
    set(gca,'TickLabelInterpreter','latex')
    hold off
    
    % (5) Figure speichern, wenn PP gefunden
    savefig(gcf,[sap_filepath,'\Sa_Sd_diagram_with_PP.fig'])
end

end




%% Subfunktion zur Notlösung: "Performance Punkt"-Ermittlung durch schleifenmäßigen Ansatz aller Punkte des Kapazitätsspektrums als Schätzer bis man einen PP gefunden hat
function [arg,flag_PP_notloesung,RS_S_d_n_red,RS_S_a_n_red] = sub_determine_PP_notloesung(arg,CS_ATC40,HB,n_segmente_vorh,n_level_vorh)
% Vorbelegung der Erfolgsflagge
flag_PP_notloesung = 0;
% Übergeordnete Schleife über alle Segmente des Kapazitätsspektrums
for i_Seg_CS = 1:n_segmente_vorh
    % Untergeordnete Schleife über alle Punkte dieses Segments
    for i_Pkt_Seg_CS = 1:n_level_vorh(i_Seg_CS)
        % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        % (0.1) Zweisegmentige Linearisierung des Kapazitätsspektrums bis zum
        % Aktuellen Punkt des Kapazitätsspektrums auslesen und als Schätzer für den PP ansetzen
        S_d_pj = CS_ATC40.(['segment_',num2str(i_Seg_CS)])(i_Pkt_Seg_CS,1);
        S_a_pj = CS_ATC40.(['segment_',num2str(i_Seg_CS)])(i_Pkt_Seg_CS,2);
        % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        % (0.2) % Weitere Vorbereitungen für den aktuellen Iterationsschritt (mit dem aktuellen Test-Performance Punkt (S_d_pj | S_a_pj) 
        % Flag setzen, die anzeigt: Schnittpunkt (kurz SP) beider Kurven noch nicht gefunden
        flag_SP = 0;
        % Startwert von (im Vergleich zum untergeordneten Zähler 2 der Pushover-Segmente) übergeordnetem Zähler 1 ('i_section_RS') auf 1 setzen
        i_section_RS = 1;
        % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        % (1) Zweisegmentige Linearisierung des Kapazitätsspektrums bis zum
        %     Test-Performance Punkt
        % Anfangssteigung des Kapazitätsspektrums über Steigungsdreieck
        % zw. den Punkten 1 und 2, mit Punkt 1 = (0|0)
        k_0 = CS_ATC40.segment_1(2,2)/CS_ATC40.segment_1(2,1); % Zeile 2: Punkt 2 (Spalte 1: S_d_n, Spalte 2: S_a_n)
        % Flächeninhalt unter dem Kapazitätsspektrum bis zum Test-Performance Punkt
        % (segmentweise integrieren bis zum Segment)
        A_soll = 0; % Vorbelegung
        % Als erstes eine Schleife über alle "vollständig abzugrasenden" Segmente
        for i_Segment = 1:(i_Seg_CS - 1)
            % Beim ersten Segment kommt noch das Trapez vom Punkt (0|0) bis zum
            % ersten gespeicherten Spektralpunkt hinzu
            if i_Segment == 1
                A_soll = A_soll + trapz([0; CS_ATC40.(['segment_',num2str(i_Segment)])(:,1)],[0; CS_ATC40.(['segment_',num2str(i_Segment)])(:,2)]); % alle Zeilen: alle Punkte; Spalte 1: S_d_n, Spalte 2: S_a_n
            else
                % Bei allen weiteren Segmenten wird allerdings das Trapez vom letzten Punkt
                % des letzten Segments bis zum ersten Punkt des aktuellen Segments
                % nicht mit angesetzt, da diese beiden Punkte jew. identisch sind.
                % (Zwar wäre der Flächeninhalt dann eigentlich eh 0, aber sicher ist sicher.)
                A_soll = A_soll + trapz(CS_ATC40.(['segment_',num2str(i_Segment)])(:,1),CS_ATC40.(['segment_',num2str(i_Segment)])(:,2)); % alle Zeilen: alle Punkte; Spalte 1: S_d_n, Spalte 2: S_a_n
            end
        end
        % Nun als zweites das letzte Segment, in dem der Test-PP liegt, bis zu
        % ebendiesem Punkt (S_d_pj | S_a_pj) integrieren
        A_soll = A_soll + trapz([CS_ATC40.(['segment_',num2str(i_Seg_CS)])(1:i_Pkt_Seg_CS,1); S_d_pj],...
            [CS_ATC40.(['segment_',num2str(i_Seg_CS)])(1:i_Pkt_Seg_CS,2); S_a_pj]); % alle Zeilen bis i_Pkt_Seg_CS: alle Punkte bis zum letzten vor dem Test-PP (Spalte 1: S_d_n, Spalte 2: S_a_n)
        % Spektralverschiebung S_d_y im effektiven Fließpunkt (y: "yielding") bestimmen
        S_d_y = (2 * A_soll - S_a_pj * S_d_pj) / (k_0 * S_d_pj - S_a_pj);
        % Spektralverschiebung im effektiven Fließpunkt daraus ableiten
        % (über das erste Segment der stückweise linearen Idealisierung)
        S_a_y = k_0 * S_d_y;
        % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        % (2) Ermittlung des effektiven Dämpfungsmaßes xi_eff sowie (darauf
        %     aufbauend) des abgeminderten elastischen Antwortspektrums
        % Maximale Dehnungsenergie E_So ermitteln
        E_So = (S_d_pj * S_a_pj) / 2; % (vgl. ATC40 (1996), S. 8-15)
        % Hystereseenergie E_D ermitteln
        % E_D darf nicht negativ sein
        % im linear-elastischen Bereich kann das auf Grund von numerischen
        % Ungenauigkeiten aber vorkommen
        E_D = max([0,4 * (S_a_y * S_d_pj - S_d_y * S_a_pj)]); % (vgl. ATC40 (1996), S. 8-15)
        % Äquivalentes viskoses Dämpfungsmaß daraus ableiten
        xi_eq = 1/(4*pi) * E_D/E_So; % [-] (vgl. ATC40 (1996), Gl. 8-5a)
        % Korrekturfaktor Kappa(xi_eq) nach ATC40 (1996), Tabelle 8-1
        switch HB
            case 'A' % stabile Hystereseschleifen (hohe Energiedissipation)
                if xi_eq <= 0.1625
                    Kappa = 1.0;
                else
                    Kappa = 1.13 - 0.51 * ((S_a_y * S_d_pj - S_d_y * S_a_pj) / (S_a_pj * S_d_pj));
                end
            case 'B' % relativ gering eingeschnürte Hystereseschleifen
                if xi_eq <= 0.25
                    Kappa = 0.67;
                else
                    Kappa = 0.845 - 0.446 * ((S_a_y * S_d_pj - S_d_y * S_a_pj) / (S_a_pj * S_d_pj));
                end
            case 'C' % stark eingeschnürte Hystereseschleifen
                Kappa = 0.33;
        end
        % Damit ergibt sich das effektive (Gesamt-)Dämpfungsmaß zu
        arg.comp.xi_eff = arg.comp.xi_0 + Kappa * xi_eq*100; % [%]!!! (vgl. ATC40 (1996), Gl. 8-8)
        % Aufbau des abgeminderten elastischen Antwortspektrums
        arg = caap_el_accel_response_spectrum(arg);
        % Transformation des abgeminderten elastischen Antwortspektrums
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
        % ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        % (3) Schnittpunkt der beiden Spektren ermitteln (im allerersten Iterationsschritt ist das Antwortspektrum noch nicht abgemindert!)
        % Übergeordnete Schleife über alle "Teilstücke" ("sections") des Antwortspektrums
        while ~flag_SP && i_section_RS <= size(RS_S_a_n_red,2)-1 % (-1, da ein Teilstück weniger als Punkte)
            % Startwert des untergeordneten Zählers 2 'i_segment_CS' immer wieder (bei jedem neuen übergeordneten
            % Schleifendurchlauf der Antwortspektrum-Schleife) auf 1 setzen!
            i_segment_CS = 1; % Zähler des Pushover-Segments (bei nicht-adaptiven Ber. immer = 1)
            % Untergeordnete Schleife über alle "Pushover-Segmente" ("segment") des Kapazitätsspektrums
            while ~flag_SP && i_segment_CS <= n_segmente_vorh
                % Startwert des untergeordneten Zählers 3 'i_section_CS' immer wieder (bei jedem neuen übergeordneten
                % Schleifendurchlauf der Kapazitätsspektrum-Segment-Schleife) auf 1 setzen!
                i_section_CS = 1; % Zähler des Pushoverschrittes bzw. "Teilstücks" INNERHALB des aktuellen Segments des segmentweise definierten (zusammengesetzten) Kapazitätsspektrums
                % Untergeordnete Schleife über alle "Teilstücke" ("section") des Kapazitätsspektrum-Segments
                while ~flag_SP && i_section_CS <= n_level_vorh(i_segment_CS)-1 % (-1, da ein Teilstück weniger als Punkte)
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
                    s21 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,1); % Ortsvektor-Komponente
                    r21 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS + 1,1) - CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,1); % Richtungsvektor-Komponente
                    s22 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,2); % Ortsvektor-Komponente
                    r22 = CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS + 1,2) - CS_ATC40.(['segment_',num2str(i_segment_CS)])(i_section_CS,2); % Richtungsvektor-Komponente
                    % Theoretischen Schnittpunkt der zunächst unendlich langen Geraden
                    % ermitteln
                    vec_f = 1 / (-r11*r22 + r12*r21) * [-r22 r21; -r12 r11] * [(s21 -s11); (s22 -s12)];
                    % Prüfen, ob die Skalierungsfaktoren beide zwischen 0 und 1 liegen
                    % (dann ist der theoretische auch ein praktischer Schnittpunkt)
                    if 0 <= vec_f(1) && vec_f(1) <= 1 && 0 <= vec_f(2) && vec_f(2) <= 1
                        % Wenn ja -> Es wurde ein tatsächlicher Schnittpunkt innerhalb der beiden
                        % endlichen Teilstücke gefunden:
                        % Dann muss noch ausgeschlossen werden, dass es sich dabei um
                        % den Punkt (0|0) handelt:
                        % -> (Theor.) Performance Punkt auswerten
                        S_d_PP = s11 + vec_f(1) * r11;
                        S_a_PP = s12 + vec_f(1) * r12;
                        % Ursprung (0|0) des A-D-Diagramms ausschließen
                        if ~(S_d_PP == 0 && S_a_PP == 0)
                            % Theoretischer Performance Punkt ist
                            % (höchstwahrscheinlich) auch ein faktischer (sinnvoller)
                            % -> Alle Schleifen abbrechen!
                            flag_SP = 1; % Performance Punkt gefunden!
                        else
                            % Schade, dann muss doch weiter gesucht werden:
                            % -> Untergeordneten Schleifenzähler 3
                            % ('i_section_CS') um 1 erhöhen und weiter gehts
                            % mit dem nächsten Punkt innerhalb des aktuellen
                            % CS-Segments
                            i_section_CS = i_section_CS + 1;
                        end
                    else
                        % Wenn nein -> Untergeordneten Schleifenzähler 3 ('i_section_CS') um 1 erhöhen
                        % und weiter gehts mit dem nächsten Punkt innerhalb des aktuellen CS-Segments
                        i_section_CS = i_section_CS + 1;
                    end
                end
                % -> Inneren Schleifenzähler 2 ('i_segment_CS') um 1 erhöhen und weiter gehts
                % mit dem nächsten CS-Segment
                i_segment_CS = i_segment_CS + 1;
            end
            % -> Übergeordneten Schleifenzähler 1 ('i_section_RS') um 1 erhöhen und weiter gehts
            % mit dem nächsten Abschnitt des Antwortspektrums
            i_section_RS = i_section_RS + 1;
        end
        % --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        % (4) Wenn ein potenzieller PP gefunden wurde: 5%-Grenzkriterium nach ATC40, S. 8-20 prüfen
        if exist('S_d_PP','var')
            % Fall: Es wurde ein potenzieller PP gefunden
            if 0.95*S_d_pj <= S_d_PP && S_d_PP <= 1.05*S_d_pj
                % Es wurde ein gültiger Performance Punkt gefunden!
                flag_PP_notloesung = 1;
                % Ggf. akkustische Eskalation
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
                        fprintf(2,'Unfortunately the jingle could not be played!\n')
                    end
                end
                % Entsprechende Ergebnisse an die "arg"-Struktur übergeben
                % -> Performance Punkt selbst speichern unter arg.comp.pp
                arg.comp.pp.s_a_PP = S_a_PP;
                arg.comp.pp.s_d_PP = S_d_PP;
                % -> Zugehörigen Lastschritt-Index und Segment speichern unter arg.comp.pp
                arg.comp.pp.lastschritt_und_segment = [i_Pkt_Seg_CS, i_Seg_CS];
                % -> Kontrollknotenverschiebung speichern unter arg.comp.pp
                %{
                Hinweis: Betragfunktion, also abs(), da VZ von beta irgendwie willkürlich; Skalierungsfaktor von PHI kürzt sich hier bei beta * PHI nicht "sauber" heraus!
                         Und selbst wenn beta korrekt ermittelt und sagen wir positiv wäre, PHI_i(mp) aber negativ, schadet die Betragsfunktion auch nicht, dann sind halt
                         die Spektralordinaten IMMER positiv (unabh. von der Richtung von DELTA_kk bzw. von F_B), das ist in meinen Augen sowieso sinnvoller als negative
                         Spektralverschiebungen oder -beschleunigungen anzusetzen!
                %}
                arg.comp.pp.delta_kk_pp = abs(S_d_PP * arg.comp.cs.zusatzinfos.beta(i_Seg_CS) * arg.comp.cs.zusatzinfos.phi_kk_Rp(i_Seg_CS));
                % -> Effektives Dämpfungsmaß im Performance-Zustand speichern unter arg.comp.pp
                arg.comp.pp.xi_eff = arg.comp.xi_eff;
                % Fundamentschub ausrechnen
                % Wenn PP im Segment 1
                if i_Seg_CS == 1
                    arg.comp.pp.F_B = S_a_PP * arg.comp.cs.zusatzinfos.m_eff(1);
                else
                    S_a_Seg_vorherig_end = arg.comp.cs.(['segment_',(num2str(i_Seg_CS-1))])(end,2);
                    F_B_Seg_vorherig_end = arg.comp.pushoverkurve.(['segment_',(num2str(i_Seg_CS-1))])(end,2);
                    arg.comp.pp.F_B = F_B_Seg_vorherig_end + (S_a_PP - S_a_Seg_vorherig_end) * arg.comp.cs.zusatzinfos.m_eff(i_Seg_CS);
                end
                % Untergeordnete for-Schleife über sämtliche Punkte des 
                % aktuellen KapazitätsspektrumSSegments abbrechen
                break
            end
        else
            % Wenn nicht: Bei dieser "Notlösungs-Schleife" nichts tun, die
            % Schleife geht dann ja autom. zum nächsten Punkt des
            % Kapazitätsspektrums als neuen Test-PP über...
        end
        % --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    end % for i_Pkt_Seg_CS = 1:n_level_vorh(i_Seg_CS)
    % Prüfen, ob die übergeordnete Schleife über alle
    % Kapazitätsspektrum-Segmente abgebrochen werden kann
    if flag_PP_notloesung
        break
    end
end % for i_Seg_CS = 1:n_segmente_vorh

end

function arg = caap_locate_nodes(erg,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_locate_nodes(erg,arg)
%
% Ziel dieser Funktion ist es, die Knoten, die sich an geradlinigen
% Balkenelementen befinden, genau zu lokalisieren (Balkennummer, absolute
% und relative Länge). Dies ermöglicht es hinterher, über den Stab
% verteilte Einzellasten zu generieren und dem Modell hinzuzufügen.
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% Main

% Lokale Variablen für die Knoten zusammenbauen
% Knotenlabels; X-Koordinate; Y-Koordinate; Z-Koordinate
knoten = erg.AssembledJointMasses.Werte(1:end-3,[1,9:11]);

% Lokale Variablen für die Balken zusammenbauen
% Balkenobjektlabel; Startknoten; Endknoten; Länge
balken = erg.ConnectivityFrame.Werte(:,[1:3,5]);

% Was ist Null?
zero_val = 1*10^(-10);

% Schleife über alle Balken
for i_Balken = 1:1:size(balken,1)
    
    % Transformierte Knoten mit den alten Daten vorbelegen
    knoten_trans = cellfun(@str2num,knoten(:,2:4));
    
    % Startknoten- und Endknotennummer extrahieren
    start_knoten_nr = balken(i_Balken,2);
    end_knoten_nr = balken(i_Balken,3);
    
    % Index des Startknotens bestimmen
    temp = strcmp(knoten(:,1),start_knoten_nr);
    [~,index_start] = max(temp);
    
    % Index des Endknotens bestimmen
    temp = strcmp(knoten(:,1),end_knoten_nr);
    [~,index_end] = max(temp);
    
    % Knoten-Koordinaten auf den Startknoten beziehen
    knoten_trans = knoten_trans - knoten_trans(index_start,:);
    
    % Winkel bestimmen
    % alpha = Rotation um die Z0-Achse
    if (abs(knoten_trans(index_end,2)) < zero_val) && (abs(knoten_trans(index_end,1)) < zero_val)
        alpha = 0;
    else
        alpha = atan(knoten_trans(index_end,2)/(knoten_trans(index_end,1)));
    end
    
    % beta =  Rotation aus der X0-Y0-Ebene heraus
    if (abs(knoten_trans(index_end,3)) < zero_val) && (abs((sqrt(knoten_trans(index_end,1)^2+knoten_trans(index_end,2)^2)))) < zero_val
        beta = 0;
    else
        beta = atan((knoten_trans(index_end,3))/(sqrt(knoten_trans(index_end,1)^2+knoten_trans(index_end,2)^2)));
    end
    
    % Transformationsmatrix
    Trans_M = [...
        cos(alpha)*cos(beta)     sin(alpha)*cos(beta)    sin(beta);...
        -sin(alpha)              cos(alpha)              0;...
        -cos(alpha)*sin(beta)    -sin(alpha)*sin(beta)   cos(beta)];
    
    % Knoten Transformieren
    knoten_trans = knoten_trans * Trans_M;
    
    % ggf. X-Achse umkehren
    if knoten_trans(index_end,1) < 0
        knoten_trans(:,1) = -knoten_trans(:,1);
    end
    
    % Y-Koordinate = 0
    Bed_1 = abs(knoten_trans(:,2)) < zero_val;
    
    % Z-Koordinate = 0
    Bed_2 = abs(knoten_trans(:,3)) < zero_val;
    
    % X-Koordinate >= X-Startknoten
    Bed_3 = ~(knoten_trans(:,1) < knoten_trans(index_start,1));
    
    % X-Koordinate <= X-Endknoten
    Bed_4 = ~(knoten_trans(:,1) > knoten_trans(index_end,1));
    
    % Knotennummern ermitteln, für die alle Bed. zutreffen
    knoten_gefunden = find(Bed_1 & Bed_2 & Bed_3 & Bed_4);
    
    % Punkt liegt auf dem Balken
    % Balkenlabel abspeichern
    knoten(knoten_gefunden,5) = repmat(balken(i_Balken,1),size(knoten_gefunden,1),1);
    
    % Relative Distanz abspeichern
    knoten(knoten_gefunden,6) = num2cell((knoten_trans(knoten_gefunden,1) ./ str2double(balken{i_Balken,4})));
    
    % Absolute Distanz berechnen und abspeichern
    knoten(knoten_gefunden,7) = num2cell(knoten_trans(knoten_gefunden,1));
    
end % Ende For-Schleife Balken

% Ausgabe-Struktur zusammenbauen
arg.comp.joint_lastverteilung = struct;
arg.comp.joint_lastverteilung.Inhalt = {'Joint','CenterX','CenterY','CenterZ','Frame','RelDist','AbsDist'};
arg.comp.joint_lastverteilung.Werte = knoten;
end
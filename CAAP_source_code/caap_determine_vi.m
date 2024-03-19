function arg = caap_determine_vi(arg)


%% Schleife über alle zu berücksichtigenden Moden

% Initiale und aktuelle Mode-Nr. des Bezugsmodes auslesen
ModeNr_B_initial = abs(arg.comp.modes.(arg.comp.d_earthquake{1,1})); % abs(), da Mode-Angabe ja auch negativ sein kann!
ModeNr_B_aktuell = arg.comp.modes_aktuell(1,1);


%% Ergebnisse der initialen sowie der neuen Modalanalyse auslesen und verarbeiten
% Ergebnisse nach Lastfällen sortieren
erg_schritt_0 = caap_sort_field(arg.comp.erg.schritt_0,'JointDisplacements','OutputCase');
erg_im_performance_zustand = caap_sort_field(arg.comp.erg.modalanalyse_im_performance_zustand,'JointDisplacements','OutputCase');
% Indizes der Zeilen in den modalen Knoten-Verformungen herausfinden, die sich auf
% den initialen (im Schritt 0) bzw. aktuellen (im Performance Zustand) Bezugsmode beziehen
indizes_Bezugsmode_initial_schritt_0 = find(cellfun(@str2num,erg_schritt_0.JointDisplacements.Werte.(arg.info.name_modal)(:,5)) == ModeNr_B_initial);
indizes_Bezugsmode_aktuell_performance_zustand = find(cellfun(@str2num,erg_im_performance_zustand.JointDisplacements.Werte.(arg.info.name_modal_new)(:,5)) == ModeNr_B_initial);
% Zum Bezugsmode korrespondierende Modalergebnisse extrahieren
Modalerg_Bezugsmode_schritt_0 = erg_schritt_0.JointDisplacements.Werte.(arg.info.name_modal)(indizes_Bezugsmode_initial_schritt_0,:);
Modalerg_Bezugsmode_performance_zustand = erg_im_performance_zustand.JointDisplacements.Werte.(arg.info.name_modal_new)(indizes_Bezugsmode_aktuell_performance_zustand,:);
% X-, Y- und Z-Translationen des Bezugsmodes in den beiden betrachteten
% Zuständen auslesen (und ggf. das VZ im Performance Zustand anpassen)
PHI_Bezugsmode_initial = cellfun(@str2num,Modalerg_Bezugsmode_schritt_0(:,6:8));
PHI_Bezugsmode_performance_zustand = cellfun(@str2num,Modalerg_Bezugsmode_performance_zustand(:,6:8)) * arg.comp.modes.SF(2,1); % arg.comp.modes.SF enthält in der zweiten Zeile der ersten Spalte den VZ-Korrekturfaktor des einen Modes im Schritt 2 (Performance Zustand)

% >> Zwischenschritt: Betraglich maximale Verschiebung des Bezugsmodes
%    (in seiner initialen Form sowie seiner Form im Performance Zustand) 
%    VORZEICHENGERECHT ermitteln, sodass bei beiden Vektoren nach der 
%    Normierung v_max immer = +1 ist!!!
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
v_massg_PHI_Bezugsmode_initial = unique(PHI_Bezugsmode_initial(abs(PHI_Bezugsmode_initial(:,:))==max(max(abs(PHI_Bezugsmode_initial(:,:)))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
                     % Tritt der betraglich maximale Wert positiv UND negativ auf,
                     % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
                     % sich bezieht, gewählt wird dann einfach der positive
                     if length(v_massg_PHI_Bezugsmode_initial) == 2
                         v_massg_PHI_Bezugsmode_initial = unique(abs(v_massg_PHI_Bezugsmode_initial));
                     end
v_massg_PHI_Bezugsmode_performance_zustand = unique(PHI_Bezugsmode_performance_zustand(abs(PHI_Bezugsmode_performance_zustand(:,:))==max(max(abs(PHI_Bezugsmode_performance_zustand(:,:)))))); % "unique(...)", falls exakt dieser betraglich maximale Wert mehrfach auftritt (jew. positiv ODER jew. negativ)!
                     % Tritt der betraglich maximale Wert positiv UND negativ auf,
                     % spielt es keine Rolle, auf welchen Wert (sprich welches VZ) man
                     % sich bezieht, gewählt wird dann einfach der positive
                     if length(v_massg_PHI_Bezugsmode_performance_zustand) == 2
                         v_massg_PHI_Bezugsmode_performance_zustand = unique(abs(v_massg_PHI_Bezugsmode_performance_zustand));
                     end
% (Ende: Zwischenschritt) >>

PHI_Bezugsmode_initial_norm = PHI_Bezugsmode_initial / v_massg_PHI_Bezugsmode_initial;
PHI_Bezugsmode_performance_zustand_norm = PHI_Bezugsmode_performance_zustand / v_massg_PHI_Bezugsmode_performance_zustand;


%% Variationsindex bezüglich der primären Bebenrichtung berechnen
% Spaltenindex für die primäre Bebenrichtung auslesen
Idx_Beben_primaer = arg.comp.d_earthquake{2,1};

% VI berechnen
arg.comp.vi_wert = abs(sum(PHI_Bezugsmode_performance_zustand_norm(:,Idx_Beben_primaer) - PHI_Bezugsmode_initial_norm(:,Idx_Beben_primaer))) / abs(sum(PHI_Bezugsmode_initial_norm(:,Idx_Beben_primaer))) * 100; % [%]

end
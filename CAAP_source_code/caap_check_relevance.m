function caap_check_relevance(arg)

%% Mini-Funktion zur Überprüfung, ob ein bestimmter Mode in einer Bebenrichtung "unsinnigerweise" berücksichtigt wurde (wenn dort die fiktiven Fundamentschubwerte aus "M*Vpunktpunkt_R*r" IN JEDEM SCHRITT = 0 waren)
% Übergeordnete Schleife über alle Bebenrichtungen
for i_R = 1:size(arg.comp.d_earthquake,2)
    % Alle in dieser Richtung angesetzten Moden auslesen
    Moden_R_akt = arg.comp.modes.(arg.comp.d_earthquake{1,i_R});
    % Untergeordnete Schleife über alle in dieser Richtung angesetzten Moden
    for i_Mode = length(Moden_R_akt)
        % Zwischenschritt: Index des aktuellen Modes in arg.comp.modes.unique ermitteln (für "Zugriff" in spaltenweise nach den uniquen Nummern sortierten arg.comp.modes.SF)
        ModeNr_akt_initial = abs(Moden_R_akt(i_Mode));
        Idx_Mode_i_in_moden_unique = find(arg.comp.modes.unique==ModeNr_akt_initial);
        % Prüfen, ob eventuell wirklich ALLE fiktiven Fundamentschübe
        % dieses Modes in dieser Richtung 0 waren
        if ~any(arg.comp.f_b_fictitious(Idx_Mode_i_in_moden_unique,i_R,:) ~= 0)
            % Kurze informative Warnung ausgeben
            fprintf(1,['\n INFO: The (initial) mode %d was taken into account in the %s direction, although the fictitious base shear values\n',...
                '       (according to M * ddot V_R * r) were 0 in ALL AMI steps!\n',...
                '-> The mode can therefore be disregarded in this direction when recalculating!\n'],ModeNr_akt_initial,arg.comp.d_earthquake{1,i_R})
        end
    end
end

end
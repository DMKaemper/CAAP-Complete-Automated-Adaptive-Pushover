function arg = caap_plot_pushover_curve(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_plot_pushover_curve(modell,arg)
%
%   Funktion zum Plot der PushOver-Kurve
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%%
% Neue figure erstellen
figure('name','PushOver-Kurve');
hold on;

% So viele Farben aus der Color-Map definieren, wie es Segmente gibt
cmap = jet(arg.info.nummer);

% Indizes der Farben
color_index = 1:arg.info.nummer;

% Vorbelegung: Rückgabe der Reihenfolge der Farben
cmap_return = zeros(arg.info.nummer,3);

% Welche Kurven sind alle vorhanden?
if arg.comp.adaptive == 0
    % Nicht adapativ: dann gibt es nur die Gesamtkurve (aus einem Segment)
    plot(...
        arg.comp.pushoverkurve.gesamt(:,1),...
        arg.comp.pushoverkurve.gesamt(:,2),...
        'Linewidth',2,'Linestyle','-','color',cmap(1,:));
    
    cmap_return(1,:) = cmap(1,:);
    
else
    % Sonst adaptiv
    
    % Nicht adaptive Initial-Kurve (gibt es allerdings NICHT im Fall "ami_c")
    % ABER ACHTUNG: Es kann ja durchaus sein, dass arg.info.procedure zwar
    % 'ami_c' ist, das aber nur seit einem der letzten Schritte, weil beim
    % 'ami_o'-Verfahren am Ende negative Spektralinkremente vorlagen.
    % Daher im Fall 'ami_c' prüfen, ob arg.info.ami_o_zu_ami_c existiert!!!
    if ~strcmp(arg.info.procedure,'ami_c') || isfield(arg.info,'ami_o_zu_ami_c')
        % Fall "standard" oder "ami_o" -> Dann gibt es eine Initial-Kurve
        plot(...
            arg.comp.pushoverkurve.initial(:,1),...
            arg.comp.pushoverkurve.initial(:,2),...
            'Linewidth',2,'Linestyle','--','color','k')
    end
    
    % Alle Segmente plotten
    for i_segment = 1:1:arg.info.nummer
        % Zufällige Farbe auswählen mittels
        % zufälligem Index von 1 bis Größe Color-Array
        i_color = randi([1,length(color_index)]);
       
        if i_segment == 1
            % Im ersten Segment
            % Einfach die korrespondierende Farbe auslesen und fertig 
            % (-> Keine Überprüfung bezüglich einer Ähnlichkeit erf.!)
            color = cmap(color_index(i_color),:);
        else
            % Ab dem zweiten Segment:
            % Letzte Farbe und potenzielle neue Farbe auslesen
            color_old = color;
            color_new_pot = cmap(color_index(i_color),:);
            % Überprüfen, ob sich die letzte und potenziell neue Farbe ähnlich
            % sind (anhand der Wurzel der Summe der quadratischen Abweichungen
            % der jeweiligen r-g-b-Anteile
            if sqrt(sum((color_old - color_new_pot).^2)) < 0.35
                % Wenn Farben zu ähnlich: Neue Farbe durch Spiegelung des
                % rgb-Codes generieren
                color = fliplr(color_new_pot);
                % Dann prüfen, ob es genau diese Farbe in der Colormap auch
                % gibt -> Dann den korresp. Index "sperren" für später
                Idx_color_vorh = find(and(and(ismember(cmap(:,1),color(1)),ismember(cmap(:,2),color(2))),ismember(cmap(:,3),color(3))));
                if ~isempty(Idx_color_vorh)
                    color_index(color_index==Idx_color_vorh) = [];
                end
            else
                % Wenn Farben nicht ähnlich:
                % Die korrespondierende Farbe speichern...
                color = color_new_pot;
                % und den zugehörigen Index in "color_index" löschen
                color_index(i_color) = [];
            end
        end
    
        % Farbe in Reihenfolge abspeichern
        cmap_return(i_segment,:) = color;
    
        % Plot
        plot(...
            arg.comp.pushoverkurve.(['segment_' num2str(i_segment)])(:,1),...
            arg.comp.pushoverkurve.(['segment_' num2str(i_segment)])(:,2),...
            'Linewidth',2,'color',color)
    
    end
    
end

% Einheiten ermitteln
units = strsplit(modell.ProgramControl.CurrUnits{1,1},',');
for i_unit = 1:1:size(units,2)
    units(1,i_unit) = {strrep(units{1,i_unit},' ','')};
end
units{1,1} = strrep(units{1,1},'K','k'); % Krafteinheit des SAP2000-Modells selbst (i. d. R. 'kN'!); Falls es kN sind, steht dort jedoch "KN", daher strrep(...)!

% Plot Eigenschaften
grid()
xlabel(sprintf('%s~(node~%s)~[%s]',lower(['U' mat2str(arg.comp.d_earthquake{2,1})]),arg.comp.kk,units{1,2}),'interpreter','latex')
ylabel(sprintf('$F_{b,%s}~[%s]$',arg.comp.d_earthquake{1,1},units{1,1}),'interpreter','latex')
title('Pushover curve','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
hold off

% Colormap ausgeben
arg.info.cmap = cmap_return;
end
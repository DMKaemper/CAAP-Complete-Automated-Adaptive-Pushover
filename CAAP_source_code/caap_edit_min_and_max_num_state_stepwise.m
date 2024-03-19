function arg = caap_edit_min_and_max_num_state_stepwise(arg,modell)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_edit_min_and_max_num_state_stepwise(arg,modell)
%   
%   Funktion zur Anpassung der min & max num states aller
%   nichtlinear-statischen Lastfälle im Zuge einer "ami_o"-Berechnung
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

% Cell-Array der LF-bezogenen NL Steps anlegen bzw. erweitern
if ~isfield(arg.comp,'min_num_state_stepwise')
    % Fall: MAX-Berechnung im AMI-Schritt 1: Jeweilige Cell-Arrays erstmal anlegen
    arg.comp.min_num_state_stepwise{1,1} = '5'; % Vertikallasten immer mit 5 Schritten rechnen
    arg.comp.max_num_state_stepwise{1,1} = '5'; % Vertikallasten immer mit 5 Schritten rechnen
    arg.comp.min_num_state_stepwise{2,1} = num2str(arg.comp.nl_steps(1)); % MAX-Berechnung immer mit der gewünschten Schrittanzahl!
    arg.comp.max_num_state_stepwise{2,1} = num2str(arg.comp.nl_steps(2)); % MAX-Berechnung immer mit der gewünschten Schrittanzahl!
    % => Eine Anpassung ist im ersten Schritt NUR notwendig bei der
    % Korrektur-Berechnung; sind hier aber noch bei der MAX-Berechnung.
else
    % Korrektur-Berechnung AMI-Schritt 1 ODER MAX- oder Korrektur-Berechnung AMI-Schritt i (> 1)
    % => Index des aktuellen und somit anzupassenden Pushover-LFs identifizieren
    Idx_LC_to_edit = find(strcmp(modell.Case0x2DStatic40x2DNonlinearParameters.Case,arg.info.name_pushover_old));
    % => Überprüfung, ob MAX- oder Korrekturberechnung
    if length(arg.comp.k) < arg.info.nummer
        % Fall: MAX-Berechnung (MAX-Berechnung immer mit einer optimierten Schrittanzahl!)
        % Referenz-Pfad auf Basis der MAX-Berechnungsdaten des letzten
        % Schrittes approximieren
        pfad_referenz_zu_weit = arg.comp.pushoverkurvendaten_maxber_tmp((arg.comp.pushoverkurve.grenzzustaende(arg.info.nummer-1).i_step_massg+1:end),:);
        DELTA_F_b_max_akt = sum(arg.comp.f_matrix_akt(:,arg.comp.d_earthquake{2,1})); % abs() nicht notwendig, da Algorithmus eh drauf achtet, dass alle Moden einen positiven resultierenden Fundamentschub in der primären Bebenrichtung aufweisen
        F_b_zuletzt = arg.comp.pushoverkurve.(['segment_',num2str(arg.info.nummer-1)])(end,2);
        F_b_max_akt = F_b_zuletzt + DELTA_F_b_max_akt;
        pfad_referenz = pfad_referenz_zu_weit(pfad_referenz_zu_weit(:,1)<F_b_max_akt,:);
        anz_Schritte = size(pfad_referenz,1)+1; % "+1", da ja der neue Endpunkt noch dazukommt
        % Auf Basis der nach der approximierten Referenzkurze notwendigen
        % Schrittzahl die Werte für "min & max num state" der aktuellen
        % MAX-Berechnung festlegen
        arg.comp.min_num_state_stepwise{Idx_LC_to_edit,1} = num2str(anz_Schritte); 
        arg.comp.max_num_state_stepwise{Idx_LC_to_edit,1} = num2str(ceil(anz_Schritte*1.1));
    else
        % Fall: Korrektur-Berechnung (Korrekturberechnung im ersten AMI-Schritt immer mit 20 Schritten, da Ast i. d. R. sehr lang; dannach mit 5 Schritten rechnen!)
        if arg.info.nummer == 1
            arg.comp.min_num_state_stepwise{Idx_LC_to_edit,1} = '20';
            arg.comp.max_num_state_stepwise{Idx_LC_to_edit,1} = '20';
        else
            arg.comp.min_num_state_stepwise{Idx_LC_to_edit,1} = '5';
            arg.comp.max_num_state_stepwise{Idx_LC_to_edit,1} = '5';
        end
    end
end

end
function [modell, arg] = caap_prepare(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   [modell, arg] = caap_prepare(modell,arg)
%   
%   Funktion zur Vorbereitung gewisser Argumente
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

% Ganz am Anfang mit arg.info.nummer ==1 
% (in allen weiteren Berechnungsschritten ist das überflüssig)
if arg.info.nummer == 1
    % Im Fall einer "Standard"-Berechnung:
    % Eingestellte Grenzverschiebung ermitteln
    if strcmp(arg.info.procedure,'standard')

        [i_pushover, ~, ~] = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),arg.info.name_pushover));
        v_grenz = modell.Case0x2DStatic20x2DNonlinearLoadApplication.TargetDispl{i_pushover,1};
        arg.comp.v_grenz = str2double(strrep(v_grenz,',','.'));
        arg.comp.v_target = arg.comp.v_grenz;

    end

    % Ferner in beiden Fällen ("Standard"- und modifizierte "AMI"-Berechnung):
    % Kontrollknoten auslesen
    % (dieser wird auch bei "Full Load" im Fall der modifizierten "AMI"-Ber. durch den
    % Benutzer bei der LoadCase-Definition angegeben)

    index = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case,arg.info.name_pushover));
    arg.comp.kk = modell.Case0x2DStatic20x2DNonlinearLoadApplication.MonitorJt{index,1};

    if isempty(arg.comp.kk)
        % Informative Ausgabe
        fprintf(2,'\n The monitoring point was not saved in the $2k file!\n')
        % While-Schleife, so lange, bis was eingetippt wurde, was sich in
        % einen Integer überführen lässt
        flag_Eingabe_ok = 0; % Noch keine verwertbare Eingabe
        while ~flag_Eingabe_ok
            % Eingabe-Aufforderung - ggf. mit akustischer Warnung
            if arg.info.sound == 0.5 || arg.info.sound == 1
                try
                    hupe('gong');
                catch
                    disp(' '); % Hier keine Ausgabe, dass versucht wurde, Sound abzuspielen...
                end
            end
            % Eingabe-Aufforderung
            eingabestring = input('Which node should be considered as monitoring point?\n -> mp = ','s');
            % Eingabe verarbeiten
            if ist_typ(str2double(eingabestring),'int')
                % Super Eingabe!
                flag_Eingabe_ok = 1;
                % n auswerten
                arg.comp.kk = eingabestring;
            end
        end
        % Hinweis: Eine Ausgabe über die Unterbrechungszeit durch die obige
        % Eingabe ist hier nicht erforderlich, da diese Eingabe wenn ganz
        % am Anfang erfolgt, das sollte der Benutzer noch mitbekommen!
    end

end
end
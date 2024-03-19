function modell = caap_check_model(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   modell = caap_check_model(modell,arg)
%   
%   Prüft Dinge im modell
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%% FrameHingeAssignments prüfen
if isfield(modell,'FrameHingeAssigns090x2DHingeOverwrites')
    flag_warning = 0;
    for i_frame = 1:1:size(modell.FrameHingeAssigns090x2DHingeOverwrites.LimNegStiff,1)
        value = str2double(modell.FrameHingeAssigns090x2DHingeOverwrites.LimNegStiff{i_frame,1});
        if value < 0 || value > 1
            flag_warning = 1;
            modell.FrameHingeAssigns090x2DHingeOverwrites.LimNegStiff(i_frame,1) = {'0.1'};
        end
    end
    if flag_warning == 1
        fprintf(1,['The value for the "Limiting Negative Stiffness Ratio" was not valid everywhere\n',...
                   '(nur von 0 bis 1) and was set to 0.1 for the corresponding beam elements.\n'])
    end
end


%% Prüfen, ob es den Pushover-LoadCase überhaupt gibt und ob die primäre Bebenrichtung mit der Richtung der "monitored displacement" übereinstimmt
case_nr = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case,arg.info.name_pushover));

if ~isempty(case_nr)
    dir_sap = modell.Case0x2DStatic20x2DNonlinearLoadApplication.MonitorDOF{case_nr,1};
else
    error('LoadCase %s does not exist!', arg.info.name_pushover)
end

dir_user = ['U' num2str(arg.comp.d_earthquake{2,1})];

if ~strcmp(dir_user,dir_sap)
    fprintf(2,'The specified primary direction %s (%s) does not match the "monitored direction" %s entered in the model! %s is transferred to the model.\n', dir_user,arg.comp.d_earthquake{1,1},dir_sap,dir_user)
    modell.Case0x2DStatic20x2DNonlinearLoadApplication.MonitorDOF{case_nr,1} = dir_user;
end



%% Prüfen, ob 1.) für den Lastfall der Vertikallasten "Full Load" und 2.) für den Pushover-Lastfall "Displacement Control" beim "Standard"-Pushover- bzw. "Full Load" beim modifizierten AMI-Verfahren eingestellt ist
% Vertikallasten
Idx_LoadCase_vertical_load_logical = strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),arg.info.name_vert);
if ~strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.LoadApp(Idx_LoadCase_vertical_load_logical),'Full Load')
    % Korrigieren!
    modell.Case0x2DStatic20x2DNonlinearLoadApplication.LoadApp(Idx_LoadCase_vertical_load_logical) = {'Full Load'};
    % Warnung ausgeben
    fprintf(2,'ATTENTION: For the vertical load case, "Full Load" was not selected for the "Load Application"! This has now been corrected!\n')
end

% Pushover-Lastfall
Idx_LoadCase_pushover_logical = strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case(:,1),arg.info.name_pushover);
switch arg.info.procedure
    case 'standard'
        if ~strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.LoadApp(Idx_LoadCase_pushover_logical),'Displ Ctrl')
            % Korrigieren!
            modell.Case0x2DStatic20x2DNonlinearLoadApplication.LoadApp(Idx_LoadCase_pushover_logical) = {'Displ Ctrl'};
            % Warnung ausgeben
            fprintf(2,'ATTENTION: For the pushover load case, "Displ Ctrl" was not selected for the "Load Application"! This has now been corrected!\n')
        end
    case {'ami_c','ami_o'}
        if ~strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.LoadApp(Idx_LoadCase_pushover_logical),'Full Load')
            % Korrigieren!
            modell.Case0x2DStatic20x2DNonlinearLoadApplication.LoadApp(Idx_LoadCase_pushover_logical) = {'Full Load'};
            % Warnung ausgeben
            fprintf(2,'ATTENTION: For the pushover load case, "Full Load" was not selected for the "Load Application"! This has now been corrected!\n')
        end
end

end
function modell = caap_create_new_LC(modell,arg,name_old,name_new,typ)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   modell = caap_create_new_LC(modell,arg,name_old,name_new,typ)
%   
%   Funktion zum Erstellen eines LoadCases
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

switch typ
    case 'modal'
        TABELLEN = {'Case0x2DModal10x2DGeneral','LoadCaseDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_old, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).Case(:,1),name_old));
            modell.(TABELLEN{i_tabelle}) = sub_copy(modell.(TABELLEN{i_tabelle}),i_old);
            modell.(TABELLEN{i_tabelle}).Case(end,1) = {name_new};
        end
        
        modell.LoadCaseDefinitions.InitialCond(end,1) = {arg.info.name_pushover_old};
        
    case 'pushover'
        TABELLEN = {'Case0x2DStatic10x2DLoadAssignments','Case0x2DStatic20x2DNonlinearLoadApplication','Case0x2DStatic40x2DNonlinearParameters','LoadCaseDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_old, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).Case(:,1),name_old));
            modell.(TABELLEN{i_tabelle}) = sub_copy(modell.(TABELLEN{i_tabelle}),i_old);
            modell.(TABELLEN{i_tabelle}).Case(end,1) = {name_new};
        end
        modell.Case0x2DStatic10x2DLoadAssignments.LoadName(end,1) = {name_new};
        if strcmp(arg.info.procedure,'standard')
            modell.Case0x2DStatic20x2DNonlinearLoadApplication.TargetDispl(end,1) = {arg.comp.v_target(end)};
        end
        modell.LoadCaseDefinitions.InitialCond(end,1) = {arg.info.name_pushover_old};
        
        TABELLEN = {'LoadPatternDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_old, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).LoadPat(:,1),name_old));
            modell.(TABELLEN{i_tabelle}) = sub_copy(modell.(TABELLEN{i_tabelle}),i_old);
            modell.(TABELLEN{i_tabelle}).LoadPat(end,1) = {name_new};
        end 
        
    case 'pushover_vergleich'
        TABELLEN = {'Case0x2DStatic10x2DLoadAssignments','Case0x2DStatic20x2DNonlinearLoadApplication','Case0x2DStatic40x2DNonlinearParameters','LoadCaseDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_old, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).Case(:,1),name_old));
            modell.(TABELLEN{i_tabelle}) = sub_copy(modell.(TABELLEN{i_tabelle}),i_old);
            modell.(TABELLEN{i_tabelle}).Case(end,1) = {name_new};
        end
        
        modell.Case0x2DStatic10x2DLoadAssignments.LoadName(end,1) = {arg.info.name_pushover_old};
        switch arg.info.procedure
            case 'standard'
                modell.Case0x2DStatic20x2DNonlinearLoadApplication.TargetDispl(end,1) = {sum(arg.comp.v_target(end-1:end))}; % wieder alte Zielverschiebung einstellen, da angepasster LF kopiert wurde
            case 'ami_o'
                modell.Case0x2DStatic10x2DLoadAssignments.LoadSF(end,1) = {num2str(1 / arg.comp.k(arg.info.nummer))};
        end
end
end

%% Sub-Funktionen

function sub_modell = sub_copy(sub_modell,index)
ATTRIBUTE = fieldnames(sub_modell);
for i_attribut = 1:1:size(ATTRIBUTE,1)
    if ~strcmp(ATTRIBUTE{i_attribut},'GUID') && ~strcmp(ATTRIBUTE{i_attribut},'name')
        sub_modell.(ATTRIBUTE{i_attribut})(end+1,1) =  sub_modell.(ATTRIBUTE{i_attribut})(index,1);
    elseif strcmp(ATTRIBUTE{i_attribut},'GUID')
        sub_modell.(ATTRIBUTE{i_attribut})(end+1,1) =  {''};
    end
end
end
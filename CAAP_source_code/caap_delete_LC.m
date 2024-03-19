function modell = caap_delete_LC(modell,name,typ)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   modell = caap_delete_LC(modell,name,typ)
%   
%   Funktion zum LĂ¶schen eines LoadCases
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%%
switch typ
    case 'modal'
        
        TABELLEN = {'Case0x2DModal10x2DGeneral','LoadCaseDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_delete, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).Case(:,1),name));
            if ~isempty(i_delete)
                modell.(TABELLEN{i_tabelle}) = sub_delete(modell.(TABELLEN{i_tabelle}),i_delete);
            end
        end
        
    case 'pushover'
        
        TABELLEN = {'Case0x2DStatic10x2DLoadAssignments','Case0x2DStatic20x2DNonlinearLoadApplication','Case0x2DStatic40x2DNonlinearParameters','LoadCaseDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_delete, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).Case(:,1),name));
            if ~isempty(i_delete)
                modell.(TABELLEN{i_tabelle}) = sub_delete(modell.(TABELLEN{i_tabelle}),i_delete);
            end
        end
        
        TABELLEN = {'LoadPatternDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_delete, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).LoadPat(:,1),name));
            modell.(TABELLEN{i_tabelle}) = sub_delete(modell.(TABELLEN{i_tabelle}),i_delete);
        end
        
    case 'pushover_vergleich'
        
        TABELLEN = {'Case0x2DStatic10x2DLoadAssignments','Case0x2DStatic20x2DNonlinearLoadApplication','Case0x2DStatic40x2DNonlinearParameters','LoadCaseDefinitions'};
        for i_tabelle = 1:1:size(TABELLEN,2)
            [i_vergleich, ~, ~,] = find(strcmp(modell.(TABELLEN{i_tabelle}).Case(:,1),'PushOver_Vergleich'));
            if ~isempty(i_vergleich)
                modell.(TABELLEN{i_tabelle}) = sub_delete(modell.(TABELLEN{i_tabelle}),i_vergleich);
            end
        end
end
end

%% Sub-Funktionen

function sub_modell = sub_delete(sub_modell,index)
ATTRIBUTE = fieldnames(sub_modell);
for i_attribut = 1:1:size(ATTRIBUTE,1)
    if ~strcmp(ATTRIBUTE{i_attribut},'name')
        sub_modell.(ATTRIBUTE{i_attribut})(index) =  [];
    end
end
end
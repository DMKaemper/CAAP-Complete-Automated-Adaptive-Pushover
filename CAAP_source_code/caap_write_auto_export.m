function modell = caap_write_auto_export(modell,arg,keyword)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   modell = caap_write_auto_export(modell,arg,keyword)
%
%   Funktion zum Vorbereiten des Auto-Exports
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%%
switch arg.info.procedure
    case {'standard','ami_c','ami_o'}
        
        switch keyword
            case 'initial'
                if isfield(modell,'NamedSets0x2DDatabaseTables10x2DGeneral')
                    modell = rmfield(modell,'NamedSets0x2DDatabaseTables10x2DGeneral');
                end
                ATTRIBUTE = {...
                    'DBNamedSet','AUTO EXPORT';...
                    'SortOrder','Elem, Cases';...
                    'Unformatted','No';...
                    'ModeStart','1';...
                    'ModeEnd','All';...
                    'ModalHist','Envelopes';...
                    'DirectHist','Envelopes';...
                    'NLStatic','StepByStep';...
                    'BaseReacX','0';...
                    'BaseReacY','0';...
                    'BaseReacZ','0';...
                    'Combo','Envelopes';...
                    'Steady','Frequencies';...
                    'SteadyOpt','Magnitude';...
                    'PSD','RMS';...
                    'Multistep','Envelopes'};
                for i_attribut = 1:1:size(ATTRIBUTE,1)
                    modell.NamedSets0x2DDatabaseTables10x2DGeneral.(ATTRIBUTE{i_attribut,1}) = ATTRIBUTE(i_attribut,2);
                end
                modell.NamedSets0x2DDatabaseTables10x2DGeneral.name = 'NAMED SETS - DATABASE TABLES 1 - GENERAL';
                
                
                if isfield(modell,'NamedSets0x2DDatabaseTables20x2DSelections')
                    modell = rmfield(modell,'NamedSets0x2DDatabaseTables20x2DSelections');
                end
                ATTRIBUTE = {...
                    'DBNamedSet',{'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT';'AUTO EXPORT'};...
                    'SelectType',{'Table';'Table';'Table';'Table';'Table';'Table';'LoadPattern';'LoadPattern';'LoadCase';'LoadCase';'LoadCase';'Table'};...
                    'Selection',{'Connectivity - Frame';'Joint Displacements';'Joint Reactions';'Assembled Joint Masses';'Modal Participation Factors';'Base Reactions';arg.info.name_vert;arg.info.name_pushover;...
                                arg.info.name_vert;arg.info.name_modal;arg.info.name_pushover;'Modal Participating Mass Ratios'}};
                
                for i_attribut = 1:1:size(ATTRIBUTE,1)
                    modell.NamedSets0x2DDatabaseTables20x2DSelections.(ATTRIBUTE{i_attribut,1}) = ATTRIBUTE{i_attribut,2};
                end
                modell.NamedSets0x2DDatabaseTables20x2DSelections.name = 'NAMED SETS - DATABASE TABLES 2 - SELECTIONS';
                
                
                if isfield(modell,'TablesAutomaticallySavedAfterAnalysis')
                    modell = rmfield(modell,'TablesAutomaticallySavedAfterAnalysis');
                end
                ATTRIBUTE = {...
                    'SaveFile','YES';...
                    'FileName',arg.info.export_file_name;...
                    'NamedSet','AUTO EXPORT';...
                    'Group','All'};
                for i_attribut = 1:1:size(ATTRIBUTE,1)
                    modell.TablesAutomaticallySavedAfterAnalysis.(ATTRIBUTE{i_attribut,1}) = ATTRIBUTE(i_attribut,2);
                end
                modell.TablesAutomaticallySavedAfterAnalysis.name = 'TABLES AUTOMATICALLY SAVED AFTER ANALYSIS';
                
                
            case 'update_modal'
                
                ATTRIBUTE = {'DBNamedSet','SelectType','Selection'};
                VALUE = {'AUTO EXPORT','LoadCase',arg.info.name_modal_new};
                
                % alte Einträge löschen
                index = find(strcmp(modell.NamedSets0x2DDatabaseTables20x2DSelections.Selection,arg.info.name_modal_old));
                for i_attribut = 1:1:size(ATTRIBUTE,2)
                    modell.NamedSets0x2DDatabaseTables20x2DSelections.(ATTRIBUTE{i_attribut})(index,:) = [];
                end
                
                % neue Einträge hinzufügen                
                for i_attribut = 1:1:size(ATTRIBUTE,2)
                    modell.NamedSets0x2DDatabaseTables20x2DSelections.(ATTRIBUTE{i_attribut})(end+1,1) = VALUE(i_attribut);
                end
                
            case 'update_push'
                
                ATTRIBUTE = {...
                    'DBNamedSet',{'AUTO EXPORT';'AUTO EXPORT'};...
                    'SelectType',{'LoadPattern';'LoadCase'};...
                    'Selection',{arg.info.name_pushover_old;arg.info.name_pushover_old}};
                
                % alte Einträge löschen
                index = find(strcmp(modell.NamedSets0x2DDatabaseTables20x2DSelections.Selection,arg.info.name_pushover_before_old));
                for i_attribut = 1:1:size(ATTRIBUTE,1)
                    modell.NamedSets0x2DDatabaseTables20x2DSelections.(ATTRIBUTE{i_attribut,1})(index,:) = [];
                end
                
                % neue Einträge hinzufügen
                for i_attribut = 1:1:size(ATTRIBUTE,1)
                    for i_value = 1:1:size(ATTRIBUTE{1,2},1)
                        modell.NamedSets0x2DDatabaseTables20x2DSelections.(ATTRIBUTE{i_attribut,1})(end+1,1) = ATTRIBUTE{i_attribut,2}(i_value);
                    end
                end
        end
end
end
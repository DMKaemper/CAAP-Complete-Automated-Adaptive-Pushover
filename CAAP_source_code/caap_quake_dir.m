function arg = caap_quake_dir(modell,arg)
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   arg = caap_quake_dir(modell,arg)
%
%   Funktion zur Ermittlung der Bebenrichtungen
%
%   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%%
if strcmp(arg.comp.name,'standard')
    case_nr = find(strcmp(modell.Case0x2DStatic20x2DNonlinearLoadApplication.Case,arg.info.name_pushover));
    
    if ~isempty(case_nr)
        r_prim = modell.Case0x2DStatic20x2DNonlinearLoadApplication.MonitorDOF{case_nr,1};
    else
        error('LoadCase %s does not exist!', arg.info.name_pushover)
    end
    
    if contains(r_prim,'R')
        error('%s was determined as primary seismic direction!',r_prim)
    else
        switch r_prim
            case 'U1'
                r_prim = 'X';
            case 'U2'
                r_prim = 'Y';
            case 'U3'
                r_prim = 'Z';
        end
    end
    
    arg.comp.d_earthquake = [{r_prim},arg.comp.d_earthquake];
end

for i_d_earthquake = 1:1:size(arg.comp.d_earthquake,2)
    switch arg.comp.d_earthquake{1,i_d_earthquake}
        case 'X'
            dir = 1;
        case 'Y'
            dir = 2;
        case 'Z'
            dir = 3;
    end
    arg.comp.d_earthquake(2,i_d_earthquake) = {dir};
end

end
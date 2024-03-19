function arg = caap_generate_lc_names(arg)
% Namen der LoadCases zusammenbauen
if arg.info.nummer == 1
    arg.info.name_pushover_old = arg.info.name_pushover;
    arg.info.name_pushover_new = [arg.info.name_pushover '__' num2str(arg.info.nummer+1)];
    
    arg.info.name_modal_old = arg.info.name_modal;
    arg.info.name_modal_new = [arg.info.name_modal '__' num2str(arg.info.nummer+1)];
else
    arg.info.name_pushover_before_old = arg.info.name_pushover_old;
    arg.info.name_pushover_old = [arg.info.name_pushover '__' num2str(arg.info.nummer)];
    arg.info.name_pushover_new = [arg.info.name_pushover '__' num2str(arg.info.nummer+1)];
    
    arg.info.name_modal_old = [arg.info.name_modal '__' num2str(arg.info.nummer)];
    arg.info.name_modal_new = [arg.info.name_modal '__' num2str(arg.info.nummer+1)];
end
end
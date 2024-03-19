function arg = caap_el_accel_response_spectrum(arg)

% Liefert ...
% - (A) ENTWEDER ein VOLLSTÄNDIGES gedämpftes elastisches Beschleunigungsantwortspektrum, also die entspr. T- und S_a-Werte nach DIN EN 1998-1 (Hauptteil) oder dem korresp. deutschen NA 

% - (B) ODER nur einen ganz bestimmten Spektralwert S_a_n_max_i(T_n_eff_i),
%       wenn nämlich das Feld "T_n_eff_i_tmp" innerhalb der Struktur "arg.comp" existiert


% ACHTUNG: Die Strukturfelder werden in der Routine "caap_check_varargin"
% immer in Kleinbuchstaben überführt (z. B. arg.rs.s oder arg.rs.t_bcd)!!!


%% Relevante Strukturfelder von arg.rs prüfen und ggf. belegen/korrigieren
%  Prüfen, ob es überhaupt eine "rs"-Substruktur gibt
if ~isfield(arg,'rs')
    error('The "rs" struct is missing!')
end

% Norm (Datenquelle)
standard_zulaessig = {'ec8-1','ec8-1_de'};
if ~isfield(arg.rs,'standard')
    arg.rs.standard = standard_zulaessig{1}; % wenn nicht definiert: Hauptteil des EC 8, Teil 1 nehmen!
elseif ~ismember(arg.rs.standard,standard_zulaessig)
    arg.rs.standard = standard_zulaessig{1}; % wenn ungültig definiert: Hauptteil des EC 8, Teil 1 nehmen!
    fprintf(2,'Attention: The source for the elastic response spectrum was defined incorrectly! The main part of EC 8, part 1 is now used!\n')
end

% Richtung 
%{
MÜSSTE MAN EIGENTLICH NICHT PRÜFEN, WIRD NÄMLICH IMMER AUTOMATISSIERT DEFINIERT:
 a) im Fall "standard" mit Erdbeben-NW (PP-Erm):
    -> in MAIN_CAAP unmittelbar vor Aufruf der Routine "caap_CSM_determine_PP"
 b) im Fall "ami_c" oder "ami_o":
    -> in caap_pushover_pointloads für die jew. akt. Richtung (in einer entspr. Schleife)
%}
richtung_zulaessig = {'horizontal','vertikal'};
if ~isfield(arg.rs,'richtung')
    arg.rs.richtung = richtung_zulaessig{1}; % wenn nicht definiert: Horizontales Spektrum! DÜRFTE WIE GESAGT EIGENTLICH NICHT SEIN, DAHER: Warnung ausgeben!
    fprintf(2,'No direction was defined for the response spectrum, which cannot actually be the case because this should always happen cleanly within the program!\n')
elseif ~ismember(arg.rs.richtung,richtung_zulaessig)
    arg.rs.richtung = richtung_zulaessig{1}; % wenn ungültig definiert: Horizontales Spektrum!
    fprintf(2,'Attention: The direction for the elastic response spectrum was defined incorrectly! A horizontal spectrum is now used!\n')
end

% a_g (horizontale Bemessungs-Bodenbeschleunigung für Baugrundklasse A, mit a_g = gamma_I * a_gR),
% benötigt beim hor. el. Antwortspektrum
if strcmp(arg.rs.richtung,'horizontal')
    if ~isfield(arg.rs,'a_g')
        error('No horizontal design ground acceleration was specified!')
    elseif ~ist_typ(arg.rs.a_g,'zahl')
        error('No specification was given for the horizontal design ground acceleration!')
    end
end

% a_vg (vertikale Bemessungs-Bodenbeschleunigung),
% benötigt beim vert. el. Antwortspektrum
if strcmp(arg.rs.richtung,'vertikal')
    if ~isfield(arg.rs,'a_vg')
        error('No vertical design ground acceleration was specified!')
    elseif ~ist_typ(arg.rs.a_vg,'zahl')
        error('No specification was given for the vertical design ground acceleration!')
    end
end

% S (Bodenparameter), 
% benötigt beim hor. el. Antwortspektrum
if strcmp(arg.rs.richtung,'horizontal')
    if ~isfield(arg.rs,'s')
        error('No soil parameter was specified, although a horizontal response spectrum should be generated!')
    elseif ~ist_typ(arg.rs.s,'zahl')
        error('No specifiaction was given for the soil parameter!')
    end
end

% T_B, T_C & T_D (Kontrollperioden)
if ~isfield(arg.rs,'t_bcd')
    error('No control periods T_B, T_C and T_D were specified!')
elseif ~ist_typ(arg.rs.t_bcd,'array') || max(size(arg.rs.t_bcd)) ~= 3 || min(size(arg.rs.t_bcd)) ~= 1
    error('For the control periods T_B, T_C and T_D no array of the dimension 1x3 or 3x1 was specified!')
end

% dT (Auflösung der T-Achse)
if ~isfield(arg.rs,'dt')
    arg.rs.dt = 0.01; % wenn nicht definiert: dT = 0,01 s
elseif ~ist_typ(arg.rs.dt,'zahl')
    arg.rs.dt = 0.01; % wenn ungültig definiert: dT = 0,01 s
    fprintf(2,'Attention: The resolution of the T-axis was defined incorrectly! It is now set to 0.01 s!\n')
end

% T_max (oberer Grenzwert der T-Achse)
if ~isfield(arg.rs,'t_max')
    arg.rs.t_max = 4; % wenn nicht definiert: T_max = 4 s
elseif ~ist_typ(arg.rs.t_max,'zahl')
    arg.rs.t_max = 4; % wenn ungültig definiert: T_max = 4 s
    fprintf(2,'Attention: The upper limit value of the T-axis was defined incorrectly! It is now set to 4 s!\n')
end

% T_min (unterer Grenzwert der T-Achse)
if ~isfield(arg.rs,'t_min')
    arg.rs.t_min = 0; % wenn nicht definiert: T_min = 0 s
elseif ~ist_typ(arg.rs.t_min,'zahl')
    arg.rs.t_min = 0; % wenn ungültig definiert: T_min = 0 s
    fprintf(2,'Attention: The lower limit value of the T-axis was defined incorrectly! It is now set to 0 s!\n')
end


%% Zwischenschritt 
% Kontrollperioden aus arg.rs auslesen für einfacheren Zugriff
T_B = arg.rs.t_bcd(1);
T_C = arg.rs.t_bcd(2);
T_D = arg.rs.t_bcd(3);
% Dämpfungs-Korrekturwert "eta" ermitteln gem. DIN EN 1998-1, 3.2.2.2 (3)
switch arg.info.procedure
    case 'standard'
        eta = max(sqrt(10/(5+arg.comp.xi_eff)),0.55);
    case {'ami_c','ami_o'}
        eta = max(sqrt(10/(5+arg.comp.xi_n_eff.(arg.richtung_akt)(arg.info.nummer,arg.i_Mode))),0.55);
end


%% Fall (A): VOLLSTÄNDIGES gedämpftes elastisches Beschleunigungsantwortspektrum aufbauen
if ~isfield(arg.comp,'T_n_eff_i_tmp')
    
    % T-Achse aufbauen
    T_Eckpunkte = [arg.rs.t_min arg.rs.t_bcd arg.rs.t_max];
    T_fein = arg.rs.t_min:arg.rs.dt:arg.rs.t_max;
    T = unique([T_Eckpunkte';T_fein'])';
    
    % S_a-Werte ermitteln, je nach Quelle (Norm) & Richtung
    % Vorbelegung
    S_a = zeros(1,length(T));

    switch arg.rs.standard
        case 'ec8-1'
            % Fall: Antwortspektrum nach dem Hauptteil des EC 8, Teil 1
            switch arg.rs.richtung
                case 'horizontal'
                    % Horizontales elastisches Antwortspektrum:
                    a_g = arg.rs.a_g;
                    S = arg.rs.s;
                    for I = 1:length(T)
                        if T(I) <= T_B
                            S_a(I) = a_g * S *(1+(T(I)/T_B)*(eta*2.5-1));
                        elseif T(I) <= T_C
                            S_a(I) = a_g * S * eta * 2.5;
                        elseif T(I) <= T_D
                            S_a(I) = a_g * S * eta * 2.5 * (T_C/T(I));
                        else
                            S_a(I) = a_g * S * eta * 2.5 * (T_C*T_D/(T(I))^2);
                        end
                    end
                case 'vertikal'
                    % Vertikales elastisches Antwortspektrum:
                    a_vg = arg.rs.a_vg;
                    for I = 1:length(T)
                        if T(I) <= T_B
                            S_a(I) = a_vg *(1+(T(I)/T_B)*(eta*3.0-1));
                        elseif T(I) <= T_C
                            S_a(I) = a_vg * eta * 3.0;
                        elseif T(I) <= T_D
                            S_a(I) = a_vg * eta * 3.0 * (T_C/T(I));
                        else
                            S_a(I) = a_vg * eta * 3.0 * (T_C*T_D/(T(I))^2);
                        end
                    end
            end
        case 'ec8-1_de' % ACHTUNG: Laut aktuellem NA sind nur bestimmte Werte und Verhältnisse,
            % wie T_B, T_C, T_D & a_vg/ag im NA anders geregelt als
            % im Hauptteil, was in dieser Funktion ja den Input
            % betreffen würde. Die Formeln für die Spektren sind
            % aber identisch!!!
            % Fall: Antwortspektrum nach dem deutschen NA zum EC 8, Teil 1
            switch arg.rs.richtung
                case 'horizontal'
                    % Horizontales elastisches Antwortspektrum:
                    a_g = arg.rs.a_g;
                    S = arg.rs.s;
                    for I = 1:length(T)
                        if T(I) <= T_B
                            S_a(I) = a_g * S *(1+(T(I)/T_B)*(eta*2.5-1));
                        elseif T(I) <= T_C
                            S_a(I) = a_g * S * eta * 2.5;
                        elseif T(I) <= T_D
                            S_a(I) = a_g * S * eta * 2.5 * (T_C/T(I));
                        else
                            S_a(I) = a_g * S * eta * 2.5 * (T_C*T_D/(T(I))^2);
                        end
                    end
                case 'vertikal'
                    % Vertikales elastisches Antwortspektrum:
                    a_vg = arg.rs.a_vg;
                    for I = 1:length(T)
                        if T(I) <= T_B
                            S_a(I) = a_vg *(1+(T(I)/T_B)*(eta*3.0-1));
                        elseif T(I) <= T_C
                            S_a(I) = a_vg * eta * 3.0;
                        elseif T(I) <= T_D
                            S_a(I) = a_vg * eta * 3.0 * (T_C/T(I));
                        else
                            S_a(I) = a_vg * eta * 3.0 * (T_C*T_D/(T(I))^2);
                        end
                    end
            end
    end
    
    % Ausgabe je nach Fall: Horizontal oder Vertikal
    % ACHTUNG: In arg.rs alle Felder mit Kleinbuchstaben benennen, da dort
    % immer alles klein geschrieben ist (Stichwort: konsistente Bezeichnung)!
    if strcmp(arg.rs.richtung,'horizontal')
        arg.rs.t = T;
        arg.rs.s_a_horizontal = S_a;
    else
        arg.rs.t = T;
        arg.rs.s_a_vertikal = S_a;
    end


%% Fall (B): Nur einen ganz bestimmten Spektralwert S_a_n_max_i(T_n_eff_i) ermitteln
else
  % Spektralbeschleunigungswert (je nach Norm) ermitteln für die Periode
  % T_n_eff_i
  T = arg.comp.T_n_eff_i_tmp;
  switch arg.rs.standard
      case 'ec8-1'
          % Fall: Antwortspektrum nach dem Hauptteil des EC 8, Teil 1
          switch arg.rs.richtung
              case 'horizontal'
                  % Horizontales elastisches Antwortspektrum:
                  a_g = arg.rs.a_g;
                  S = arg.rs.s;
                  if T <= T_B
                      S_a = a_g * S *(1+(T/T_B)*(eta*2.5-1));
                  elseif T <= T_C
                      S_a = a_g * S * eta * 2.5;
                  elseif T <= T_D
                      S_a = a_g * S * eta * 2.5 * (T_C/T);
                  else
                      S_a = a_g * S * eta * 2.5 * (T_C*T_D/T^2);
                  end
              case 'vertikal'
                  % Vertikales elastisches Antwortspektrum:
                  a_vg = arg.rs.a_vg;
                  if T <= T_B
                      S_a = a_vg *(1+(T/T_B)*(eta*3.0-1));
                  elseif T <= T_C
                      S_a = a_vg * eta * 3.0;
                  elseif T <= T_D
                      S_a = a_vg * eta * 3.0 * (T_C/T);
                  else
                      S_a = a_vg * eta * 3.0 * (T_C*T_D/T^2);
                  end
          end
      case 'ec8-1_de' % ACHTUNG: Laut aktuellem NA sind nur bestimmte Werte 
          % und Verhältnisse, wie T_B, T_C, T_D & a_vg/ag, im NA anders geregelt
          % als im Hauptteil, was in dieser Funktion ja den Input betreffen
          % würde. Die Formeln für die Spektren sind aber identisch!!!
          % Fall: Antwortspektrum nach dem deutschen NA zum EC 8, Teil 1
          switch arg.rs.richtung
              case 'horizontal'
                  % Horizontales elastisches Antwortspektrum:
                  a_g = arg.rs.a_g;
                  S = arg.rs.s;
                  if T <= T_B
                      S_a = a_g * S *(1+(T/T_B)*(eta*2.5-1));
                  elseif T <= T_C
                      S_a = a_g * S * eta * 2.5;
                  elseif T <= T_D
                      S_a = a_g * S * eta * 2.5 * (T_C/T);
                  else
                      S_a = a_g * S * eta * 2.5 * (T_C*T_D/T^2);
                  end
              case 'vertikal'
                  % Vertikales elastisches Antwortspektrum:
                  a_vg = arg.rs.a_vg;
                  if T <= T_B
                      S_a = a_vg *(1+(T/T_B)*(eta*3.0-1));
                  elseif T <= T_C
                      S_a = a_vg * eta * 3.0;
                  elseif T <= T_D
                      S_a = a_vg * eta * 3.0 * (T_C/T);
                  else
                      S_a = a_vg * eta * 3.0 * (T_C*T_D/T^2);
                  end
          end
  end
  
  % S_a an der richtigen Stelle in der "arg"-Struktur abspeichern
  arg.comp.s_a_n_max_i(arg.info.nummer,arg.i_Mode) = S_a;
    
end

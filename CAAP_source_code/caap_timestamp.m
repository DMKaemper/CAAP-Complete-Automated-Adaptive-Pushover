function [zeit] = caap_timestamp()
matlabtimestamp = 719529 + posixtime(datetime)/86400;
datum = datevec(matlabtimestamp);
zeit = '';
sec = strsplit(num2str(datum(6)),'.');
datum(6) = str2double(sec(1));
if length(num2str(datum(1))) == 1
    zeit = [zeit, '000', datum(1)];
elseif length(num2str(datum(1))) == 2
    zeit = [zeit, '00', datum(1)];
elseif length(num2str(datum(1))) == 3
    zeit = [zeit, '0', datum(1)];
else
    zeit = [zeit, num2str(datum(1))];
end
for item = 2:6
    if item == 4
        zeit = [zeit, '_'];
    end
    if length(num2str(datum(item))) == 1
        zeit = [zeit, '0', num2str(datum(item))];
    else
        zeit = [zeit, num2str(datum(item))];
    end
end
end
% pixel type as defined by SHUJI
pixel_types={'d','t','t','t','t','e','t','d','t','t','e','z','e','e','e','z','t','e','e','e','t','e','z','e','e','e','j','e','e','e','z','z','t','e','e','e','e','j','e','e','t','d','e','z','e','e','e','z','e','j','j','j','e','j','z','z','e','e','j','z','e','e','z','z','t','e','e','e','e','j','e','e','e','e','j','z','j','j','j','z','e','j','j','j','e','j','z','z','j','j','f','z','j','j','z','z','t','e','e','e','e','j','e','e','z','z','z','z','z','z','z','z','e','j','j','j','e','j','z','z','z','z','z','z','z','z','z','z','t','e','e','e','e','j','e','e','e','e','j','z','j','j','j','z','t','e','e','e','d','e','z','z','e','e','j','z','e','e','z','z','e','j','j','j','j','f','j','j','e','e','j','z','j','j','j','z','e','j','j','j','e','j','z','z','e','e','z','z','e','e','z','z','t','e','e','e','e','j','e','e','e','e','j','z','j','j','j','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','d','e','e','e','e','j','e','e','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z'};
% corresponding binary number
binconfig=cell(1,256);
for i=0:255
    binconfig{i+1}=dec2bin(i,8);
end

%% usage
% look for all 'j' types
jtype=strcmp(pixel_types,'e');
% corresponding binary numbers
jconf=binconfig(jtype);
% display the configurations
for i=1:numel(jconf)
    cfg2mat(jconf{i})
end


   function Crgb = str2rgb(Cstr)
   %
   % Crgb = str2rgb(Cstr)
   %
   % Turns letter specifying color "Cstr" (kbgcrmyw) into a row vector of rgb values "Crgb".
   % 
   % Oliver Woodford
   % 23 Oct, 2009
   
   %% Code %%
   
   Crgb = rem(floor((strfind('kbgcrmyw', Cstr) - 1) * [0.25 0.5 1]), 2);
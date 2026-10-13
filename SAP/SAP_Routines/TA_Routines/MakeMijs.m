function Mijs = MakeMijs(Lijs)
%
% Mijs = MakeMijs(Lijs)
%
% Returns nHL x 4 matrix "Mijs" [Mxx Myx Mxy Myy ; ...] calculated from nHL x 2 matrix "Lijs" [Lx Ly; Lx' Ly';...]
% calculating the outer product FOR EACH Lij with regular matrix product: Mij = Lij*Lij' 
% nHL = number of Half-Links 
%
% Version 1.0
% Boris Guirao


%% Code %%

% gets nHL and initializes Mijs_cell:
nHL = size(Lijs,1);
MijsCell = cell(nHL,1);

% creates appropriate cell arrays:
LijsCell = (num2cell(Lijs',1))';                      % {[Lij_X ; Lij_Y] ; [Lij'_X ; Lij'_Y]; ...}
TLijsCell = num2cell(Lijs,2);                         % {[Lij_X  Lij_Y] ; [Lij'_X  Lij'_Y] ; ...}

% Calculates outer product: Mij = Lij*Lij'
for l = 1:nHL
    MijsCell{l} = LijsCell{l}*TLijsCell{l};
end

% Reshapes "Mijs_cell" and turns it into a matrix:
Mijs = cell2mat(MijsCell);                            % turns cell: {[Mxx Myx ; Mxy Myy];...}
Mijs = reshape(Mijs',1,[]);
Mijs =(reshape(Mijs',4,[]))';                          % into matrix: [Mxx Myx Mxy Myy ; ...]


%% History %%

% 7/12/2011: creation

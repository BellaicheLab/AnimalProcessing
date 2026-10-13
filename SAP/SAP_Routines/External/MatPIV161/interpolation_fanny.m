function [matricePIV] = interpolation(donneesPIV)
%fonction ecrite pour recuperer facilement les donnes issues de PIVview
%__________________________________________________________________________
%donneesPIV est une matrice qui donne en 1e et 2e la colonne et la ligne du
%point de la grille ou est calculé le champ de déplacement
% en 3e et 4e sont les coordonnes dx et dy du champ de deplacement
% la convention est que les pixels sont numérotés de bas en haut et de
% gauche a droite dont (1,1) correspondra au pixel en bas a gauche
% on n'utilisera pas cette convention pour la sortie
% ______________________________________________________________________
% matricePIVtemp est une matrice de meme taille que l'image qui donne les
% champs de déplacements en tout point par interpolation
% la convention de matricePIVtemp est que le pixel (1,1) en haut a gauche, le
% pixel (largeurimage,1) en haut a droite...etc...

%-------------------------------------
%on rajoute ici des parametres qui pourront etre ensuite directement
%recuperes dans donneesPIV

ecart=16;
largeurimage=573;
hauteurimage=682;
largeurgrille=544;
hauteurgrille=656;
%--------------------------------------------------------------------
for sautligne=ecart:ecart:hauteurgrille
    for sautcolonne=2*ecart:ecart:largeurgrille-2*ecart
        x2=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(sautcolonne-ecart)/ecart+2,3);
        x1=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(sautcolonne-ecart)/ecart+1,3);
        y2=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(sautcolonne-ecart)/ecart+2,4);
        y1=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(sautcolonne-ecart)/ecart+1,4);
        for i=0:1:ecart  
            matricePIVtemp(sautligne,sautcolonne+i,1)=(x2-x1)*i/ecart+x1;
            matricePIVtemp(sautligne,sautcolonne+i,2)=(y2-y1)*i/ecart+y1; 
        end
    end
    x2=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+2,3);
    x1=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+1,3);
    y2=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+2,4);
    y1=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+1,4);
    for i=-ecart+1:1:ecart
        matricePIVtemp(sautligne,ecart+i,1)=(x2-x1)*i/ecart+x1;
        matricePIVtemp(sautligne,ecart+i,2)=(y2-y1)*i/ecart+y1; 
    end
    x2=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(largeurgrille-2*ecart)/ecart+2,3);
    x1=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(largeurgrille-2*ecart)/ecart+1,3);
    y2=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(largeurgrille-2*ecart)/ecart+2,4);
    y1=donneesPIV((sautligne-ecart)/ecart*(largeurgrille/ecart)+(largeurgrille-2*ecart)/ecart+1,4);
    for i=0:1:ecart+largeurimage-largeurgrille
        matricePIVtemp(sautligne,largeurgrille-ecart+i,1)=(x2-x1)*i/ecart+x1;
        matricePIVtemp(sautligne,largeurgrille-ecart+i,2)=(y2-y1)*i/ecart+y1; 
     end
end

for sautcolonne=1:1:largeurimage
    for sautligne=2*ecart:ecart:hauteurgrille-2*ecart
        x2=matricePIVtemp(sautligne+ecart,sautcolonne,1);
        x1=matricePIVtemp(sautligne,sautcolonne,1);
        y2=matricePIVtemp(sautligne+ecart,sautcolonne,2);
        y1=matricePIVtemp(sautligne,sautcolonne,2);
        for j=0:1:ecart
            matricePIVtemp(sautligne+j,sautcolonne,1)=(x2-x1)*j/ecart+x1;
            matricePIVtemp(sautligne+j,sautcolonne,2)=(y2-y1)*j/ecart+y1;
        end
    end
    x2=matricePIVtemp(2*ecart,sautcolonne,1);
    x1=matricePIVtemp(ecart,sautcolonne,1);
    y2=matricePIVtemp(2*ecart,sautcolonne,2);
    y1=matricePIVtemp(ecart,sautcolonne,2);
    for j=-ecart+1:1:ecart
        matricePIVtemp(ecart+j,sautcolonne,1)=(x2-x1)*j/ecart+x1;
        matricePIVtemp(ecart+j,sautcolonne,2)=(y2-y1)*j/ecart+y1;
    end
    x2=matricePIVtemp(hauteurgrille,sautcolonne,1);
    x1=matricePIVtemp(hauteurgrille-ecart,sautcolonne,1);
    y2=matricePIVtemp(hauteurgrille,sautcolonne,2);
    y1=matricePIVtemp(hauteurgrille-ecart,sautcolonne,2);
    for j=0:1:ecart+hauteurimage-hauteurgrille
        matricePIVtemp(hauteurgrille-ecart+j,sautcolonne,1)=(x2-x1)*j/ecart+x1;
        matricePIVtemp(hauteurgrille-ecart+j,sautcolonne,2)=(y2-y1)*j/ecart+y1;
    end   
end

%--------------------------------------
%retournement de la matrice de sortie pour que la convention de haut en bas
%soit respectee
for numeroligne=1:size(matricePIVtemp,1)
    matricePIV(numeroligne,:,:)=matricePIVtemp(size(matricePIVtemp,1)-numeroligne+1,:,:);
end


    



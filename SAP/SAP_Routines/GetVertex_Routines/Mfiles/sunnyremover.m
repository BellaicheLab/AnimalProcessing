function cIMG=sunnyremover(IMG)
    % detect specific elements X motif
    % 1 0 0 1
    % 0 1 1 0
    % 0 1 1 0
    % 1 0 0 1
    filtered= conv2(double(IMG),[1 0 0 1;0 1 1 0;0 1 1 0;1 0 0 1],'same');
    inds=find(filtered==8);
    
    % copy original
    cIMG=IMG;
    % authorized type
    authorizedtype=[17 81 113 145];
    
    while(~isempty(inds))
        [y,x]=ind2sub(size(IMG),inds(1));
        pixelsvalue=zeros(1,8);
        pixelsvalue(1:5)=[1 0 cIMG(y+1,x+2) cIMG(y+2,x) cIMG(y+2,x+2)];
        if(y+3<=size(IMG,1)), pixelsvalue(6:8)=[cIMG(y+3,x) cIMG(y+3,x+1) cIMG(y+3,x+2)]; end
        
        typevalue=pixelsvalue*[1 2 4 8 16 32 64 128]';
        
        if ~isempty(find(authorizedtype==typevalue, 1))
            cIMG(y+1,x+1)=0;
            cIMG(y+2,x+1)=1;
            disp(['sunnyremover: (' num2str(x+1) ' ' num2str(y+1) ') moved to (' num2str(x+1) ' ' num2str(y+2) ')']);            
        else
            % try another move             
            disp('try another move')
            % rot90
            pixelsvalue=zeros(1,8);
            pixelsvalue(1:5)=[1 0 0 0 1];
            if(x-2>=1), pixelsvalue(6:8)=[cIMG(y,x-2) cIMG(y+1,x-2) cIMG(y+2,x-2)]; end        
            typevalue=pixelsvalue*[1 2 4 8 16 32 64 128]';
            if ~isempty(find(authorizedtype==typevalue, 1))
                cIMG(y+1,x)=0;
                cIMG(y+1,x-1)=1;
                disp(['sunnyremover: (' num2str(x) ' ' num2str(y+1) ') moved to (' num2str(x-1) ' ' num2str(y+1) ')']);
            else
                % try another move             
                disp('try another move 2')
                % rot180
                pixelsvalue=zeros(1,8);
                pixelsvalue(1:5)=[1 0 0 0 1];
                if(y-2>=1), pixelsvalue(6:8)=[cIMG(y-2,x+1) cIMG(y-2,x) cIMG(y-2,x-1)]; end        
                typevalue=pixelsvalue*[1 2 4 8 16 32 64 128]';
                if ~isempty(find(authorizedtype==typevalue, 1))
                    cIMG(y,x)=0;
                    cIMG(y-1,x)=1;
                    disp(['sunnyremover: (' num2str(x) ' ' num2str(y) ') moved to (' num2str(x) ' ' num2str(y-1) ')']);
                else
                    % try another move             
                    disp('try another move 3')
                    % rot270
                    pixelsvalue=zeros(1,8);
                    pixelsvalue(1:5)=[1 0 0 0 1];
                    if(x+3<=size(cIMG,2)), pixelsvalue(6:8)=[cIMG(y+1,x+3) cIMG(y,x+3) cIMG(y+1,x+3)]; end        
                    typevalue=pixelsvalue*[1 2 4 8 16 32 64 128]';
                    if ~isempty(find(authorizedtype==typevalue, 1))
                        cIMG(y,x+1)=0;
                        cIMG(y,x+2)=1;
                        disp(['sunnyremover: (' num2str(x+1) ' ' num2str(y) ') moved to (' num2str(x+2) ' ' num2str(y-1) ')']);
                    else
                        disp('try another move 4?')
                    end
                end
            end
        end
        % update inds
        filtered= conv2(double(cIMG),[1 0 0 1;0 1 1 0;0 1 1 0;1 0 0 1],'same');
        inds=find(filtered==8);       
    end
end
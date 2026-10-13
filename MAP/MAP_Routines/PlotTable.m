function PlotTable(mat1,mat2,plot_list,title_fig,output)

fontsize=4;
nanTF1 = isnan(mat1(:));
nanFR2 = isnan(mat2(:));

% figure('units','normalized','outerposition',[0 0 1 1]);
figure();%'PaperPositionMode','auto')
title(title_fig);
imagesc(mat1);            %# Create a colored plot of the matrix values
colormap(flipud(gray));      %# Change the colormap to gray (so higher values are
                             %#   black and lower values are white)

textStrings = num2str(mat1(:).*100.*sign(mat2(:)),'%0.0f');  %# Create strings from the matrix values
textStrings = strtrim(cellstr(textStrings));  %# Remove any space padding

textStrings(nanTF1) = {'.'};

% textStrings2 = num2str(mat2(:),'%0.2f');  %# Create strings from the matrix values
% textStrings2 = strtrim(cellstr(textStrings2));  %# Remove any space padding
% 
% textStrings2(nanFR2) = {''};

[x,y] = meshgrid(1:length(mat1));   %# Create x and y coordinates for the strings




hStrings = text(x(:),y(:),textStrings(:),...      %# Plot the strings
                'HorizontalAlignment','center','FontSize',fontsize);
            
midValue = mean(get(gca,'CLim'));  %# Get the middle value of the color range

textColors = repmat(mat1(:) > midValue,1,3);  %# Choose white or black for the
                                             %#   text color of the strings so
                                             %#   they can be easily seen over
                                             %#   the background color
                                             
set(hStrings,{'Color'},num2cell(textColors,2));  %# Change the text colors






% hStrings = text(x(:),y(:),textStrings2(:),...      %# Plot the strings
%                 'VerticalAlignment','top','HorizontalAlignment','center','FontSize',fontsize);
%             
% midValue = mean(get(gca,'CLim'));  %# Get the middle value of the color range
% 
% textColors = repmat(mat1(:) > midValue,1,3);  %# Choose white or black for the
%                                              %#   text color of the strings so
%                                              %#   they can be easily seen over
%                                              %#   the background color
%                                              
% set(hStrings,{'Color'},num2cell(textColors,2));  %# Change the text colors            
            
set(gca,'XTick',1:length(mat1),...                         %# Change the axes tick marks
        'XTickLabel',plot_list,...  %#   and tick labels
        'YTick',1:length(mat1),...
        'YTickLabel',plot_list,...
        'TickLength',[0 0],'FontSize',fontsize);
    
    
    
XTickLabel = get(gca,'XTickLabel');
set(gca,'XTickLabel',' ');
hxLabel = get(gca,'XLabel');
set(hxLabel,'Units','data');
xLabelPosition = get(hxLabel,'Position');
y = xLabelPosition(2)-0.45;
XTick = get(gca,'XTick');
y=repmat(y,length(XTick),1);
fs = get(gca,'fontsize');
hText = text(XTick, y, XTickLabel,'fontsize',fs);
set(hText,'Rotation',90, 'HorizontalAlignment','right');
    
    
    set(gca, 'color', 'white');
    
    filename = [output filesep title_fig '.png'];
        print('-dpng', '-r500', filename);

end
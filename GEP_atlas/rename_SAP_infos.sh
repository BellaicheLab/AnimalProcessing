# for file in /path/to/data/GEPs/SAP_infos/protein/resol40um/*.m; do
#     sed "s|mainpath='/path/to/data/data/Processing17h00/protein/';|mainpath='/path/to/data/GEPs/data/protein/';|g" "$file" > temp && mv temp "$file"
# done

# cd /path/to/data/GEPs/SAP_infos/fish_RNAi/resol40um
# for file in /path/to/data/GEPs/SAP_infos/fish_RNAi/resol40um/*.m; do
# 	filenew="${file#SAP_info_}";
# 	filenew="${filenew%%.m}";
# 	newtext="pathFolderRaw=[mainpath,'$filenew']";
# 	sed '/^pathFolderRaw/ s/.*/"$newtext"/' "$file" > temp && mv temp "$file"
# done


# for file in /path/to/data/GEPs/24hAPF/SAP_infos/protein/40um/*.m; do
#     sed -i "s|mainpath=.*|mainpath='/path/to/data/GEPs/24hAPF/data/protein/';|g" "$file"
# done
for file in /path/to/data/GEPs/24hAPF/SAP_infos/validation_protein/resol40um/*.m; do

    # For 17hAPF
    sed -i "s|mainpath='/path/to/data/GEPs/data/fish/';|mainpath='/path/to/data/GEPs/17hAPF/data/fish/';|g" "$file"
    sed -i "s|mainpath='/path/to/data/GEPs/data/protein/';|mainpath='/path/to/data/GEPs/17hAPF/data/protein/';|g" "$file"
    sed -i "s|mainpath='/path/to/data/GEPs/data/fish_RNAi/';%% Frames to process %%|mainpath='/path/to/data/GEPs/17hAPF/data/fish_RNAi/';|g" "$file"
    
    # For 24hAPF
    sed -i "s|mainpath='/path/to/data/data/Processing24hAPF/24APF_landmark_patterns/for_Matlab/';|mainpath='/path/to/data/GEPs/24hAPF/data/protein/';|g" "$file"
    sed -i "s|mainpath='/path/to/data/data/Processing24hAPF/24APF_validation_patterns_FISH/for_Matlab/';|mainpath='/path/to/data/GEPs/24hAPF/data/validation_fish/';|g" "$file"
    
    sed -i "s|mainpath='/path/to/data/data/Processing24hAPF/24APF_validation_patterns_protein/for_Matlab/';|mainpath='/path/to/data/GEPs/24hAPF/data/validation_protein/';|g" "$file"


done


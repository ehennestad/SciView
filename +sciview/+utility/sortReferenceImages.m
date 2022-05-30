function [sorted, sortedIdx] = sortReferenceImages(imageTypes)


    sortOrder = {'Brain Surface', 'Dura', 'FOV'};


            listInd = cat(2, listInd(contains(imTypes, 'Brain Surface')), ...
                listInd(contains(imTypes, 'Dura')), ...
                listInd(contains(imTypes, 'FOV')));
            
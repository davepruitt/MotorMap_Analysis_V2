classdef MotorMapSet
    
    properties
        
        Maps
        Group
        GroupName
        
    end
    
    methods
        
        function obj = MotorMapSet(file_list)
            for i=1:length(file_list)
                if (~isempty(file_list{i}))
                    maps(i) = MotorMap.CreateMap(file_list{i});
                    MotorMap.VerifyMap(maps(i));
                end
            end
            obj.Maps = maps;
        end
        
        function numeric_array = RetrieveDataset (obj, varargin)
            
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultUseFractionalMeasurements = 1;
            defaultMovementType = MotorMapMovements.Grasp;
            defaultMapType = 'LD';
            defaultCalculateArea = 1;
            defaultSpecial = 'None';
            
            addOptional(p, 'UseFractionalMeasurements', defaultUseFractionalMeasurements);
            addOptional(p, 'MovementType', defaultMovementType);
            addOptional(p, 'MapType', defaultMapType);
            addOptional(p, 'CalculateArea', defaultCalculateArea);
            addOptional(p, 'SpecialCalculation', defaultSpecial);
            parse(p, varargin{:});
            
            movement_type = p.Results.MovementType;
            use_fractional_measurements = p.Results.UseFractionalMeasurements;
            map_type = p.Results.MapType;
            calculate_area = p.Results.CalculateArea;
            special = p.Results.SpecialCalculation;
            
            numeric_array = nan(length(obj.Maps), 1);
            
            for i = 1:length(obj.Maps)
                numeric_array(i) = obj.Maps(i).RetrieveData( ...
                    'UseFractionalMeasurements', use_fractional_measurements, ...
                    'MovementType', movement_type, ...
                    'MapType', map_type, ...
                    'CalculateArea', calculate_area, ...
                    'SpecialCalculation', special);
            end
        end
        
    end
    
    methods (Static)
       
        %The following functions are meant to analyze how callers/placers call/place sites

        function maps_participated = RetrieveTotalMapsParticipated ( map_set, include_placing, include_calling )
            
            if (nargin < 2)
                include_placing = 1;
                include_calling = 1;
            elseif (nargin < 3)
                include_calling = 1;
            end
            
            maps_participated = {};
            
            %Iterate over all maps
            for m = 1:length(map_set.Maps)
                
                placer_data = unique(map_set.Maps(m).Placer);
                caller_data = unique(map_set.Maps(m).Caller);
                
                if (include_placing)
                    for p = 1:length(placer_data)
                        if (~isempty(maps_participated) && size(maps_participated, 1) > 0 && size(maps_participated, 2) > 0)
                            index_of_person = find(strcmpi(maps_participated(:, 1), placer_data(p)), 1, 'first');
                            if (isempty(index_of_person))
                                index_of_person = size(maps_participated, 1) + 1;
                                maps_participated{index_of_person, 1} = placer_data{p};
                                maps_participated{index_of_person, 2} = 1;
                            else
                                maps_participated{index_of_person, 2} = maps_participated{index_of_person, 2} + 1;
                            end
                        else
                            index_of_person = size(maps_participated, 1) + 1;
                            maps_participated{index_of_person, 1} = placer_data{p};
                            maps_participated{index_of_person, 2} = 1;
                        end
                    end
                end
                
                if (include_calling)
                    for p = 1:length(caller_data)
                        if (~isempty(maps_participated) && size(maps_participated, 1) > 0 && size(maps_participated, 2) > 0)
                            index_of_person = find(strcmpi(maps_participated(:, 1), caller_data(p)), 1, 'first');
                            if (isempty(index_of_person))
                                index_of_person = size(maps_participated, 1) + 1;
                                maps_participated{index_of_person, 1} = caller_data{p};
                                maps_participated{index_of_person, 2} = 1;
                            else
                                maps_participated{index_of_person, 2} = maps_participated{index_of_person, 2} + 1;
                            end
                        else
                            index_of_person = size(maps_participated, 1) + 1;
                            maps_participated{index_of_person, 1} = caller_data{p};
                            maps_participated{index_of_person, 2} = 1;
                        end
                    end
                end
                
            end
            
        end
        
        function sites_mapped = RetrieveTotalSitesMappedByEachPerson ( map_set )
            
            placer_data = MotorMapSet.RetrieveTotalPlacedSitesByEachPlacer(map_set);
            caller_data = MotorMapSet.RetrieveTotalCalledSitesByEachCaller(map_set, 1, 1);
            
            all_persons = [placer_data(:, 1); caller_data(:, 1)];
            unique_persons = unique(all_persons);
            
            sites_mapped = {};
            for p = 1:length(unique_persons)
            
                sites_mapped{p, 1} = unique_persons{p};
                
                index_of_caller = find(strcmpi(caller_data(:, 1), unique_persons(p)), 1, 'first');
                index_of_placer = find(strcmpi(placer_data(:, 1), unique_persons(p)), 1, 'first');
                
                s = 0;
                if (~isempty(index_of_caller))
                    s = s + caller_data{index_of_caller, 2};
                end
                   
                if (~isempty(index_of_placer))
                    s = s + placer_data{index_of_placer, 2};
                end
                
                sites_mapped{p, 2} = s;
                
            end
            
            sites_mapped = sortrows(sites_mapped, 2);
            
        end
        
        function sites_placed = RetrieveTotalPlacedSitesByEachPlacer ( map_set )
            
            sites_placed = {};
            
            for m = 1:length(map_set.Maps)
                
                placer_data = map_set.Maps(m).RetrievePlacerData();
                
                for p = 1:size(placer_data, 1)
                    
                    if (~isempty(sites_placed) && size(sites_placed, 1) > 0 && size(sites_placed, 2) > 0)
                        index_of_placer = find(strcmpi(sites_placed(:, 1), placer_data(p, 1)), 1, 'first');
                    else
                        index_of_placer = [];
                    end
                    
                    if (isempty(index_of_placer))
                        sites_placed{end+1, 1} = placer_data{p, 1};
                        sites_placed{end, 2} = placer_data{p, 2};
                    else
                        sites_placed{index_of_placer, 2} = sites_placed{index_of_placer, 2} + placer_data{p, 2};
                    end
                    
                end
                
            end
            
        end
        
        function sites_called = RetrieveTotalCalledSitesByEachCaller ( map_set, long_duration, partial )
            %Given a set of maps, this function returns a dataset indicating how many sites each caller called.
            
            if (nargin < 2)
                long_duration = 1;
                partial = 1;
            elseif (nargin < 3)
                partial = 1;
            end
            
            sites_called = {};
            
            for m = 1:length(map_set.Maps)
                caller_data = map_set.Maps(m).RetrieveCallerData(long_duration, partial);
                
                for c = 1:length(caller_data)
                    
                    if (~isempty(sites_called) && size(sites_called, 1) > 0 && size(sites_called, 2) > 0)
                        index_of_caller = find(strcmpi(sites_called(:, 1), caller_data(c).caller), 1, 'first');
                    else
                        index_of_caller = [];
                    end
                    
                    if (isempty(index_of_caller))
                        sites_called{end+1, 1} = caller_data(c).caller;
                        called_sites_vec = [caller_data(c).call_data{:, 2}];
                        num_called_sites = nansum(called_sites_vec);
                        sites_called{end, 2} = num_called_sites;
                    else
                        called_sites_vec = [caller_data(c).call_data{:, 2}];
                        num_called_sites = nansum(called_sites_vec);
                        sites_called{index_of_caller, 2} = sites_called{index_of_caller, 2} + num_called_sites;
                    end
                    
                end
                
            end
            
        end
        
        function sites_called = RetrieveForelimbSitesByEachCaller ( map_set, long_duration, partial, compress, normalize, kick_out_low_n )
            
            if (nargin < 2)
                long_duration = 1;
                partial = 1;
                compress = 0;
                normalize = 0;
                kick_out_low_n = -1;
            elseif (nargin < 3)
                partial = 1;
                compress = 0;
                normalize = 0;
                kick_out_low_n = -1;
            elseif (nargin < 4)
                compress = 0;
                normalize = 0;
                kick_out_low_n = -1;
            elseif (nargin < 5)
                normalize = 0;
                kick_out_low_n = -1;
            elseif (nargin < 6)
                kick_out_low_n = -1;
            end
            
            sites_called = {};
            
            %Add the first column for the sites called matrix that has all of the forelimb call types
            sites_called{1, 1} = [];
            for f = 1:length(MotorMapMovements.ForelimbMovements)
                sites_called{f+1, 1} = MotorMapMovements.ForelimbMovements(f);
            end
            
            for m = 1:length(map_set.Maps)
                caller_data = map_set.Maps(m).RetrieveCallerForelimbData(long_duration, partial);
                
                for c = 1:length(caller_data)
                    
                    if (size(sites_called, 2) > 1)
                        destination_callers = sites_called(1, 2:end);
                        index_of_destination = find(strcmpi(destination_callers, caller_data(c).caller), 1, 'first') + 1;
                    else
                        index_of_destination = [];
                    end
                    
                    if (~isempty(index_of_destination))
                        
                        for r = 1:length(MotorMapMovements.ForelimbMovements)
                            sites_called{r + 1, index_of_destination} = sites_called{r + 1, index_of_destination} + caller_data(c).call_data{r, 2};
                        end
                        
                    else
                        index_of_destination = size(sites_called, 2) + 1;
                        sites_called{1, index_of_destination} = caller_data(c).caller;
                        for r = 1:length(MotorMapMovements.ForelimbMovements)
                            sites_called{r + 1, index_of_destination} = caller_data(c).call_data{r, 2};
                        end
                    end
                    
                end
                
            end
            
            %Compress the data if the user has asked us to do so
            if (compress)
                compressed_sites_called = {};
                compressed_sites_called{1, 1} = [];
                compressed_sites_called{2, 1} = MotorMapMovements.Distal;
                compressed_sites_called{3, 1} = MotorMapMovements.Proximal;
                
                for c = 2:size(sites_called, 2)
                    
                    distal_count = 0;
                    proximal_count = 0;
                    
                    for r = 1:length(MotorMapMovements.ForelimbMovements)
                        this_movement = MotorMapMovements.ForelimbMovements(r);
                        if (MotorMapMovements.IsDistalForelimb(this_movement))
                            distal_count = distal_count + sites_called{r+1, c};
                        else
                            proximal_count = proximal_count + sites_called{r+1, c};
                        end
                    end
                    
                    compressed_sites_called{1, c} = sites_called{1, c};
                    compressed_sites_called{2, c} = distal_count;
                    compressed_sites_called{3, c} = proximal_count;
                    
                end
                
                sites_called = compressed_sites_called;
                
            end
            
            %Kick out low n if necessary
            if (kick_out_low_n ~= -1)
                
                indices_to_remove = [];
                
                for c = 2:size(sites_called, 2)
                    sum_total_sites_called = nansum([sites_called{2:end, c}]);
                    if (sum_total_sites_called < kick_out_low_n)
                        indices_to_remove = [indices_to_remove c];
                    end
                end
                
                %Remove columns
                sites_called(:, indices_to_remove) = [];
                
            end
            
            %Normalize the data if necessary
            if (normalize)
                
                for c = 2:size(sites_called, 2)
                    
                    sum_total_sites_called = nansum([sites_called{2:end, c}]);
                    
                    for r = 2:size(sites_called, 1)
                        sites_called{r, c} = (sites_called{r, c} / sum_total_sites_called) * 100;
                    end
                    
                end
                
            end
            
        end
        
    end
    
    methods (Static)
        
        %The following methods are meant to plot data sets
        
        function PlotForelimbSitesCalled ( sites_called, sort_by_row )
            
            if (nargin < 2)
                sort_by_row = 0;
                sort_columns = 0;
            end
            
            figure;
            
            numerical_data = [];
            for caller = 2:size(sites_called, 2)
                new_row = [sites_called{2:end, caller}];
                numerical_data = [numerical_data; new_row];
            end
            
            person_names = sites_called(1, 2:end);
            num_persons = length(person_names);
            
            call_types = sites_called(2:end, 1);
            call_type_strings = {};
            for c = 1:length(call_types)
                call_type_strings(end+1) = MotorMapMovements.ConvertFromMovementToLonghand(call_types{c});
            end
            
            %Sort the data before plotting
            if (sort_by_row > 0)
                [sorted, idx] = sortrows(numerical_data, sort_by_row);
                numerical_data = sorted;
                person_names = person_names(idx);
            elseif (sort_by_row == -1)
                %This sort type allows sorting by total called sites
                summed_data = nansum(numerical_data, 2);
                [~, idx] = sort(summed_data);
                numerical_data = numerical_data(idx, :);
                person_names = person_names(idx);
            end
            
            bar(numerical_data, 'stacked');
            set(gca, 'XTick', 1:num_persons);
            set(gca, 'XTickLabel', person_names);
            xlim([0 num_persons+1]);
            legend(call_type_strings);
            
        end
        
        function PlotMapsParticipated ( maps_participated )
            
            figure;
            
            numerical_data = [maps_participated{:, 2}];
            person_names = maps_participated(:, 1);
            
            [sorted_data, idx] = sort(numerical_data);
            numerical_data = sorted_data;
            person_names = person_names(idx);
            
            num_persons = length(numerical_data);
            
            bar(numerical_data);
            set(gca, 'XTick', 1:num_persons);
            set(gca, 'XTickLabel', person_names);
            xlim([0 num_persons+1]);
            
            ylabel('Number of maps participated');
            
            max_ylim = max(ylim);
            ylim([0 max_ylim+1]);
            
        end
        
        function PlotSitesMapped ( sites_mapped )
            
            figure;
            
            numerical_data = [sites_mapped{:, 2}];
            person_names = sites_mapped(:, 1);
            
            [sorted_data, idx] = sort(numerical_data);
            numerical_data = sorted_data;
            person_names = person_names(idx);
            
            num_persons = length(numerical_data);
            
            bar(numerical_data);
            set(gca, 'XTick', 1:num_persons);
            set(gca, 'XTickLabel', person_names);
            xlim([0 num_persons+1]);
            
            xlabel('Mapper');
            ylabel('Sites mapped');
            
        end
        
    end
    
end


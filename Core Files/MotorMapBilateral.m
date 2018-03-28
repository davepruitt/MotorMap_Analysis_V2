classdef MotorMapBilateral
    %MOTORMAP Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        PlacingLeftHemisphere
        PlacingRightHemisphere
        
        MapDataLeftHemisphereContra
        MapDataLeftHemisphereIpsi
        MapDataRightHemisphereContra
        MapDataRightHemisphereIpsi
        
        MapThresholdsLeftHemisphereContra
        MapThresholdsLeftHemisphereIpsi
        MapThresholdsRightHemisphereContra
        MapThresholdsRightHemisphereIpsi
        
        PlacerLeftHemisphere
        CallerLeftHemisphere
        
        PlacerRightHemisphere
        CallerRightHemisphere
        
        RatName
        Voltage_Pk2Pk
        SpO2Max
        SpO2Min
        SpO2Drop
        Weight
        Date
        Impedance
        StartTime
        EndTime
        Group
        
        Updates
        MeanUpdateQuantityIncludingInitial
        MeanUpdateQuantityExcludingInitial
        MeanTimeBetweenUpdatesIncludingInitial
        MeanTimeBetweenUpdatesExcludingInitial
        TotalDrugUsed
        
    end
    
    methods
        
        function obj = MotorMapBilateral ( placing_left, placing_right, placer_left, placer_right, caller_left, caller_right, ...
                thresh_contra_left, thresh_ipsi_left, response_contra_left, response_ipsi_left, ...
                thresh_contra_right, thresh_ipsi_right, response_contra_right, response_ipsi_right, ...
                updates, rat_info )
            
            
            obj.PlacingLeftHemisphere = placing_left;
            obj.PlacingRightHemisphere = placing_right;
            obj.PlacerLeftHemisphere = placer_left;
            obj.PlacerRightHemisphere = placer_right;
            obj.CallerLeftHemisphere = caller_left;
            obj.CallerRightHemisphere = caller_right;
            
            obj.MapThresholdsLeftHemisphereContra = thresh_contra_left;
            obj.MapThresholdsLeftHemisphereIpsi = thresh_ipsi_left;
            obj.MapDataLeftHemisphereContra = response_contra_left;
            obj.MapDataLeftHemisphereIpsi = response_ipsi_left;
            
            obj.MapThresholdsRightHemisphereContra = thresh_contra_right;
            obj.MapThresholdsRightHemisphereIpsi = thresh_ipsi_right;
            obj.MapDataRightHemisphereContra = response_contra_right;
            obj.MapDataRightHemisphereIpsi = response_ipsi_right;

            obj.RatName = '';
            obj.Voltage_Pk2Pk = NaN;
            obj.SpO2Max = NaN;
            obj.SpO2Min = NaN;
            obj.SpO2Drop = NaN;
            obj.Weight = NaN;
            obj.Date = NaN;
            obj.Impedance = NaN;
            obj.StartTime = NaN;
            obj.EndTime = NaN;
            
            if (~isempty(rat_info))
                try
                    obj.RatName = rat_info{1, 2};
                    obj.Voltage_Pk2Pk = rat_info{2, 2};
                    obj.SpO2Max = rat_info{3, 2};
                    obj.SpO2Min = rat_info{4, 2};
                    obj.SpO2Drop = rat_info{3, 2} - rat_info{4, 2};
                    obj.Weight = rat_info{5, 2};
                    obj.Date = rat_info{6, 2};
                    obj.Impedance = rat_info{7, 2};
                    obj.StartTime = rat_info{8, 2};
                    obj.EndTime = rat_info{9, 2};
                catch e
                    e
                end
            end
            
            if (~isempty(updates))
                obj.Updates = updates;
                obj.MeanUpdateQuantityIncludingInitial = nanmean([updates{:, 3}]);
                obj.MeanUpdateQuantityExcludingInitial = nanmean([updates{2:end, 3}]);
                
                update_times = [updates{:, 1}];
                diff_update_times = [];
                for i=1:length(update_times)-1
                    new_diff_update_time = etime(datevec(update_times(i+1)), datevec(update_times(i)));
                    diff_update_times = [diff_update_times new_diff_update_time];
                end
                
                %Convert from seconds to minutes
                diff_update_times = diff_update_times ./ 60;
                
                %Take the mean
                obj.MeanTimeBetweenUpdatesIncludingInitial = nanmean(diff_update_times);
                obj.MeanTimeBetweenUpdatesExcludingInitial = nanmean(diff_update_times(2:end));
                obj.TotalDrugUsed = nansum([updates{:, 3}]);
                
            end
            
        end
        
        
        function num_responses = RetrieveData ( obj, varargin )
            
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultUseFractionalMeasurements = 1;
            defaultMovementType = MotorMapMovements.Grasp;
            defaultCalculateArea = 1;
            defaultSpecialCalculation = 'None';
            defaultHemisphere = 'Left';
            defaultMovementSide = 'Right';
            
            addOptional(p, 'UseFractionalMeasurements', defaultUseFractionalMeasurements);
            addOptional(p, 'MovementType', defaultMovementType);
            addOptional(p, 'Hemisphere', defaultHemisphere);
            addOptional(p, 'MovementSide', defaultMovementSide);
            addOptional(p, 'CalculateArea', defaultCalculateArea);
            addOptional(p, 'SpecialCalculation', defaultSpecialCalculation);
            parse(p, varargin{:});
            
            hemisphere = p.Results.Hemisphere;
            movement_side = p.Results.MovementSide;
            use_fractional_measurements = p.Results.UseFractionalMeasurements;
            calculate_area = p.Results.CalculateArea;
            special_calc = p.Results.SpecialCalculation;
            does_contain_movement_type = p.Results.MovementType;
            
            %Initialize the number of responses to 0
            num_responses = 0;
            
            if (strcmpi(hemisphere, 'Left') && strcmpi(movement_side, 'Left'))
                selected_map = obj.MapDataLeftHemisphereIpsi;
            elseif (strcmpi(hemisphere, 'Left') && strcmpi(movement_side, 'Right'))
                selected_map = obj.MapDataLeftHemisphereContra;
            elseif (strcmpi(hemisphere, 'Right') && strcmpi(movement_side, 'Left'))
                selected_map = obj.MapDataRightHemisphereContra;
            elseif (strcmpi(hemisphere, 'Right') && strcmpi(movement_side, 'Right'))
                selected_map = obj.MapDataRightHemisphereIpsi;
            end
            
            if (strcmpi(special_calc, 'TotalSitesVisited'))
                num_responses = length(selected_map);
                return;
            end
            
            num_sites = length(selected_map);
            for s = 1:num_sites
                
                this_site = selected_map{s};
                amount_to_add = 0;
                
                if (strcmpi(special_calc, 'Distal'))
                    
                    this_site_positives = 0;
                    for i = 1:length(this_site)
                        if (MotorMapMovements.IsDistalForelimb(this_site(i)))
                            this_site_positives = this_site_positives + 1;
                        end
                    end
                    
                    if (use_fractional_measurements)
                        amount_to_add = this_site_positives / length(this_site);
                    else
                        if (this_site_positives > 0)
                            amount_to_add = 1;
                        end
                    end
                    num_responses = num_responses + amount_to_add;
                    
                elseif (strcmpi(special_calc, 'Proximal'))
                    
                    this_site_positives = 0;
                    for i = 1:length(this_site)
                        if (MotorMapMovements.IsProximalForelimb(this_site(i)))
                            this_site_positives = this_site_positives + 1;
                        end
                    end
                    
                    if (use_fractional_measurements)
                        amount_to_add = this_site_positives / length(this_site);
                    else
                        if (this_site_positives > 0)
                            amount_to_add = 1;
                        end
                    end
                    num_responses = num_responses + amount_to_add;
                
                elseif (strcmpi(special_calc, 'Forelimb'))
                    
                    this_site_positives = 0;
                    for i = 1:length(this_site)
                        if (MotorMapMovements.IsForelimb(this_site(i)))
                            this_site_positives = this_site_positives + 1;
                        end
                    end
                    
                    if (use_fractional_measurements)
                        amount_to_add = this_site_positives / length(this_site);
                    else
                        if (this_site_positives > 0)
                            amount_to_add = 1;
                        end
                    end
                    num_responses = num_responses + amount_to_add;
                    
                elseif (strcmpi(special_calc, 'TotalResponsiveSites'))
                    
                    this_site_positives = 0;
                    for i = 1:length(this_site)
                        if (MotorMapMovements.IsResponse(this_site(i)))
                            this_site_positives = this_site_positives + 1;
                        end
                    end
                    
                    if (this_site_positives > 0)
                        amount_to_add = 1;
                    end
                    
                    num_responses = num_responses + amount_to_add;
                    
                else
                    does_contain_movement_type = find(this_site == movement_type, 1, 'first');
                    if (~isempty(does_contain_movement_type))
                        if (use_fractional_measurements)
                            amount_to_add = 1 / length(this_site);
                        else
                            amount_to_add = 1;
                        end
                        num_responses = num_responses + amount_to_add;
                    end
                end
                
            end
            
            if (calculate_area)
                num_responses = num_responses * 0.25;
            end
            
        end
        
        
    end
    
    methods (Static, Access = private)
        
        function [placer, caller, thresh_contra, thresh_ipsi, response_contra, response_ipsi] = ParseMappingData ( raw_data_sheet )
            
            %Initialize the LD matrix as an empty cell array
            response_contra = {};
            response_ipsi = {};
            
            %Initialize some variables we will need
            current_placer = {NaN};
            current_caller = {NaN};
            placer = {};
            caller = {};
            thresh_contra = [];
            thresh_ipsi = [];
            
            %Parse the data
            num_sites = size(raw_data_sheet, 1); 
            num_possible_responses = size(raw_data_sheet, 2);
            for s = 2:num_sites  %We start at index 2 because there is a header row at the first row index
                for n = 1:num_possible_responses
                    
                    if (n == 1)
                        %Check to see if a new placer has been assigned on this site
                        if (iscellstr(raw_data_sheet(s, n)))
                            current_placer = raw_data_sheet(s, n);
                        end
                        placer(end+1) = current_placer;
                    elseif (n == 2)
                        %Check to see if a new caller has been assigned on this site
                        if (iscellstr(raw_data_sheet(s, n)))
                            current_caller = raw_data_sheet(s, n);
                        end
                        caller(end+1) = current_caller;
                    elseif (n == 3)
                        %Check to see what the listed threshold value is
                        thresh_contra(end+1) = raw_data_sheet{s, n};
                    elseif (n == 4)
                        %Check to see what the listed suprathreshold value is
                        thresh_ipsi(end+1) = raw_data_sheet{s, n};
                    else
                        %Otherwise, add the response stored in this cell to the list of responses for this site
                        if (iscellstr(raw_data_sheet(s, n)))
                            this_response = MotorMapMovements.ConvertFromShorthandToMovement(raw_data_sheet(s, n));
                            
                            if (this_response == MotorMapMovements.Undefined)
                                disp(['Undefined movement found: ' raw_data_sheet{s, n}]);
                            end
                            
                            if (n == 5)
                                response_contra{end+1} = this_response;
                            elseif (n == 6)
                                response_ipsi{end+1} = this_response;
                            end
                        else
                            if (n == 5)
                                response_contra{end+1} = MotorMapMovements.NoResponse;
                            elseif (n == 6)
                                response_ipsi{end+1} = MotorMapMovements.NoResponse;
                            end
                        end
                    end
                    
                end
                
            end
            
        end
                
        function [placing_left, placing_right, placer_left, placer_right, caller_left, caller_right, ...
                thresh_contra_left, thresh_ipsi_left, response_contra_left, response_ipsi_left, ...
                thresh_contra_right, thresh_ipsi_right, response_contra_right, response_ipsi_right, ...
                updates, rat_info] = ReadMap ( fully_qualified_path )
            
            [~, ~, placing_raw_left] = xlsread(fully_qualified_path, 'Placing (Left)');
            [~, ~, placing_raw_right] = xlsread(fully_qualified_path, 'Placing (Right)');
            [~, ~, sd_raw_left] = xlsread(fully_qualified_path, 'SD (Left)');
            [~, ~, sd_raw_right] = xlsread(fully_qualified_path, 'SD (Right)');
            [~, ~, updates_raw] = xlsread(fully_qualified_path, 'Updates');
            [~, ~, rat_info_raw] = xlsread(fully_qualified_path, 'Rat Information');
            
            %Assign the placing matrix
            placing_left = cell2mat(placing_raw_left(2:end, 2:end));
            placing_right = cell2mat(placing_raw_right(2:end, 2:end));
            
            %Parse the left hemisphere data
            [placer_left, caller_left, thresh_contra_left, thresh_ipsi_left, response_contra_left, response_ipsi_left] = MotorMapBilateral.ParseMappingData ( sd_raw_left );
            
            %Parse the right hemisphere data
            [placer_right, caller_right, thresh_contra_right, thresh_ipsi_right, response_contra_right, response_ipsi_right] = MotorMapBilateral.ParseMappingData ( sd_raw_right );
            
            %Parse the drug-update information
            updates = updates_raw(2:end, :);
            
            %Parse out the rat information
            rat_info = rat_info_raw;
            
        end
        
    end
    
    methods (Static)
        
        function obj = CreateMap ( fully_qualified_path )
            
            [placing_left, placing_right, placer_left, placer_right, caller_left, caller_right, ...
                thresh_contra_left, thresh_ipsi_left, response_contra_left, response_ipsi_left, ...
                thresh_contra_right, thresh_ipsi_right, response_contra_right, response_ipsi_right, ...
                updates, rat_info] = MotorMapBilateral.ReadMap ( fully_qualified_path );
            
            obj = MotorMapBilateral(placing_left, placing_right, placer_left, placer_right, caller_left, caller_right, ...
                thresh_contra_left, thresh_ipsi_left, response_contra_left, response_ipsi_left, ...
                thresh_contra_right, thresh_ipsi_right, response_contra_right, response_ipsi_right, ...
                updates, rat_info);
            
        end

        function VerifyMap ( map )
            
            %Display message to the user that this map is being verified
            disp([map.RatName ': Verifying map (LEFT hemisphere)...']);
            MotorMapBilateral.VerifyMap2(map, map.PlacingLeftHemisphere, map.MapDataLeftHemisphereContra, map.MapDataLeftHemisphereIpsi);
            
            disp([map.RatName ': Verifying map (RIGHT hemisphere)...']);
            MotorMapBilateral.VerifyMap2(map, map.PlacingRightHemisphere, map.MapDataRightHemisphereContra, map.MapDataRightHemisphereIpsi);
            
        end
        
        function VerifyMap2 ( map, p, c, i )
            
            good = 1;
            
            %First, collapse the placing data into a one-dimensional array
            total_elements = size(p, 1) * size(p, 2);
            reshaped_data = reshape(p, 1, total_elements);
            
            %Next, sort the array and remove all 0's from the array
            reshaped_data = sort(reshaped_data);
            reshaped_data(reshaped_data == 0) = [];
            
            %Now check for gaps in the array
            diff_array = diff(reshaped_data);
            if (any(diff_array ~= 1))
               disp('Gaps found in placing matrix!');
               good = 0;
            end
            
            %Check for missing values in the placing matrix
            values = 1:length(reshaped_data);
            missing_values = setdiff(values, reshaped_data);
            if (~isempty(missing_values))
                good = 0;
                disp('The following values are missing from the placing matrix: ');
                for i = 1:length(missing_values)
                    disp(num2str(missing_values(i)));
                end
            end
            
            %Check for duplicates
            [~, ind] = unique(reshaped_data);
            duplicate_indices = setdiff(1:length(reshaped_data), ind);
            duplicate_values = reshaped_data(duplicate_indices);
            if (~isempty(duplicate_values))
                good = 0;
                disp('Duplicate values found in placing matrix: ');
                for i = 1:length(duplicate_values)
                    disp(num2str(duplicate_values(i)));
                end
            end
            
            %Make sure that the placing matrix has the same site count as the caller's data
            placing_matrix_size = length(reshaped_data);
            placing_matrix_max = max(reshaped_data);
            num_sites_called_ld = length(c);
            num_sites_called_sd = length(i);
            
            if (isempty(placing_matrix_max))
                placing_matrix_max = 0;
            end
            
            if (~(placing_matrix_size == num_sites_called_ld && placing_matrix_max == num_sites_called_ld))
                good = 0;
                disp('Number of called sites (long duration) does not match number of placed sites!');
            end
            
            if (~(placing_matrix_size == num_sites_called_sd && placing_matrix_max == num_sites_called_sd))
                good = 0;
                disp('Number of called sites (short duration) does not match number of placed sites!');
            end
            
            if (good == 1)
                disp([map.RatName ': Successfully verified map.']);
            else
                disp([map.RatName ': Problems found with map! Fix the data file and re-load it into Matlab.']);
            end
            
        end
        
    end
    
end





























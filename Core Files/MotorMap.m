classdef MotorMap
    %MOTORMAP Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        PlacingData
        MapDataLongDuration
        MapDataShortDuration
        MapThresholdsLongDuration
        MapThresholdsShortDuration
        MapSuprathresholdsLongDuration
        MapSuprathresholdsShortDuration
        Placer
        Caller
        
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
        SD_Supra
        
        Updates
        MeanUpdateQuantityIncludingInitial
        MeanUpdateQuantityExcludingInitial
        MeanTimeBetweenUpdatesIncludingInitial
        MeanTimeBetweenUpdatesExcludingInitial
        TotalDrugUsed
        
    end
    
    methods
        
        function obj = MotorMap ( varargin )
            
            %Handle optional input parameters
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultPlacing = [];
            defaultLongDuration = [];
            defaultShortDuration = [];
            defaultUpdates = [];
            defaultRatInformation = [];
            defaultPlacer = {};
            defaultCaller = {};
            defaultLDThresh = [];
            defaultSDThresh = [];
            defaultLDSupra = [];
            defaultSDSupra = [];
            
            addOptional(p, 'Placing', defaultPlacing);
            addOptional(p, 'Placer', defaultPlacer);
            addOptional(p, 'Caller', defaultCaller);
            addOptional(p, 'LongDurationThresholds', defaultLDThresh);
            addOptional(p, 'ShortDurationThresholds', defaultSDThresh);
            addOptional(p, 'LongDurationSuprathresholds', defaultLDSupra);
            addOptional(p, 'ShortDurationSuprathresholds', defaultSDSupra);
            addOptional(p, 'LongDuration', defaultLongDuration);
            addOptional(p, 'ShortDuration', defaultShortDuration);
            addOptional(p, 'Updates', defaultUpdates);
            addOptional(p, 'RatInformation', defaultRatInformation);
            parse(p, varargin{:});
            
            obj.PlacingData = p.Results.Placing;
            obj.MapDataLongDuration = p.Results.LongDuration;
            obj.MapDataShortDuration = p.Results.ShortDuration;
            obj.MapThresholdsLongDuration = p.Results.LongDurationThresholds;
            obj.MapThresholdsShortDuration = p.Results.ShortDurationThresholds;
            obj.MapSuprathresholdsLongDuration = p.Results.LongDurationSuprathresholds;
            obj.MapSuprathresholdsShortDuration = p.Results.ShortDurationSuprathresholds;
            obj.Placer = p.Results.Placer;
            obj.Caller = p.Results.Caller;
            
            rat_info = p.Results.RatInformation;
            updates = p.Results.Updates;
            
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
            defaultMapType = 'LD';
            defaultCalculateArea = 1;
            defaultSpecialCalculation = 'None';
            
            addOptional(p, 'UseFractionalMeasurements', defaultUseFractionalMeasurements);
            addOptional(p, 'MovementType', defaultMovementType);
            addOptional(p, 'MapType', defaultMapType);
            addOptional(p, 'CalculateArea', defaultCalculateArea);
            addOptional(p, 'SpecialCalculation', defaultSpecialCalculation);
            parse(p, varargin{:});
            
            movement_type = p.Results.MovementType;
            use_fractional_measurements = p.Results.UseFractionalMeasurements;
            map_type = p.Results.MapType;
            calculate_area = p.Results.CalculateArea;
            special_calc = p.Results.SpecialCalculation;
            
            %Initialize the number of responses to 0
            num_responses = 0;
            
            if (strcmpi(map_type, 'LD'))
                selected_map = obj.MapDataLongDuration;
            else
                selected_map = obj.MapDataShortDuration;
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
                    
                elseif (strcmpi(special_calc, 'TotalCombinedGraspWithElbow'))
                    
                    this_site_positives = 0;
                    
                    contains_grasp = ~isempty(find(this_site == MotorMapMovements.Grasp, 1, 'first'));
                    contains_ef = ~isempty(find(this_site == MotorMapMovements.ElbowFlexion, 1, 'first'));
                    if (contains_grasp && contains_ef)
                        this_site_positives = this_site_positives + 1;
                    end
                    
                    num_responses = num_responses + this_site_positives;
                    
                elseif (strcmpi(special_calc, 'TotalCombinedGraspOrElbow'))
                    
                    this_site_positives = 0;
                    
                    contains_grasp = ~isempty(find(this_site == MotorMapMovements.Grasp, 1, 'first'));
                    contains_ef = ~isempty(find(this_site == MotorMapMovements.ElbowFlexion, 1, 'first'));
                    if (contains_grasp || contains_ef)
                        this_site_positives = this_site_positives + 1;
                    end
                    
                    num_responses = num_responses + this_site_positives;
                    
                elseif (strcmpi(special_calc, 'TotalMultijoint'))
                    
                    is_distal = 0;
                    is_proximal = 0;
                    
                    for i = 1:length(this_site)
                        if (MotorMapMovements.IsDistalForelimb(this_site(i)))
                            is_distal = 1;
                        end
                        if (MotorMapMovements.IsProximalForelimb(this_site(i)))
                            is_proximal = 1;
                        end
                    end
                    
                    if (is_distal && is_proximal)
                        amount_to_add = 1;
                    else
                        amount_to_add = 0;
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
        
        function [placing_mean, placing_err, placing_mask_array] = RetrievePlacingDistanceData ( obj, include_corners )
            %This function first calculates the placing mask, and then it uses the mask to calculate the mean time-distance
            %between all sites in the map, along with the standard error.  It returns this data to the caller.
           
            if (nargin < 2)
                include_corners = 0;
            end
            
            placing_mask = obj.RetrievePlacingMask(include_corners);
            
            placing_mask_array = reshape(placing_mask, 1, size(placing_mask, 1) * size(placing_mask, 2));
            placing_mask_array(isnan(placing_mask_array)) = [];
            
            placing_mean = mean(placing_mask_array);
            placing_err = std(placing_mask_array) / sqrt(length(placing_mask_array));
            
        end
        
        function placing_mask = RetrievePlacingMask ( obj, include_corners )
            %This function calculates the average time-distance between a site and all adjacent sites
            
            if (nargin < 2)
                include_corners = 0;
            end
            
            placing_mask = nan(size(obj.PlacingData, 1), size(obj.PlacingData, 2));
            
            for r = 1:size(obj.PlacingData, 1)
                for c = 1:size(obj.PlacingData, 2)
                    
                    if (obj.PlacingData(r, c) == 0)
                       placing_mask(r, c) = NaN;
                       continue;
                    end
                    
                    this_cell_values = nan(1, 8);
                    
                    above = r - 1;
                    below = r + 1;
                    to_the_left = c - 1;
                    to_the_right = c + 1;
                    
                    if (above > 0)
                        if (obj.PlacingData(above, c) > 0)
                            this_cell_values(1) = obj.PlacingData(r, c) - obj.PlacingData(above, c);
                        end
                    end
                    
                    if (to_the_left > 0)
                        if (obj.PlacingData(r, to_the_left) > 0)
                            this_cell_values(2) = obj.PlacingData(r, c) - obj.PlacingData(r, to_the_left);
                        end
                    end
                    
                    if (below <= size(obj.PlacingData, 1))
                        if (obj.PlacingData(below, c) > 0)
                            this_cell_values(3) = obj.PlacingData(r, c) - obj.PlacingData(below, c);
                        end
                    end
                    
                    if (to_the_right <= size(obj.PlacingData, 2))
                        if (obj.PlacingData(r, to_the_right) > 0)
                            this_cell_values(4) = obj.PlacingData(r, c) - obj.PlacingData(r, to_the_right);
                        end
                    end
                    
                    if (include_corners)
                        
                        if (above > 0 && to_the_left > 0)
                            if (obj.PlacingData(above, to_the_left) > 0)
                                this_cell_values(5) = obj.PlacingData(r, c) - obj.PlacingData(above, to_the_left);
                            end
                        end
                        
                        if (above > 0 && to_the_right <= size(obj.PlacingData, 2))
                            if (obj.PlacingData(above, to_the_right) > 0)
                                this_cell_values(6) = obj.PlacingData(r, c) - obj.PlacingData(above, to_the_right);
                            end
                        end
                        
                        if (below <= size(obj.PlacingData, 1) && to_the_left > 0)
                            if (obj.PlacingData(below, to_the_left) > 0)
                                this_cell_values(7) = obj.PlacingData(r, c) - obj.PlacingData(below, to_the_left);
                            end
                        end
                        
                        if (below <= size(obj.PlacingData, 1) && to_the_right <= size(obj.PlacingData, 2))
                            if (obj.PlacingData(below, to_the_right) > 0)
                                this_cell_values(8) = obj.PlacingData(r, c) - obj.PlacingData(below, to_the_right);
                            end
                        end
                        
                    end
                    
                    
                    mean_of_all_differences = nanmean(abs(this_cell_values));
                    
                    placing_mask(r, c) = mean_of_all_differences;
                    
                end
            end
            
        end
        
        function placer_data = RetrievePlacerData ( obj )
            %This function returns the number of sites placed by each unique placer
            
            unique_placers = unique(obj.Placer);
            
            placer_data = {};
            for p = 1:length(unique_placers)
                placer_data{p, 1} = unique_placers{p};
                placer_data{p, 2} = sum(strcmpi(obj.Placer, unique_placers(p)));
            end
            
        end
        
        function result = DidCallerCallForelimb ( obj, caller_id, long_duration )
            
            if (nargin < 3)
                long_duration = 1;
            end
            
            result = 0;
            
            
            this_map_callers = unique(obj.Caller);
            if (any(strcmpi(this_map_callers, caller_id)))
                
                site_indices = find(strcmpi(obj.Caller, caller_id));
                for f = 1:length(site_indices)
                    
                    site_index = site_indices(f);
                    
                    if (long_duration)
                        responses = obj.MapDataLongDuration{site_index};
                    else
                        responses = obj.MapDataShortDuration{site_index};
                    end
                    
                    for r = 1:length(responses)
                        if (MotorMapMovements.IsForelimb(responses(r)))
                            result = 1;
                        end
                    end
                end
            end
            
        end
        
        function caller_data = RetrieveCompressedCallerForelimbData ( obj, long_duration, partial )
            
            if (nargin < 2)
                long_duration = 1;
                partial = 0;
            elseif (nargin < 3)
                partial = 0;
            end
            
            caller_data_pre = obj.RetrieveCallerForelimbData(long_duration, partial);
            
            caller_data = {};
            caller_data{1, 1} = [];
            caller_data{2, 1} = MotorMapMovements.Distal;
            caller_data{3, 1} = MotorMapMovements.Proximal;
            
            %Iterate over each caller
            for c = 1:length(caller_data_pre)
                
                column_index = c + 1;
                distal_count = 0;
                proximal_count = 0;
                
                for r = 1:length(MotorMapMovements.ForelimbMovements)
                    this_movement = MotorMapMovements.ForelimbMovements(r);
                    if (MotorMapMovements.IsDistalForelimb(this_movement))
                        distal_count = distal_count + caller_data_pre(c).call_data{r, 2};
                    else
                        proximal_count = proximal_count + caller_data_pre(c).call_data{r, 2};
                    end
                end

                caller_data{1, column_index} = caller_data_pre(c).caller;
                caller_data{2, column_index} = distal_count;
                caller_data{3, column_index} = proximal_count;
                
            end
            
        end
        
        function caller_data = RetrieveTotalForelimbSitesPerCaller ( obj, long_duration )
            
            if (nargin < 2)
                long_duration = 1;
            end
            
            caller_data_pre = obj.RetrieveCallerForelimbData(long_duration, 1);
            
            caller_data = cell(length(caller_data_pre), 2);
            
            for c = 1:length(caller_data_pre)
                caller_data{c, 1} = caller_data_pre(c).caller;
                caller_data{c, 2} = nansum([caller_data_pre(c).call_data{:, 2}]);
            end
            
        end
        
        function caller_data = RetrieveCallerData ( obj, long_duration, partial )
            %This function returns the number of sites (of each type) called by each unique caller
            
            if (nargin < 2)
                long_duration = 1;
                partial = 0;
            elseif (nargin < 3)
                partial = 0;
            end
            
            unique_callers = unique(obj.Caller);
            
            caller_data = struct('caller', {}, 'call_data', {});
            all_movements = enumeration(MotorMapMovements.Vibrissa);
            number_of_unique_movements = length(all_movements);
            
            for c = 1:length(unique_callers)
                
                this_caller_data = [];
                this_caller_data.caller = unique_callers{c};
                this_caller_data.call_data = cell(number_of_unique_movements, 2);
                
                this_caller_indices = find(strcmpi(obj.Caller, unique_callers{c}));
                if (long_duration)
                    this_caller_calls = obj.MapDataLongDuration(this_caller_indices);
                else
                    this_caller_calls = obj.MapDataShortDuration(this_caller_indices);
                end
                
                for f = 1:number_of_unique_movements
                    movement_value = all_movements(f);
                    
                    this_caller_data.call_data{f, 1} = movement_value;
                    
                    movement_value_count = 0;
                    for r = 1:length(this_caller_calls)
                        responses = this_caller_calls{r};
                        responses_of_this_movement = length(find(responses == movement_value));
                        
                        if (partial)
                            responses_of_this_movement = responses_of_this_movement / length(responses);
                        end
                        
                        movement_value_count = movement_value_count + responses_of_this_movement;
                    end
                    
                    this_caller_data.call_data{f, 2} = movement_value_count;
                    
                end
                
                caller_data(c) = this_caller_data;
                
            end
            
        end
        
        function caller_data = RetrieveCallerForelimbData ( obj, long_duration, partial )
            %This function returns the number of sites (of each type) called by each unique caller
            
            if (nargin < 2)
                long_duration = 1;
                partial = 0;
            elseif (nargin < 3)
                partial = 0;
            end
            
            unique_callers = unique(obj.Caller);
            
            caller_data = struct('caller', {}, 'call_data', {});
            number_of_unique_forelimb_movements = length(MotorMapMovements.ForelimbMovements);
            
            for c = 1:length(unique_callers)
                
                this_caller_data = [];
                this_caller_data.caller = unique_callers{c};
                this_caller_data.call_data = cell(number_of_unique_forelimb_movements, 2);
                
                this_caller_indices = find(strcmpi(obj.Caller, unique_callers{c}));
                if (long_duration)
                    this_caller_calls = obj.MapDataLongDuration(this_caller_indices);
                else
                    this_caller_calls = obj.MapDataShortDuration(this_caller_indices);
                end
                
                for f = 1:number_of_unique_forelimb_movements
                    movement_value = MotorMapMovements.ForelimbMovements(f);
                    
                    this_caller_data.call_data{f, 1} = movement_value;
                    
                    movement_value_count = 0;
                    for r = 1:length(this_caller_calls)
                        responses = this_caller_calls{r};
                        responses_of_this_movement = length(find(responses == movement_value));
                        
                        if (partial)
                            responses_of_this_movement = responses_of_this_movement / length(responses);
                        end
                        
                        movement_value_count = movement_value_count + responses_of_this_movement;
                    end
                    
                    this_caller_data.call_data{f, 2} = movement_value_count;
                    
                end
                
                caller_data(c) = this_caller_data;
                
            end
            
        end
        
        function PlotMap ( obj, varargin )
            
            %Handle optional input parameters
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultPlotStyle = obj.PlotStyleNormal;
            defaultPlotNoResponses = 0;
            defaultPlotEdgeLines = 1;
            defaultSignificanceMap = [];
            defaultNoResponsesWithXMarker = 0;
            defaultPlotGridLines = 1;
            defaultPlotLegend = 0;
            defaultSimplifyMap = 0;
            defaultPlotInterpolatedHeatMap = 1;
            addOptional(p, 'PlotStyle', defaultPlotStyle, @isnumeric);
            addOptional(p, 'PlotNoResponseSites', defaultPlotNoResponses, @isnumeric);
            addOptional(p, 'PlotEdgeLines', defaultPlotEdgeLines, @isnumeric);
            addOptional(p, 'SignificanceMap', defaultSignificanceMap);
            addOptional(p, 'NoResponsesWithXMarker', defaultNoResponsesWithXMarker, @isnumeric);
            addOptional(p, 'PlotGridLines', defaultPlotGridLines, @isnumeric);
            addOptional(p, 'PlotLegend', defaultPlotLegend, @isnumeric);
            addOptional(p, 'SimplifyMap', defaultSimplifyMap, @isnumeric);
            addOptional(p, 'PlotInterpolatedHeatMap', defaultPlotInterpolatedHeatMap, @isnumeric);
            parse(p, varargin{:});
            plot_style = p.Results.PlotStyle;
            plot_no_responses = p.Results.PlotNoResponseSites;
            plot_edge_lines = p.Results.PlotEdgeLines;
            significance_map = p.Results.SignificanceMap;
            no_responses_with_x = p.Results.NoResponsesWithXMarker;
            plot_grid_lines = p.Results.PlotGridLines;
            plot_legend = p.Results.PlotLegend;
            simplify_map = p.Results.SimplifyMap;
            plot_interpolated_heat_map = p.Results.PlotInterpolatedHeatMap;
            
            %Plot the map
            f.fig = figure('units', 'centimeters', ...
                'position', [1 3 16 22], ...
                'color', 'w');
            f.axes = axes('parent', f.fig, ...
                'units', 'centimeters', ...
                'position', [2 2 13 19]);
            set(gca, 'clipping', 'off');

            f.colors = obj.PlotColorsNormal;
            hold on;

            if (plot_style == obj.PlotStyleNormal)
                
                x_size = size(obj.MapData, 1);
                y_size = size(obj.MapData, 2);
                
                %Draw grid lines
                if (plot_grid_lines)
                    max_xval = length(MotorMap.MapMLCoordinates)+1;
                    max_yval = length(MotorMap.MapAPCoordinates)+1;
                    for y = 1:max_yval
                        line([0 max_xval], [y y], 'LineStyle', ':', 'Color', [0.7 0.7 0.7]);
                    end
                    for x = 1:max_xval
                        line([x x], [0 max_yval], 'LineStyle', ':', 'Color', [0.7 0.7 0.7]);
                    end
                end
                
                %Plot the legend
                if (plot_legend)
                    set(gcf, 'position', [1 3 23 22]);
                    xval_legend = length(MotorMap.MapMLCoordinates)+2.1;
                    top_yval = length(MotorMap.MapAPCoordinates)+0.1;
                    
                    if (~simplify_map)
                        rectangle('Position', [xval_legend top_yval 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Vibrissa, :));
                        rectangle('Position', [xval_legend top_yval-1 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Face, :));
                        rectangle('Position', [xval_legend top_yval-2 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Neck, :));
                        rectangle('Position', [xval_legend top_yval-3 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.DistalForelimb, :));
                        rectangle('Position', [xval_legend top_yval-4 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.ProximalForelimb, :));
                        rectangle('Position', [xval_legend top_yval-5 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Shoulder, :));
                        rectangle('Position', [xval_legend top_yval-6 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Hindlimb, :));

                        text(xval_legend+1, top_yval+0.5, MotorMap.MapStrings(MotorMap.Vibrissa), 'FontSize', 18);
                        text(xval_legend+1, top_yval-0.5, MotorMap.MapStrings(MotorMap.Face), 'FontSize', 18);
                        text(xval_legend+1, top_yval-1.5, MotorMap.MapStrings(MotorMap.Neck), 'FontSize', 18);
                        text(xval_legend+1, top_yval-2.5, MotorMap.MapStrings(MotorMap.DistalForelimb), 'FontSize', 18);
                        text(xval_legend+1, top_yval-3.5, MotorMap.MapStrings(MotorMap.ProximalForelimb), 'FontSize', 18);
                        text(xval_legend+1, top_yval-4.5, MotorMap.MapStrings(MotorMap.Shoulder), 'FontSize', 18);
                        text(xval_legend+1, top_yval-5.5, MotorMap.MapStrings(MotorMap.Hindlimb), 'FontSize', 18);
                    else
                        rectangle('Position', [xval_legend top_yval 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Vibrissa, :));
                        rectangle('Position', [xval_legend top_yval-1 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.DistalForelimb, :));
                        rectangle('Position', [xval_legend top_yval-2 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Hindlimb, :));
                        text(xval_legend+1, top_yval+0.5, MotorMap.MapStrings(MotorMap.TotalHead), 'FontSize', 18);
                        text(xval_legend+1, top_yval-0.5, MotorMap.MapStrings(MotorMap.TotalForelimb), 'FontSize', 18);
                        text(xval_legend+1, top_yval-1.5, MotorMap.MapStrings(MotorMap.Hindlimb), 'FontSize', 18);
                    end
                end
                
                if (obj.IsProbabilityMap)
                    %colors = flipud(jet(100));
                    colors = jet(100);
                    colormap(colors);
                end
                
                for x = 1:x_size
                    for y = 1:y_size
                        
                        if (obj.IsProbabilityMap)
                            
                            if (plot_interpolated_heat_map)
                                
                                probability_map = obj.MapData;
                                interpolated_data = interp2(probability_map, 5);
                                interpolated_data = interpolated_data';
                                interpolated_data = interpolated_data * 100;
                                
                                %min_x = min(MotorMap.MapAPCoordinates);
                                %max_x = max(MotorMap.MapAPCoordinates);
                                %min_y = min(MotorMap.MapMLCoordinates);
                                %max_y = max(MotorMap.MapMLCoordinates);
                                
                                min_x = 1;
                                max_x = length(MotorMap.MapAPCoordinates) + 1;
                                min_y = 1;
                                max_y = length(MotorMap.MapMLCoordinates) + 1;
                                
                                rectangle('Position', [0 0 max_y+0.1 max_x+0.1], 'FaceColor', colors(1, :));
                                image('YData', [min_x max_x], 'XData', [min_y max_y], 'CData', interpolated_data);
                                
                                
                                
                            else
                                
                                probability = obj.MapData(x, y);
                                override_edge_color = 0;
                                if (~isempty(significance_map))
                                    if (significance_map(x, y) > 0)
                                        if (probability == 0)
                                            rectangle('Position', [x y 1 1], 'FaceColor', [1 1 1], 'EdgeColor', [1 0 0]);
                                        else
                                            override_edge_color = 1;
                                        end
                                    end
                                end

                                if (probability > 0)
                                    fill_color = colors(round(probability * 100), :);
                                    edge_color = [0 0 0];
                                    if (~plot_edge_lines)
                                        edge_color = fill_color;
                                    end

                                    if (override_edge_color)
                                        edge_color = [1 0 0];
                                        fill_color = [1 0 0];
                                    end

                                    rectangle('Position', [x y 1 1], 'FaceColor', fill_color, 'EdgeColor', edge_color);
                                end
                                
                            end
                            

                            
                        else
                            data_point = obj.MapData(x, y);

                            if (~isnan(data_point))
                                if ((data_point == MotorMap.NoResponse && plot_no_responses) || data_point ~= MotorMap.NoResponse)
                                    
                                    if (simplify_map)
                                        if (data_point == MotorMap.Vibrissa || ...
                                            data_point == MotorMap.Face || ...
                                            data_point == MotorMap.Neck)
                                            fill_color = f.colors(MotorMap.Vibrissa, :);
                                        elseif (data_point == MotorMap.DistalForelimb || ...
                                            data_point == MotorMap.ProximalForelimb || ...
                                            data_point == MotorMap.Shoulder)
                                            fill_color = f.colors(MotorMap.DistalForelimb, :);
                                        else
                                            fill_color = f.colors(data_point, :);
                                        end
                                    else
                                        fill_color = f.colors(data_point, :);    
                                    end
                                    
                                    edge_color = [0 0 0];
                                    if (~plot_edge_lines)
                                        edge_color = fill_color;
                                    end
                                    
                                    
                                    if (data_point == MotorMap.NoResponse && no_responses_with_x)
                                        line([x+0.4 x+0.6], [y+0.4 y+0.6], 'Color', 'k', 'LineWidth', 2);
                                        line([x+0.4 x+0.6], [y+0.6 y+0.4], 'Color', 'k', 'LineWidth', 2);
                                    else
                                        rectangle('Position', [x y 1 1], 'FaceColor', fill_color, 'EdgeColor', edge_color);
                                    end
                                end
                            end
                        end
                    end
                end
                
                set(gca, 'xlim', [0 14]);
                set(gca, 'xtick', [1.5 11.5]);
                set(gca, 'xticklabel', {'0' '5'});
                
                set(gca, 'ylim', [0 20]);
                set(gca, 'ytick', [1.5 9.5 19.5]);
                set(gca, 'yticklabel', {'-4' '0' '5'});
                
                set(gca, 'fontsize', 18);
                set(gca, 'fontweight', 'bold');
                
                xlabel('Lateral', 'fontsize', 18);
                ylabel('Anterior', 'fontsize', 18);
                
                %Arrow next to the xlabel
                line([8.5 11], [-1.6 -1.6], 'Color', [0 0 0], 'LineWidth', 2);
                line([10.75 11], [-1.5 -1.6], 'Color', [0 0 0], 'LineWidth', 2);
                line([10.75 11], [-1.7 -1.6], 'Color', [0 0 0], 'LineWidth', 2);
                
                %Arrow next to the ylabel
                line([-1.25 -1.25], [12 14.5], 'Color', [0 0 0], 'LineWidth', 2);
                line([-1.15 -1.25], [14.25 14.5], 'Color', [0 0 0], 'LineWidth', 2);
                line([-1.35 -1.25], [14.25 14.5], 'Color', [0 0 0], 'LineWidth', 2);
                
                if (obj.IsProbabilityMap)
                    colorbar();
                end
                
            else
                %Not normal plot style
                %TO DO: this code
                disp('Error: code has not yet been written to plot in this style');
            end
            
            
        end
        
        function PlotMap2 ( obj, varargin )
            
            %Handle optional input parameters
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultPlotStyle = obj.PlotStyleNormal;
            defaultPlotNoResponses = 0;
            defaultPlotEdgeLines = 1;
            defaultSignificanceMap = [];
            defaultNoResponsesWithXMarker = 0;
            defaultPlotGridLines = 1;
            defaultPlotLegend = 0;
            defaultSimplifyMap = 0;
            defaultPlotInterpolatedHeatMap = 1;
            defaultAxes = 0;
            defaultLegendForelimbOnly = 0;
            defaultBregmaIndicatorColor = [0.5 0.5 0.5];
            defaultLegendLocation = 0;
            addOptional(p, 'PlotStyle', defaultPlotStyle, @isnumeric);
            addOptional(p, 'PlotNoResponseSites', defaultPlotNoResponses, @isnumeric);
            addOptional(p, 'PlotEdgeLines', defaultPlotEdgeLines, @isnumeric);
            addOptional(p, 'SignificanceMap', defaultSignificanceMap);
            addOptional(p, 'NoResponsesWithXMarker', defaultNoResponsesWithXMarker, @isnumeric);
            addOptional(p, 'PlotGridLines', defaultPlotGridLines, @isnumeric);
            addOptional(p, 'PlotLegend', defaultPlotLegend, @isnumeric);
            addOptional(p, 'SimplifyMap', defaultSimplifyMap, @isnumeric);
            addOptional(p, 'PlotInterpolatedHeatMap', defaultPlotInterpolatedHeatMap, @isnumeric);
            addOptional(p, 'Axes', defaultAxes);
            addOptional(p, 'BregmaIndicatorColor', defaultBregmaIndicatorColor);
            addOptional(p, 'LegendForelimbOnly', defaultLegendForelimbOnly);
            addOptional(p, 'LegendLocation', defaultLegendLocation);
            parse(p, varargin{:});
            plot_style = p.Results.PlotStyle;
            plot_no_responses = p.Results.PlotNoResponseSites;
            plot_edge_lines = p.Results.PlotEdgeLines;
            significance_map = p.Results.SignificanceMap;
            no_responses_with_x = p.Results.NoResponsesWithXMarker;
            plot_grid_lines = p.Results.PlotGridLines;
            plot_legend = p.Results.PlotLegend;
            simplify_map = p.Results.SimplifyMap;
            plot_interpolated_heat_map = p.Results.PlotInterpolatedHeatMap;
            map_plot_axes = p.Results.Axes;
            bregma_circle_color = p.Results.BregmaIndicatorColor;
            legend_forelimb_only = p.Results.LegendForelimbOnly;
            legend_location = p.Results.LegendLocation;
            
            %Grab the figure that the user passed in, or create a new figure.
            axes_width = 5.8;
            axes_height = 7.66;
            
            figure_class = class(map_plot_axes);
            if (strcmpi(figure_class, 'matlab.graphics.axis.Axes'))
                %map_position = get(map_plot_axes, 'position');
                %set(map_plot_axes, ...
                %    'units', 'centimeters', ...
                %    'position', [map_position(1) map_position(2) axes_width axes_height]);
            else
                %Plot the map
                f.fig = figure('units', 'centimeters', ...
                    'position', [1 3 16 22], ...
                    'color', 'w');
                f.axes = axes('parent', f.fig, ...
                    'units', 'centimeters', ...
                    'position', [2 2 13 19]);
                set(gca, 'clipping', 'off');

                f.colors = obj.PlotColorsNormal;
                hold on;
            end
            
            f.colors = obj.PlotColorsNormal;
            
            if (plot_style == obj.PlotStyleNormal)
                
                x_size = size(obj.MapData, 1);
                y_size = size(obj.MapData, 2);
                
                %Draw grid lines
                if (plot_grid_lines)
                    max_xval = length(MotorMap.MapMLCoordinates)+1;
                    max_yval = length(MotorMap.MapAPCoordinates)+1;
                    for y = 1:max_yval
                        line([0 max_xval], [y y], 'LineStyle', ':', 'Color', [0.7 0.7 0.7]);
                    end
                    for x = 1:max_xval
                        line([x x], [0 max_yval], 'LineStyle', ':', 'Color', [0.7 0.7 0.7]);
                    end
                end
                
                if (plot_legend)
                    xval_legend = length(MotorMap.MapMLCoordinates)-4.5;
                    top_yval = length(MotorMap.MapAPCoordinates)-1;
                    
                    if (~simplify_map)
                        rectangle('Position', [xval_legend top_yval 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Vibrissa, :));
                        rectangle('Position', [xval_legend top_yval-1 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Face, :));
                        rectangle('Position', [xval_legend top_yval-2 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Neck, :));
                        rectangle('Position', [xval_legend top_yval-3 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.DistalForelimb, :));
                        rectangle('Position', [xval_legend top_yval-4 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.ProximalForelimb, :));
                        rectangle('Position', [xval_legend top_yval-5 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Shoulder, :));
                        rectangle('Position', [xval_legend top_yval-6 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Hindlimb, :));

                        text(xval_legend+1, top_yval+0.5, MotorMap.MapStrings(MotorMap.Vibrissa), 'FontSize', 18);
                        text(xval_legend+1, top_yval-0.5, MotorMap.MapStrings(MotorMap.Face), 'FontSize', 18);
                        text(xval_legend+1, top_yval-1.5, MotorMap.MapStrings(MotorMap.Neck), 'FontSize', 18);
                        text(xval_legend+1, top_yval-2.5, MotorMap.MapStrings(MotorMap.DistalForelimb), 'FontSize', 18);
                        text(xval_legend+1, top_yval-3.5, MotorMap.MapStrings(MotorMap.ProximalForelimb), 'FontSize', 18);
                        text(xval_legend+1, top_yval-4.5, MotorMap.MapStrings(MotorMap.Shoulder), 'FontSize', 18);
                        text(xval_legend+1, top_yval-5.5, MotorMap.MapStrings(MotorMap.Hindlimb), 'FontSize', 18);
                    else
                        
                        if (legend_location == 1)
                            top_yval = 5;
                        end
                        
                        if (~legend_forelimb_only)
                            rectangle('Position', [xval_legend top_yval 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Vibrissa, :));
                            rectangle('Position', [xval_legend top_yval-1 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.DistalForelimb, :));
                            rectangle('Position', [xval_legend top_yval-2 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.Hindlimb, :));
                            text(xval_legend+1, top_yval+0.5, MotorMap.MapStrings(MotorMap.TotalHead), 'FontSize', 8);
                            text(xval_legend+1, top_yval-0.5, MotorMap.MapStrings(MotorMap.TotalForelimb), 'FontSize', 8);
                            text(xval_legend+1, top_yval-1.5, MotorMap.MapStrings(MotorMap.Hindlimb), 'FontSize', 8);
                        else
                            rectangle('Position', [xval_legend top_yval 0.8 0.8], 'FaceColor', MotorMap.PlotColorsNormal(MotorMap.DistalForelimb, :));
                            text(xval_legend+1, top_yval+0.5, MotorMap.MapStrings(MotorMap.TotalForelimb), 'FontSize', 8);
                        end
                    end
                end
                
                if (obj.IsProbabilityMap)
                    %colors = flipud(jet(100));
                    colors = jet(100);
                    %colors = flipud(hot(100));
                    colormap(colors);
                end
                
                for x = 1:x_size
                    for y = 1:y_size
                        
                        if (obj.IsProbabilityMap)
                            
                            if (plot_interpolated_heat_map)
                                
                                probability_map = obj.MapData;
                                interpolated_data = interp2(probability_map, 5);
                                interpolated_data = interpolated_data';
                                interpolated_data = interpolated_data * 100;
                                
                                %min_x = min(MotorMap.MapAPCoordinates);
                                %max_x = max(MotorMap.MapAPCoordinates);
                                %min_y = min(MotorMap.MapMLCoordinates);
                                %max_y = max(MotorMap.MapMLCoordinates);
                                
                                min_x = 1;
                                max_x = length(MotorMap.MapAPCoordinates) + 1;
                                min_y = 1;
                                max_y = length(MotorMap.MapMLCoordinates) + 1;
                                
                                %rectangle('Position', [0 0 max_y+0.1 max_x+0.1], 'FaceColor', colors(1, :));
                                image('YData', [min_x max_x], 'XData', [min_y max_y], 'CData', interpolated_data);
                                
                                
                                
                            else
                                
                                probability = obj.MapData(x, y);
                                override_edge_color = 0;
                                if (~isempty(significance_map))
                                    if (significance_map(x, y) > 0)
                                        if (probability == 0)
                                            rectangle('Position', [x y 1 1], 'FaceColor', [1 1 1], 'EdgeColor', [1 0 0]);
                                        else
                                            override_edge_color = 1;
                                        end
                                    end
                                end

                                if (probability > 0)
                                    fill_color = colors(round(probability * 100), :);
                                    edge_color = [0 0 0];
                                    if (~plot_edge_lines)
                                        edge_color = fill_color;
                                    end

                                    if (override_edge_color)
                                        edge_color = [1 0 0];
                                        fill_color = [1 0 0];
                                    end

                                    rectangle('Position', [x y 1 1], 'FaceColor', fill_color, 'EdgeColor', edge_color);
                                end
                                
                            end
                            

                            
                        else
                            data_point = obj.MapData(x, y);

                            if (~isnan(data_point))
                                if ((data_point == MotorMap.NoResponse && plot_no_responses) || data_point ~= MotorMap.NoResponse)
                                    
                                    if (simplify_map)
                                        if (data_point == MotorMap.Vibrissa || ...
                                            data_point == MotorMap.Face || ...
                                            data_point == MotorMap.Neck)
                                            fill_color = f.colors(MotorMap.Vibrissa, :);
                                        elseif (data_point == MotorMap.DistalForelimb || ...
                                            data_point == MotorMap.ProximalForelimb || ...
                                            data_point == MotorMap.Shoulder)
                                            fill_color = f.colors(MotorMap.DistalForelimb, :);
                                        else
                                            fill_color = f.colors(data_point, :);
                                        end
                                    else
                                        fill_color = f.colors(data_point, :);    
                                    end
                                    
                                    edge_color = [0 0 0];
                                    if (~plot_edge_lines)
                                        edge_color = fill_color;
                                    end
                                    
                                    
                                    if (data_point == MotorMap.NoResponse && no_responses_with_x)
                                        line([x+0.4 x+0.6], [y+0.4 y+0.6], 'Color', 'k', 'LineWidth', 1);
                                        line([x+0.4 x+0.6], [y+0.6 y+0.4], 'Color', 'k', 'LineWidth', 1);
                                    else
                                        rectangle('Position', [x y 1 1], 'FaceColor', fill_color, 'EdgeColor', edge_color);
                                    end
                                end
                            end
                        end
                    end
                end
                
                set(gca, 'xlim', [0 14]);
                set(gca, 'xtick', [1.5 11.5]);
                set(gca, 'xticklabel', {'0' '5'});
                
                set(gca, 'ylim', [0 20]);
                set(gca, 'ytick', [1.5 9.5 19.5]);
                set(gca, 'yticklabel', {'-4' '0' '5'});
                
                %Bregma circle
                rectangle('Position', [1.25 9.25 0.5 0.5], 'Curvature', [1 1], 'EdgeColor', bregma_circle_color, 'FaceColor', bregma_circle_color);
                
                %lateral_edge = 12.5;
                %x_arrow_start = lateral_edge - 0.25;
                
                %Horizontal line from bregma
                %line([1.5 lateral_edge], [9.5 9.5], 'LineStyle', '--', 'Color', bregma_circle_color, 'LineWidth', 1);
                %line([x_arrow_start lateral_edge], [9.75 9.5], 'Color', bregma_circle_color, 'LineWidth', 1);
                %line([x_arrow_start lateral_edge], [9.25 9.5], 'Color', bregma_circle_color, 'LineWidth', 1);
                
                %Vertical line from bregma
                %line([1.5 1.5], [9.5 19.5], 'LineStyle', '--', 'Color', bregma_circle_color, 'LineWidth', 1);
                %line([1.25 1.5], [19.25 19.5], 'Color', bregma_circle_color, 'LineWidth', 1);
                %line([1.75 1.5], [19.25 19.5], 'Color', bregma_circle_color, 'LineWidth', 1);
                
                if (obj.IsProbabilityMap && plot_legend)
                    colorbar();
                end
                
            end
            
            
        end
        
        function PlotPenetrationSites ( obj, varargin )
            
            %Handle optional input parameters
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultAxes = 0;
            defaultBregmaIndicatorColor = [0.5 0.5 0.5];
            addOptional(p, 'Axes', defaultAxes);
            addOptional(p, 'BregmaIndicatorColor', defaultBregmaIndicatorColor);
            parse(p, varargin{:});
            map_plot_axes = p.Results.Axes;
            bregma_circle_color = p.Results.BregmaIndicatorColor;
            
            %Grab the figure that the user passed in, or create a new figure.
            axes_width = 5.8;
            axes_height = 7.66;
            
            figure_class = class(map_plot_axes);
            if (strcmpi(figure_class, 'matlab.graphics.axis.Axes'))
                %map_position = get(map_plot_axes, 'position');
                %set(map_plot_axes, ...
                %    'units', 'centimeters', ...
                %    'position', [map_position(1) map_position(2) axes_width axes_height]);
            else
                %Plot the map
                f.fig = figure('units', 'centimeters', ...
                    'position', [1 3 16 22], ...
                    'color', 'w');
                f.axes = axes('parent', f.fig, ...
                    'units', 'centimeters', ...
                    'position', [2 2 13 19]);
                set(gca, 'clipping', 'off');

                f.colors = obj.PlotColorsNormal;
                hold on;
            end
            
            f.colors = obj.PlotColorsNormal;

            x_size = size(obj.MapData, 1);
            y_size = size(obj.MapData, 2);

            for x = 1:x_size
                for y = 1:y_size

                    rectangle('Position', [(x+0.35) (y+0.35) 0.3 0.3], 'Curvature', [1 1], 'EdgeColor', 'k', 'FaceColor', 'k');

                end
            end

            set(gca, 'xlim', [0 14]);
            set(gca, 'xtick', [1.5 11.5]);
            set(gca, 'xticklabel', {'0' '5'});

            set(gca, 'ylim', [0 20]);
            set(gca, 'ytick', [1.5 9.5 19.5]);
            set(gca, 'yticklabel', {'-4' '0' '5'});

            %Bregma circle
            %rectangle('Position', [1.25 9.25 0.5 0.5], 'Curvature', [1 1], 'EdgeColor', bregma_circle_color, 'FaceColor', bregma_circle_color);
                
            
            
        end
        
    end
    
    methods (Static, Access = private)
        
        function merged_array = MergePlacerCallerData ( ld, sd )
            
            length_of_shorter_array = min(length(ld), length(sd));
            merged_array = cell(1, length_of_shorter_array);
            for i = 1:length_of_shorter_array
                
                if (iscellstr(ld(i)))
                    merged_array{1, i} = ld{i};
                elseif (iscellstr(sd(i)))
                    merged_array{1, i} = sd{i};
                else
                    merged_array{1, i} = '';
                end
                
            end
            
        end
        
        function [placer, caller, thresh, supra, responses] = ParseMappingData ( raw_data_sheet )
            
            %Initialize the LD matrix as an empty cell array
            responses = {};
            
            %Initialize some variables we will need
            current_placer = {NaN};
            current_caller = {NaN};
            placer = {};
            caller = {};
            thresh = [];
            supra = [];
            
            %Parse the data
            num_sites = size(raw_data_sheet, 1); 
            num_possible_responses = size(raw_data_sheet, 2);
            for s = 2:num_sites  %We start at index 2 because there is a header row at the first row index
                responses_this_site = [];
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
                        thresh(end+1) = raw_data_sheet{s, n};
                    elseif (n == 4)
                        %Check to see what the listed suprathreshold value is
                        supra(end+1) = raw_data_sheet{s, n};
                    else
                        %Otherwise, add the response stored in this cell to the list of responses for this site
                        if (iscellstr(raw_data_sheet(s, n)))
                            this_response = MotorMapMovements.ConvertFromShorthandToMovement(raw_data_sheet(s, n));
                            
                            if (this_response == MotorMapMovements.Undefined)
                                disp(['Undefined movement found: ' raw_data_sheet{s, n}]);
                            end
                            
                            responses_this_site = [responses_this_site this_response];
                        end
                    end
                    
                end
                
                responses{end+1} = responses_this_site; 
                
            end
            
        end
                
        function [placing, placer, caller, ldthresh, ldsupra, sdthresh, sdsupra, ld, sd, updates, rat_info] = ReadMap ( fully_qualified_path )
            
            [~, ~, placing_raw] = xlsread(fully_qualified_path, 'Placing');
            [~, ~, ld_raw] = xlsread(fully_qualified_path, 'LD');
            [~, ~, sd_raw] = xlsread(fully_qualified_path, 'SD');
            [~, ~, updates_raw] = xlsread(fully_qualified_path, 'Updates');
            [~, ~, rat_info_raw] = xlsread(fully_qualified_path, 'Rat Information');
            
            %Assign the placing matrix
            placing = cell2mat(placing_raw(2:end, 2:end));
            
            %Parse the long duration data
            [ldplacer, ldcaller, ldthresh, ldsupra, ld] = MotorMap.ParseMappingData ( ld_raw );
            
            %Parse the short duration data
            [sdplacer, sdcaller, sdthresh, sdsupra, sd] = MotorMap.ParseMappingData ( sd_raw );
            
            %Merge the placer and caller data
            placer = MotorMap.MergePlacerCallerData(ldplacer, sdplacer);
            caller = MotorMap.MergePlacerCallerData(ldcaller, sdcaller);
            
            %Parse the drug-update information
            updates = updates_raw(2:end, :);
            
            %Parse out the rat information
            rat_info = rat_info_raw;
            
        end
        
    end
    
    methods (Static)
        
        function obj = CreateMap ( fully_qualified_path )
            
            [placing, placer, caller, ldthresh, ldsupra, sdthresh, sdsupra, ld, sd, updates, rat_info] = MotorMap.ReadMap ( fully_qualified_path );
            obj = MotorMap('Placing', placing, ...
                'LongDuration', ld, ...
                'ShortDuration', sd, ...
                'Placer', placer, ...
                'Caller', caller, ...
                'LongDurationThresholds', ldthresh, ...
                'ShortDurationThresholds', sdthresh, ...
                'LongDurationSuprathresholds', ldsupra, ...
                'ShortDurationSuprathresholds', sdsupra, ...
                'Updates', updates, 'RatInformation', rat_info);
            
        end

        function VerifyMap ( map )
            
            good = 1;
            
            %Display message to the user that this map is being verified
            disp([map.RatName ': Verifying map...']);
            
            %First, collapse the placing data into a one-dimensional array
            total_elements = size(map.PlacingData, 1) * size(map.PlacingData, 2);
            reshaped_data = reshape(map.PlacingData, 1, total_elements);
            
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
            num_sites_called_ld = length(map.MapDataLongDuration);
            num_sites_called_sd = length(map.MapDataShortDuration);
            
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





























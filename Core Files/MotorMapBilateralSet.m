classdef MotorMapBilateralSet
    
    properties
        
        Maps
        Group
        GroupName
        
    end
    
    methods
        
        function obj = MotorMapBilateralSet(file_list)
            for i=1:length(file_list)
                if (~isempty(file_list{i}))
                    maps(i) = MotorMapBilateral.CreateMap(file_list{i});
                    MotorMapBilateral.VerifyMap(maps(i));
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
    
end


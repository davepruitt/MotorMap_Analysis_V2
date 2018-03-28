function x_vals = generate_xvals_v2 ( y_vals, x_offset, x_range )

    %Force y_vals to be a row vector
    y_vals = y_vals(:)';

    x_vals = zeros(1, length(y_vals));

    unique_vals = unique(y_vals);
    
    min_y = min(y_vals);
    max_y = max(y_vals);
    y_range = max_y - min_y;
    
    for i = unique_vals
        
        diff_for_this_value = unique_vals - i;
        
        indices_of_this_value = find(y_vals == i);
        value_count = length(indices_of_this_value);
        x_start = x_offset - x_range;
        x_end = x_offset + x_range;
        x_delta = (2 * x_range) / (value_count - 1);
        
        if (value_count == 1)
            x_vals(indices_of_this_value) = x_offset;
        else
            new_x_vals = x_start:x_delta:x_end;
            x_vals(indices_of_this_value) = new_x_vals;
        end
        
    end

end
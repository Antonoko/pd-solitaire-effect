import 'CoreLibs/graphics'
import "CoreLibs/sprites"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local screenWidth <const> = playdate.display.getWidth()
local screenHeight <const> = playdate.display.getHeight()

---------------------------------

local card_imagetable = gfx.imagetable.new("card_placeholder_fun")
local card_width, card_height = card_imagetable[1]:getSize()

local win_animation_cards_info = {}
local win_animation_render_canvas = gfx.image.new(screenWidth, screenHeight, gfx.kColorClear)
local win_animation_render_sprite = gfx.sprite.new(win_animation_render_canvas)

---------------------------------

function init_win_animation_cards_info(x_array, y_baseline, card_imagetable)
    -- Pre-generate animation properties for all cards
    -- eg. win_animation_cards_info = init_win_animation_cards_info({15, 80, 145, 275}, 30, card_imagetable)
    -- return: calculated card_imagetable

    -- x_array: table, Initial deck position, X coordinates of the upper left corner of the card deck, eg. {15, 80, 145, 275}
    -- y_baseline: int, Y coordinates of the upper left corner of all the card deck, eg. 30
    -- card_imagetable: playdate.graphics.imagetable, imagetable of all cards

    -- Logarithmic Mapping
    function _mapValue(old_value, old_min, old_max, new_min, new_max)
        -- return ((old_value - old_min) * (new_max - new_min) / (old_max - old_min) + new_min)   -- Linear Map
        if old_min >= old_max or old_value < old_min or old_value > old_max then
            error("Invalid input values")
        end
        local log_old_min = math.log(old_min)
        local log_old_max = math.log(old_max)
        local log_old_value = math.log(old_value)    
        local new_value = ((log_old_value - log_old_min) * (new_max - new_min) / (log_old_max - log_old_min) + new_min)
        return new_value
    end

    local card_stack_pos = {
        x = x_array,
        y = y_baseline
    }
    local win_animation_cards_info = {}
    local next_card_trigger_time_accumulation = 1   -- cumulative animation timeline

    for i = 1, #card_imagetable, 1 do
        next_card_trigger_time_accumulation += math.random(10, 50)            -- trigger time of the next stop card animation
        local bounce_interval = math.random(10, 100)                          -- distance between each bounce
        local start_x = card_stack_pos.x[math.random(1, #card_stack_pos.x)]   -- deck coordinates from which the card was fired
        local direction_left = math.random() < 0.6                            -- fired direction
        if start_x < screenWidth*(1/4) then      -- cards on the left side of the screen are always fired to the right
            direction_left = false
        end

        win_animation_cards_info[i] = {
            state = "pending",      -- pending, playing, end
            time = 0,               -- relative time counter of each card
            start_x = start_x,
            start_y = card_stack_pos.y,
            img = card_imagetable[i],
            bounce_interval = bounce_interval,
            decay_factor = math.random(4, 9)*0.1,                     -- decay of each bounce, range: 0~1
            speed = _mapValue(bounce_interval, 10, 100, .3,2.5),      -- normalize the speed, so that cards with short intervals fall at a slower speed, consistent with cards with long intervals
            next_card_trigger_time = next_card_trigger_time_accumulation,   -- when the time is up, trigger the next card animation
            direction_left = direction_left
        }
    end

    return win_animation_cards_info
end



function init_win_animation()
    -- Initialize the content needed for the victory animation

    win_animation_render_canvas = gfx.image.new(screenWidth, screenHeight, gfx.kColorClear)    -- Create a blank canvas buffer
    -- win_animation_render_canvas = gfx.image.new("bg-refer")     -- for test refer
    win_animation_render_sprite = gfx.sprite.new(win_animation_render_canvas)                  -- Create a sprite to display the canvas 
    win_animation_render_sprite:moveTo(screenWidth/2, screenHeight/2)
    win_animation_render_sprite:add()
    win_animation_render_sprite:setZIndex(100)   -- Should be lower than the victory modal tip box, located below it
    win_animation_cards_info = init_win_animation_cards_info({15, 80, 145, 275}, 30, card_imagetable)   -- Prepare all card animation properties
end



function get_bounce_position(t, x0, y0, bounceInterval, decayFactor, speed, direction_left)
    -- Get the corresponding coordinates of the card on the screen

    function _createParabola(x1, y1, xv, yv)
        -- Calculate the parabola function by the coordinates of the starting point and the highest point
        local a = (y1 - yv) / ((x1 - xv) * (x1 - xv))
        local b = -2 * a * xv
        local c = yv + a * xv * xv
        return function(x)
            return a * x * x + b * x + c
        end
    end

    function _mapToScreen_Y(y)
        -- Mapping normal coordinates to screen coordinates
        local screenY = screenHeight - y
        return screenY
    end

    local x = x0 + t*speed + bounceInterval/2       -- for calc y result only
    local x_origin = x0 + t*speed                   -- final displayed x coordinate
    local seg = math.floor((x-x0)/bounceInterval)   -- bounce segment
    -- print("x0 "..x0.." x "..x.." seg "..seg)

    local highest_y = (screenHeight - y0)*decayFactor^(seg)          -- bounce Decay
    if highest_y < card_height +3 then                               -- bottom-touching strategy
        highest_y = card_height + 60*decayFactor^(math.abs(seg-6))      -- let it bounce higher one more time
    end
    
    local parabola = _createParabola(
        x0 + seg*bounceInterval, 
        card_height, 
        x0 + (seg*bounceInterval + bounceInterval/2), 
        highest_y
    )
    local y = _mapToScreen_Y(parabola(x))           -- calculate the parabola and the result
    if direction_left then                          -- mirror the direction
        x_origin = 2*x0 - x_origin
    end
    
    return x_origin, y
end


function update_win_animation(time, win_animation_cards_info)
    -- Update the win animation. Should be updated in each frame before the animation is finished.
    -- return: is animation end

    -- time: int, as each frame increases
    -- win_animation_cards_info: table, all generated card animation properties

    local state_end_counter = 0

    for k, v in pairs(win_animation_cards_info) do
        if time < v.next_card_trigger_time then
            break
        end
        if v.state == "pending" then
            win_animation_cards_info[k].state = "playing"
        end
        if v.state == "playing" then
            gfx.pushContext(win_animation_render_canvas)
                local x, y = get_bounce_position(v.time, v.start_x, v.start_y, v.bounce_interval, v.decay_factor, v.speed, v.direction_left)
                if x > screenWidth or x < -card_width then         -- Out of Bounds
                    win_animation_cards_info[k].state = "end"
                end

                v.img:draw(x, y)
            gfx.popContext()
            win_animation_render_sprite:setImage(win_animation_render_canvas)
            win_animation_cards_info[k].time += 1
        end
        if v.state == "end" then
            state_end_counter += 1
            if state_end_counter == #win_animation_cards_info then      --if all card animation properties are ended
                return true
            end
        end
    end

    return false
end


----------------------------------

local time = 0         -- Animation time counter, here I use frames to add up the data. We can also use timer, animator and other data driven.
init_win_animation()


function pd.update()
    gfx.sprite.update()

    local is_animation_end = update_win_animation(time, win_animation_cards_info)
    if not is_animation_end then
        time += 1
    end

    print("time ", time, " is_animation_end: ", is_animation_end)
end
import 'CoreLibs/graphics'
import "CoreLibs/sprites"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local screenWidth <const> = playdate.display.getWidth()
local screenHeight <const> = playdate.display.getHeight()

---------------------------------

local card_imagetable = gfx.imagetable.new("card_placeholder_fun")
local card_width, card_height = card_imagetable[1]:getSize()
local win_animation_card_info = {}
local win_animation_render_canvas = gfx.image.new(screenWidth, screenHeight, gfx.kColorClear)
local win_animation_render_sprite = gfx.sprite.new(win_animation_render_canvas)


function init_win_animation_card_info(x_array, y_baseline)
    -- function mapValue(old_value, old_min, old_max, new_min, new_max)
    --     return ((old_value - old_min) * (new_max - new_min) / (old_max - old_min) + new_min)
    -- end

    function mapValue(old_value, old_min, old_max, new_min, new_max)
        -- 确保 old_min 和 old_max 不相等，且 old_value 在这个范围内
        if old_min >= old_max or old_value < old_min or old_value > old_max then
            error("Invalid input values")
        end
        
        -- 对数映射
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
    win_animation_card_info = {}
    next_card_trigger_time_accumulation = 1

    for i = 1, #card_imagetable, 1 do
        next_card_trigger_time_accumulation += math.random(10, 50)
        local bounce_interval = math.random(10, 100)
        local start_x = card_stack_pos.x[math.random(1, #card_stack_pos.x)]
        local direction_left = math.random() < 0.6
        if start_x < screenWidth*(1/4) then
            direction_left = false
        end

        win_animation_card_info[i] = {
            state = "pending",   -- pending, playing, end
            time = 0,
            start_x = start_x,
            start_y = card_stack_pos.y,
            img = card_imagetable[i],
            bounce_interval = bounce_interval,
            decay_factor = math.random(4, 9)*0.1,
            speed = mapValue(bounce_interval, 10, 100, .3,2.5),   -- Normalize the speed, so that cards with short intervals fall at a slower speed, consistent with cards with long intervals
            next_card_trigger_time = next_card_trigger_time_accumulation,
            direction_left = direction_left
        }
    end
end

function init_win_animation()
    win_animation_render_canvas = gfx.image.new(screenWidth, screenHeight, gfx.kColorClear)
    -- win_animation_render_canvas = gfx.image.new("bg-refer")
    win_animation_render_sprite = gfx.sprite.new(win_animation_render_canvas)
    win_animation_render_sprite:moveTo(screenWidth/2, screenHeight/2)
    win_animation_render_sprite:add()
    win_animation_render_sprite:setZIndex(100)   --比提示框低
    
    init_win_animation_card_info({15, 80, 145, 275}, 30)
end


function get_bounce_position(t, x0, y0, groundY, bounceInterval, decayFactor, speed, direction_left)

    function createParabola(x1, y1, xv, yv)
        -- x1, y1: 起始坐标
        -- xv, yv: 拐点(极值点)坐标
        
        -- 计算二次函数的系数
        local a = (y1 - yv) / ((x1 - xv) * (x1 - xv))
        local b = -2 * a * xv
        local c = yv + a * xv * xv
        
        return function(x)
            return a * x * x + b * x + c
        end
    end

    function mapToScreen(y)
        local screenY = screenHeight - y
        return screenY
    end

    local x = x0 + t*speed + bounceInterval/2   -- for calc y only
    local x_origin = x0 + t*speed
    local seg = math.floor((x-x0)/bounceInterval)
    -- print("x0 "..x0.." x "..x.." seg "..seg)

    local highest_y = (screenHeight - y0)*decayFactor^(seg)
    if highest_y < card_height +3 then
        highest_y = card_height + 60*decayFactor^(math.abs(seg-6))
    end
    
    local parabola = createParabola(
        x0 + seg*bounceInterval, 
        card_height, 
        x0 + (seg*bounceInterval + bounceInterval/2), 
        highest_y
    )
    local y = mapToScreen(parabola(x))
    if direction_left then   -- mirror the direction
        x_origin = 2*x0 - x_origin
    end
    
    return x_origin, y

end



function update_win_animation(time)
    local groundY = screenHeight

    for k, v in pairs(win_animation_card_info) do
        if time < v.next_card_trigger_time then
            break
        end
        if v.state == "pending" then
            win_animation_card_info[k].state = "playing"
        end
        if v.state == "playing" then
            gfx.pushContext(win_animation_render_canvas)
                local x, y = get_bounce_position(v.time, v.start_x, v.start_y, groundY-card_height, v.bounce_interval, v.decay_factor, v.speed, v.direction_left)
                if x > screenWidth or x < -card_width then
                    win_animation_card_info[k].state = "end"
                end

                v.img:draw(x, y)
            gfx.popContext()
            win_animation_render_sprite:setImage(win_animation_render_canvas)
            win_animation_card_info[k].time += 1
        end
        
    end


end


----------------------------------

local time = 0
init_win_animation()


function pd.update()
    gfx.sprite.update()

    time += 1

    update_win_animation(time)

end
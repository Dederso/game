function love.load()
    wf = require "libraries/windfield"
    sti = require "libraries/sti"
    cameralib = require "libraries/camera"
    camera = cameralib()
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 1000)

    love.window.setMode(800, 600, {
        resizable=true,
        vsync=true,
        minwidth=400,
        minheight=300
    })
    -- Carrega o mapa
    map = sti("mapa/mapa.lua")
    
    -- Verifica se o mapa foi carregado corretamente
    if not map then
        print("Erro ao carregar o mapa!")
        love.event.quit()
        return
    end

    -- Definir classes de colisão
    world:addCollisionClass('Player')
    world:addCollisionClass('Ground')
    sprite_right = love.graphics.newImage("assets/Sprite_astronauta_right.png")
    sprite_left = love.graphics.newImage("assets/Sprite_astronauta_left.png")
    player = {
        width = 16,
        height = 32,
        width_sprite = 32,
        height_sprite = 32,
        sprite = sprite_right,
        speed = 200,
        jumpForce = 600,
        isOnGround = false,
        direction = 1,  -- 1 para direita, -1 para esquerda
        coyoteTime = 0.1, -- tempo de tolerância em segundos
        coyoteTimer = 0 -- timer do coyote time
    }
   
    local x = map.width * map.tilewidth / 2
    local y = map.height * map.tileheight * 0.97
    player.hitbox = world:newRectangleCollider(x, y, player.width, player.height)
    player.hitbox:setCollisionClass('Player')
    player.hitbox:setFixedRotation(true)
    player.hitbox:setFriction(0)
    
    -- Cria colisões do mapa
    if map.layers["colision"] then
        for _, object in ipairs(map.layers["colision"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setType("static")
            collider:setCollisionClass('Ground')
        end
    end
    
end

function love.update(dt)
    world:update(dt)
    if player.direction == 1 then
        player.sprite = sprite_right
    elseif player.direction == -1 then
        player.sprite = sprite_left
    end
    local vx, vy = player.hitbox:getLinearVelocity()
    local px, py = player.hitbox:getPosition()

    -- Movimento horizontal
    if love.keyboard.isDown("left") then
        vx = -player.speed
        player.direction = -1
    elseif love.keyboard.isDown("right") then
        vx = player.speed
        player.direction = 1
    else
        vx = 0
    end
      -- Verifica colisão com o chão
    local groundColliders = world:queryRectangleArea(px - player.width/2, py + player.height/2, player.width, 2, {'Ground'})
    if #groundColliders > 0 then
        player.isOnGround = true
        lastGroundTime = love.timer.getTime()
    else
        player.isOnGround = false
        local time = love.timer.getTime()
        local lastTime
        if(lastGroundTime ~= nil) then
            lastTime = lastGroundTime
        else
            lastTime = player.coyoteTime+1
        end
        player.coyoteTimer = time - lastTime
    end
    
    

    -- Pulo com coyote time
    if love.keyboard.isDown("up")then 
       if player.isOnGround then
            vy = -player.jumpForce
            player.coyoteTimer = 0
       else
            if player.coyoteTimer <= player.coyoteTime then
                vy = -player.jumpForce
                player.lastGroundTime = love.timer.getTime()
            end
       end
    end

    camera:lookAt(px, py)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local wt = map.width * map.tilewidth
    local ht = map.height * map.tileheight


    if camera.x < w/2 then
        camera.x = w/2
    end

    if camera.y < h/2 then
        camera.y = h/2
    end

    if camera.x > (wt - w/2) then
        camera.x = (wt - w/2)
    end
    
    if camera.y > (ht - h/2) then
        camera.y = (ht - h/2)
    end
     -- Aplica a velocidade horizontal sempre, mas mantém a velocidade vertical
     player.hitbox:setLinearVelocity(vx, vy)

end

function love.draw()
    camera:attach()
        -- Desenha o mapa
        if map then
            for i, layer in ipairs(map.layers) do
                if layer.name ~= "colision" then
                    layer:draw()
                end
            end
        else
            love.graphics.print("Mapa não carregado!", 400, 300)
        end
        -- Desenha os objetos do mundo físico (opcional)
    world:draw()


    -- Desenha o sprite do jogador centralizado
    local spriteWidth = player.sprite:getWidth()
    local spriteHeight = player.sprite:getHeight()
    local scaleX = player.width_sprite / spriteWidth
    local scaleY = player.height_sprite / spriteHeight
    love.graphics.draw(
        player.sprite,
        player.hitbox:getX(),
        player.hitbox:getY(),
        0,
        scaleX,
        scaleY,
        spriteWidth / 2,
        spriteHeight / 2
    )
    camera:detach()
    -- Adiciona texto de depuração
    love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    love.graphics.print("jump: " .. tostring(player.isOnGround), 10, 30)
    love.graphics.print("x: " .. tostring(player.hitbox:getX()), 10, 50)
    love.graphics.print("y: " .. tostring(player.hitbox:getY()), 10, 70)
    --printa o tempo desde que o jogador deixou o chão a contagem do tempo e o tempo armazenado no lastGroundTime
    love.graphics.print("lastGroundTime: " .. tostring(player.coyoteTimer), 10, 110)
    
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
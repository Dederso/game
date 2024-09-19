function love.load()
    wf = require "libraries/windfield"
    sti = require "libraries/sti"
    cameralib = require "libraries/camera"
    camera = cameralib()
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 800)

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

    player = {
        width = 50,
        height = 50,
        sprite = love.graphics.newImage("assets/Sprite_astronauta.png"),
        speed = 200,
        jumpForce = 500,
        isOnGround = false,
        direction = 1  -- 1 para direita, -1 para esquerda
    }
    player.hitbox = world:newRectangleCollider(32, 3000, player.width, player.height)
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
    
    -- Pulo
    if love.keyboard.isDown("up") and player.isOnGround then
        vy = -player.jumpForce
        player.isOnGround = false
    end 
    
    -- Aplica a velocidade horizontal sempre, mas mantém a velocidade vertical
    player.hitbox:setLinearVelocity(vx, vy)

    -- Verifica colisão com o chão
    player.isOnGround = false
    local groundColliders = world:queryRectangleArea(px - player.width/2, py + player.height/2, player.width, 2, {'Ground'})
    if #groundColliders > 0 then
        player.isOnGround = true    
    end

    camera:lookAt(px, py)
end

function love.draw()
    camera:attach()
        -- Desenha o mapa
        if map then
            for i, layer in ipairs(map.layers) do
                layer:draw()
            end
        else
            love.graphics.print("Mapa não carregado!", 400, 300)
        end
        -- Desenha os objetos do mundo físico (opcional)
    world:draw()
    -- Desenha o sprite do jogador centralizado
    local spriteWidth = player.sprite:getWidth()
    local spriteHeight = player.sprite:getHeight()
    local scaleX = player.width / spriteWidth
    local scaleY = player.height / spriteHeight
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
    
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
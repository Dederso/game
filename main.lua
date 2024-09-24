function love.load()
-- Importa as bibliotecas ====================================================================================================
    wf = require "libraries/windfield"
    sti = require "libraries/sti"
    cameralib = require "libraries/camera"
    camera = cameralib()
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 1000)

    -- Lista de resoluções suportadas
    resolutions = {
        {width = 1920, height = 1080}, -- Resolução mais alta
        {width = 1600, height = 900}, -- Resolução média
        {width = 1366, height = 768}, -- Resolução mais baixa
        {width = 1280, height = 720}, -- Resolução mais baixa
        {width = 1024, height = 576} -- Resolução mais baixa
    }

-- Configura a janela do jogo ================================================================================================
    resolution = resolutions[5]
    love.window.setMode(resolution.width, resolution.height, {
        resizable=true,
        vsync=true,
        minwidth=400,
        minheight=300
    })

-- Carrega o mapa ===========================================================================================================
    map = sti("mapa/mapa.lua")    
-- Verifica se o mapa foi carregado corretamente
    if not map then
        print("Erro ao carregar o mapa!")
        love.event.quit()
        return
    end

-- Definir classes de colisão ===============================================================================================
    world:addCollisionClass('Player')
    world:addCollisionClass('Ground')

-- Carrega os sprites do jogador ============================================================================================
    sprite_right = love.graphics.newImage("assets/Sprite_astronauta_right.png")
    sprite_left = love.graphics.newImage("assets/Sprite_astronauta_left.png")
    sprite_jump_right = love.graphics.newImage("assets/Sprite_astronauta_jumping_right.png")
    sprite_jump_left = love.graphics.newImage("assets/Sprite_astronauta_jumping_left.png")

-- Cria o jogador ===========================================================================================================
    player = {
        width = 32,
        height = 63, --um pixel menos para que ele nao fique colidindo com 2 tiles para cima
        width_sprite = 64,
        height_sprite = 64,
        sprite = sprite_right,
        speed = 200,
        jumpForce = 700,
        isOnGround = false,
        direction = 1,  -- 1 para direita, -1 para esquerda
        
    }

-- Cria a hitbox do jogador =================================================================================================
    local x = map.width * map.tilewidth / 2
    local y = map.height * map.tileheight * 0.96
    player.hitbox = world:newRectangleCollider(x, y, player.width, player.height)
    player.hitbox:setCollisionClass('Player')
    player.hitbox:setFixedRotation(true)
    player.hitbox:setFriction(0)
    
-- Cria colisões do mapa ================================================================================================
    if map.layers["colision"] then
        for _, object in ipairs(map.layers["colision"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setType("static")
            collider:setCollisionClass('Ground')
        end
    end
    
    -- Adicione isso ao final da função love.load()
    jumpChargeBarWidth = 100
    jumpChargeBarHeight = 10
end

-- Função para verificar colisões laterais
function checkLateralCollisions(player)
    local px, py = player.hitbox:getPosition()
    local leftColliders = world:queryRectangleArea(
        px - player.width/2 - 2, -- 2 pixels à esquerda do jogador
        py - player.height/2 + 2, -- 2 pixels abaixo do topo do jogador
        2, -- largura da área de verificação
        player.height - 4, -- altura da área de verificação (4 pixels menor que o jogador)
        {'Ground'}
    )

    local rightColliders = world:queryRectangleArea(
        px + player.width/2, -- borda direita do jogador
        py - player.height/2 + 2, -- 2 pixels abaixo do topo do jogador
        2, -- largura da área de verificação
        player.height - 4, -- altura da área de verificação (4 pixels menor que o jogador)
        {'Ground'}
    )

    local isCollidingLeft = #leftColliders > 0
    local isCollidingRight = #rightColliders > 0

    return isCollidingLeft, isCollidingRight
end

-- Atualiza o jogo ==========================================================================================================
function love.update(dt)
    -- Atualiza o mundo físico =================================================================================================
    world:update(dt)
    if player.direction == 1 then
        player.sprite = sprite_right
    elseif player.direction == -1 then
        player.sprite = sprite_left
    end
    -- Movimento do jogador ===============================================================================================
    local vx, vy = player.hitbox:getLinearVelocity()
    local px, py = player.hitbox:getPosition()

    -- Movimento horizontal do jogador (esquerda e direita) =================================================================
    if (love.keyboard.isDown("left") or love.keyboard.isDown("a")) and player.isOnGround then
        vx = -player.speed
        player.direction = -1
    elseif (love.keyboard.isDown("right") or love.keyboard.isDown("d")) and player.isOnGround then
        vx = player.speed
        player.direction = 1
    end
    -- Pulo do jogador com base na barra de carga
    if love.keyboard.isDown("space") or love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        if player.isOnGround then
            player.jumpCharge = (player.jumpCharge or 0) + dt
            if player.jumpCharge > 1 then
                player.jumpCharge = 1
            end
        end
    else
        if player.isOnGround and player.jumpCharge and player.jumpCharge > 0 then
            if player.jumpCharge > 0.25 then
                vy = -player.jumpForce * player.jumpCharge
                vx = player.speed * player.direction * player.jumpCharge
            end
        end
        player.jumpCharge = 0
    end

    if not player.isOnGround then
        if player.direction == 1 then
            player.sprite = sprite_jump_right
            
        elseif player.direction == -1 then
            player.sprite = sprite_jump_left
            
        end
    end

    
    

    -- Verifica colisão com o chão
    player.isOnGround = false
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
        end
       
    end
    
    

    -- Verifica colisões laterais
    local isCollidingLeft, isCollidingRight = checkLateralCollisions(player)

    -- Adiciona informações de depuração
    player.isCollidingLeft = isCollidingLeft
    player.isCollidingRight = isCollidingRight

    -- Configura a câmera para seguir o jogador ===================================================================
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

    local freio = 2 -- velocidade de freio no chao (quanto menor, mais ele desliza)
    if player.isOnGround and vx > freio then
        vx = vx - freio
    elseif player.isOnGround and vx < -freio then
        vx = vx + freio
    elseif player.isOnGround then
        vx = 0
    end
    if not player.isOnGround then
        if player.isCollidingLeft then
            vx = -vx 
        elseif player.isCollidingRight then
            vx = -vx
        end
    end
     -- Aplica a velocidade horizontal sempre, mas mantém a velocidade vertical
     player.hitbox:setLinearVelocity(vx, vy)

end
-- =================================================================================================================
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

    -- Desenha as hitbox do mundo físico (opcional)
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
    love.graphics.print("x: " .. tostring(player.hitbox:getX()), 10, 50)
    love.graphics.print("y: " .. tostring(player.hitbox:getY()), 10, 70)

    -- Adicione isso após camera:detach() para desenhar a barra de carga do salto
    -- Barra de fundo
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", 10, love.graphics.getHeight() - 30, jumpChargeBarWidth, jumpChargeBarHeight)
    
    -- Barra de carga
    love.graphics.setColor(0, 1, 0)
    if(player.jumpCharge == 1) then
        love.graphics.setColor(1, 0, 0)
    end
    -- Resetar a cor
    love.graphics.rectangle("fill", 10, love.graphics.getHeight() - 30, jumpChargeBarWidth * (player.jumpCharge or 0), jumpChargeBarHeight)
    love.graphics.setColor(1, 1, 1)

    -- Adiciona texto de depuração para colisões laterais
    love.graphics.print("Colidindo à esquerda: " .. tostring(player.isCollidingLeft), 10, 90)
    love.graphics.print("Colidindo à direita: " .. tostring(player.isCollidingRight), 10, 110)

end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        reiniciarJogo()
    end
end

-- Adicione esta nova função no final do arquivo
function reiniciarJogo()
    -- Recarrega o mapa
    map = sti("mapa/mapa.lua")
    if not map then
        print("Erro ao recarregar o mapa!")
        love.event.quit()
        return
    end

    -- Recria o mundo físico
    world:destroy()
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 1000)

    -- Redefine as classes de colisão
    world:addCollisionClass('Player')
    world:addCollisionClass('Ground')

    -- Recria o jogador
    local x = map.width * map.tilewidth / 2
    local y = map.height * map.tileheight * 0.96
    player.hitbox = world:newRectangleCollider(x, y, player.width, player.height)
    player.hitbox:setCollisionClass('Player')
    player.hitbox:setFixedRotation(true)
    player.hitbox:setFriction(0)
    player.direction = 1
    player.sprite = sprite_right
    player.jumpCharge = 0

    -- Recria as colisões do mapa
    if map.layers["colision"] then
        for _, object in ipairs(map.layers["colision"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setType("static")
            collider:setCollisionClass('Ground')
        end
    end
end


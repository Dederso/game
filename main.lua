function love.load()

-- Configurações iniciais do jogo ==========================================================================================
    love.window.setTitle("Lunatic Astronaut")
    love.graphics.setBackgroundColor(0.5, 0.5, 0.5)
    love.graphics.setDefaultFilter("nearest", "nearest")

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
        {width = 1024, height = 576} -- Resolução mais baixa
    }
    baixa = resolutions[3]
    media = resolutions[2]
    alta = resolutions[1]

-- Configura a janela do jogo ================================================================================================
    local screenWidth, screenHeight = love.window.getDesktopDimensions()
    resolution = {width = screenWidth, height = screenHeight}
    love.window.setMode(resolution.width, resolution.height, {
        resizable = true,
        vsync = true,
        minwidth = 400,
        minheight = 300,
        fullscreen = true -- Adiciona a opção de tela cheia
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
    sprites = {
        idle_right = love.graphics.newImage("assets/Sprite_astronauta_idle_right.png"),
        idle_left = love.graphics.newImage("assets/Sprite_astronauta_idle_left.png"),
        run_right = {
            love.graphics.newImage("assets/Sprite_astronauta_running_right_1.png"),
            love.graphics.newImage("assets/Sprite_astronauta_running_right_2.png")
        },
        run_left = {
            love.graphics.newImage("assets/Sprite_astronauta_running_left_1.png"),
            love.graphics.newImage("assets/Sprite_astronauta_running_left_2.png")
        },
        jump_right = love.graphics.newImage("assets/Sprite_astronauta_jumping_right.png"),
        jump_left = love.graphics.newImage("assets/Sprite_astronauta_jumping_left.png")
    }

    -- Configuração das animações
    animations = {
        run_right = {frames = sprites.run_right, current = 1, timer = 0},
        run_left = {frames = sprites.run_left, current = 1, timer = 0}
    }

    player = {
        width = 32,
        height = 63, --um pixel menos para que ele nao fique colidindo com 2 tiles para cima
        width_sprite = 64,
        height_sprite = 64,
        speed = 300,
        jumpForce = 900,
        jumpCharge = 0,
        isOnGround = false,
        direction = 1,  -- 1 para direita, -1 para esquerda
        currentSprite = sprites.idle_right,
        animationState = "idle"
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
        player.sprite = sprites.idle_right
    elseif player.direction == -1 then
        player.sprite = sprites.idle_left
    end
    -- Movimento do jogador ===============================================================================================
    local vx, vy = player.hitbox:getLinearVelocity()
    local px, py = player.hitbox:getPosition()

    -- Atualiza a animação
    if player.isOnGround then
        if math.abs(vx) < 1 then
            player.animationState = "idle"
            player.currentSprite = player.direction == 1 and sprites.idle_right or sprites.idle_left
        else
            player.animationState = "run"
            local anim = player.direction == 1 and animations.run_right or animations.run_left
            anim.timer = anim.timer + dt
            if anim.timer > 0.2 then  -- Mude o tempo aqui para ajustar a velocidade da animação
                anim.current = anim.current % #anim.frames + 1
                anim.timer = 0
            end
            player.currentSprite = anim.frames[anim.current]
        end
    else
        player.animationState = "jump"
        player.currentSprite = player.direction == 1 and sprites.jump_right or sprites.jump_left
    end

    -- Movimento horizontal do jogador (esquerda e direita) =================================================================
    if (love.keyboard.isDown("left") or love.keyboard.isDown("a")) and player.isOnGround and player.jumpCharge == 0 then
        vx = -player.speed
        player.direction = -1
    elseif (love.keyboard.isDown("right") or love.keyboard.isDown("d")) and player.isOnGround and player.jumpCharge == 0 then
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
                vy = -player.jumpForce * (player.jumpCharge + 0.25-(player.jumpCharge*0.25))
                vx = player.speed * player.direction * player.jumpCharge
            end
        end
        player.jumpCharge = 0
    end

    if not player.isOnGround then
        if player.direction == 1 then
            player.sprite = sprites.jump_right
            
        elseif player.direction == -1 then
            player.sprite = sprites.jump_left
            
        end
    end

    
    

    -- Verifica colisão com o chão ==========================================================================================
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

    local freio = 4 -- velocidade de freio no chao (quanto menor, mais ele desliza)
    if player.isOnGround and vx > freio then
        vx = vx - freio
    elseif player.isOnGround and vx < -freio then
        vx = vx + freio
    elseif player.isOnGround then
        vx = 0
    end
    -- Inverte a velocidade horizontal se houver colisão lateral ==========================================================
    if not player.isOnGround then
        if player.isCollidingLeft then
            vx = -vx 
        elseif player.isCollidingRight then
            vx = -vx
        end
    end

     -- Aplica a velocidade horizontal sempre, mas mantém a velocidade vertical atual se houver colisão lateral ========
     player.hitbox:setLinearVelocity(vx, vy)

end
-- Desenha o jogo ===========================================================================================================
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

    local spriteWidth = player.currentSprite:getWidth()
    local spriteHeight = player.currentSprite:getHeight()
    local scaleX = player.width_sprite / spriteWidth
    local scaleY = player.height_sprite / spriteHeight
    -- Desenha o sprite atual do jogador
    love.graphics.draw(
        player.currentSprite,
        player.hitbox:getX(),
        player.hitbox:getY(),
        0,
        scaleX,
        scaleY,
        spriteWidth/2,
        spriteHeight/2
    )
    camera:detach()

    -- Adiciona texto de depuração ===========================================================================================
    world:draw() -- Desenha as hitboxes
    love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    love.graphics.print("x: " .. tostring(player.hitbox:getX()), 10, 50)
    love.graphics.print("y: " .. tostring(player.hitbox:getY()), 10, 70)

    -- Adicione isso após camera:detach() para desenhar a barra de carga do salto
    -- Barra de fundo
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", 10, love.graphics.getHeight() - 30, jumpChargeBarWidth, jumpChargeBarHeight)
    
    -- Barra de carga
    
    if(player.jumpCharge == 1) then
        love.graphics.setColor(0, 1, 0)  -- Verde
    elseif(player.jumpCharge > 0.25) then
        love.graphics.setColor(1, 1, 0)  -- Amarelo 
    else
        love.graphics.setColor(1, 0, 0) -- Vermelho
    end
    -- Resetar a cor
    love.graphics.rectangle("fill", 10, love.graphics.getHeight() - 30, jumpChargeBarWidth * (player.jumpCharge or 0), jumpChargeBarHeight)
    love.graphics.setColor(1, 1, 1)

    -- Adiciona texto de depuração para colisões laterais
    love.graphics.print("Colidindo à esquerda: " .. tostring(player.isCollidingLeft), 10, 90)
    love.graphics.print("Colidindo à direita: " .. tostring(player.isCollidingRight), 10, 110)

end

-- Função para redimensionar a janela =======================================================================================
function love.resize(w, h)
    camera:resize(w, h)
end

-- Função para fechar o jogo ===============================================================================================
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
    player.sprite = sprites.idle_right
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


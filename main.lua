-- Adicione estas variáveis globais no início do arquivo
local gameState = "menu"
local menuOptions = {"Jogar", "Sair"}
local selectedOption = 1
local tempoInicio = 0
local tempoFinal = 0
local jogoFinalizado = false

--[[
    Função para desenhar o menu
]] 
function love.load()    
    -- Adicione esta linha para carregar a fonte do menu =======================================================================
    menuFont = love.graphics.newFont(32)
    -- Carrega a imagem de fundo do menu ========================================================================================
    menuBackground = love.graphics.newImage("assets/background_Menu.jpg")
    -- Configurações iniciais do jogo ==========================================================================================
    love.window.setTitle("Lunatic Astronaut")
    love.graphics.setBackgroundColor(0.5, 0.5, 0.5)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Importa as bibliotecas ====================================================================================================
    wf = require "libraries/windfield"
    sti = require "libraries/sti"
    cameralib = require "libraries/camera"

    -- Cria o mundo físico =======================================================================================================
    camera = cameralib()
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 1000)

    -- Lista de resoluções suportadas ==========================================================================================
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
        vsync = false,
        minwidth = 400,
        minheight = 300,
        fullscreen = true -- Adiciona a opção de tela cheia
    })

    -- Carrega o mapa ===========================================================================================================
    map = sti("mapa/mapa.lua")    
    -- Verifica se o mapa foi carregado corretamente ==============================================================================
    if not map then
        print("Erro ao carregar o mapa!")
        love.event.quit()
        return
    end

    -- Definir classes de colisão ===============================================================================================
    world:addCollisionClass('Player')
    world:addCollisionClass('Ground')
    world:addCollisionClass('objetivo extra 1',{ignores = {'Player'}})
    world:addCollisionClass('objetivo final',{ignores = {'Player'}})

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
        jump_left = love.graphics.newImage("assets/Sprite_astronauta_jumping_left.png"),
        coin = love.graphics.newImage("assets/coin.png")
    }

    -- Carrega os sons do jogo ================================================================================================
    sounds = {
        jump = love.audio.newSource("sounds/cartoon_jump.mp3", "static"),
        ambient = love.audio.newSource("sounds/ambient_sound.mp3", "stream"),
        pick_up = love.audio.newSource("sounds/pick_up_item.mp3", "static"),
        step = love.audio.newSource("sounds/step.mp3", "static")
    }

    -- Configuração das animações do jogador =================================================================================
    animations = {
        run_right = {frames = sprites.run_right, current = 1, timer = 0},
        run_left = {frames = sprites.run_left, current = 1, timer = 0}
    }
    -- Configurações do jogador ===============================================================================================
    player = {
        width = 32,
        height = 63, --um pixel menos para que ele nao fique colidindo com 2 tiles para cima
        width_sprite = 64,
        height_sprite = 64,
        speed = 300,
        jumpForce = 800,
        jumpCharge = 0,
        isOnGround = false,
        direction = 1,  -- 1 para direita, -1 para esquerda
        currentSprite = sprites.idle_right,
        animationState = "idle",
        extra_objetivo = 0
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
    -- Adicione esta linha para armazenar os coletáveis
    objetivosExtras = {}
    if map.layers["objetivo extra 1"] then
        for _, object in ipairs(map.layers["objetivo extra 1"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setCollisionClass('objetivo extra 1')
            collider:setType("static")
            table.insert(objetivosExtras, {collider = collider, collected = false,w= object.width, h= object.height})
        end
    end
    if map.layers["objetivo final"] then
        for _, object in ipairs(map.layers["objetivo final"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setCollisionClass('objetivo final')
            collider:setType("static")
            table.insert(objetivosExtras, {collider = collider,w= object.width, h= object.height})
        end
    end
    -- Adicione isso ao final da função love.load()
    jumpChargeBarWidth = 100
    jumpChargeBarHeight = 10

    -- Adicione estas variáveis globais no início do arquivo, após a declaração das resoluções
    currentResolutionIndex = 1
    isFullscreen = true
    
    tempoInicio = love.timer.getTime()
    jogoFinalizado = false
end

-- Função para verificar colisões laterais ===================================================================================
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
    if gameState == "playing" and not jogoFinalizado then
        -- Atualiza o mundo físico =================================================================================================
        world:update(dt)
        if player.direction == 1 then
            player.sprite = sprites.idle_right
        elseif player.direction == -1 then
            player.sprite = sprites.idle_left
        end

        -- Ativa o som ambiente do jogo ===============================================================================================
        if not sounds.ambient:isPlaying() then
            sounds.ambient:setLooping(true)
            love.audio.play(sounds.ambient)
        end

        -- Movimento do jogador ===============================================================================================
        local vx, vy = player.hitbox:getLinearVelocity()
        local px, py = player.hitbox:getPosition()
        if(py <=640) then
            world:setGravity(0, 400)
        else
            world:setGravity(0, 1000)
        end
        -- Verifica colisão com os objetivos extras e coleta se houver colisão ====================================================
        if(player.hitbox:enter("objetivo extra 1")) then
            for i, objetivo in ipairs(objetivosExtras) do
                if not objetivo.collected and player.hitbox:enter('objetivo extra 1') then
                    if player.hitbox:getEnterCollisionData('objetivo extra 1').collider == objetivo.collider then
                        objetivo.collected = true
                        objetivo.collider:destroy()
                        player.extra_objetivo = player.extra_objetivo + 1
                        love.audio.play(sounds.pick_up)
                        break
                    end
                end
            end
        end
        -- Atualiza a animação do jogador com base no estado atual ============================================================
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
                love.audio.play(sounds.step)
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
        -- Pulo do jogador com base na barra de carga ===============================================================================
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
                    vx = player.speed * player.direction * (player.jumpCharge + 0.25-(player.jumpCharge*0.25))
                    love.audio.play(sounds.jump)
                end
            end
            player.jumpCharge = 0
        end

        -- Atualiza a animação de pulo do jogador ===============================================================================
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
        
        -- Verifica colisões laterais do jogador =================================================================================
        local isCollidingLeft, isCollidingRight = checkLateralCollisions(player)

        -- Adiciona informações de depuração ======================================================================================
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

        local freio = 10 -- velocidade de freio no chao (quanto menor, mais ele desliza) ========================================
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
        if player.hitbox:enter("objetivo final") then
            for _, objetivo in ipairs(objetivosExtras) do
                if player.hitbox:getEnterCollisionData('objetivo final').collider == objetivo.collider then
                    tempoFinal = love.timer.getTime() - tempoInicio
                    jogoFinalizado = true
                    break
                end
            end
        end
         -- Aplica a velocidade horizontal sempre, mas mantém a velocidade vertical atual se houver colisão lateral ========
         player.hitbox:setLinearVelocity(vx, vy)
    elseif gameState == "menu" then
        -- Lógica simples do menu
        if love.keyboard.isDown("up") then
            selectedOption = math.max(1, selectedOption - 1)
        elseif love.keyboard.isDown("down") then
            selectedOption = math.min(#menuOptions, selectedOption + 1)
        end
    end
end

-- Desenha o jogo ===========================================================================================================
function love.draw()
    if gameState == "playing" then
        camera:attach()
            -- Desenha o mapa do jogo ============================================================================================
            if map then
                for i, layer in ipairs(map.layers) do
                    if layer.name ~= "colision" and layer.name ~= "objetivo extra 1" then
                        layer:draw()
                    elseif layer.name == "objetivo extra 1" then
                        -- Desenha apenas os objetivos não coletados
                        for j, objeto in ipairs(objetivosExtras) do
                            if not objeto.collected then
                                local x, y = objeto.collider:getPosition()
                                love.graphics.draw(sprites.coin, x, y, 0, 1, 1, sprites.coin:getWidth()/2, sprites.coin:getHeight()/2)
                            end
                        end
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
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)

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
        love.graphics.setColor(0, 0, 0)
        -- love.graphics.print("objetivo extra: " .. tostring(player.extra_objetivo), 10, 20)
        love.graphics.setColor(1, 1, 1)

        if jogoFinalizado then
            fimDeJogo()
        end
    elseif gameState == "menu" then
        -- Desenhe o menu
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(menuBackground, 0, 0)
        love.graphics.setFont(menuFont)
        for i, option in ipairs(menuOptions) do
            if i == selectedOption then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.print(option, 300, 200 + i * 50)
        end
    end
end

-- Função para redimensionar a janela =======================================================================================
function love.resize(w, h)
    atualizarCamera()
end

-- Função para fechar o jogo ===============================================================================================
function love.keypressed(key)
    if jogoFinalizado then
        if key == "r" then
            jogoFinalizado = false
            tempoInicio = love.timer.getTime()
            tempoFinal = 0
            reiniciarJogo()      
        elseif key == "escape" then
            gameState = "menu"
            jogoFinalizado = false
        end
    elseif gameState == "menu" then
        if key == "return" then
            if selectedOption == 1 then
                gameState = "playing"
                -- Aqui você pode adicionar código para iniciar o jogo
            elseif selectedOption == 2 then
                love.event.quit()
            end
        end
    elseif gameState == "playing" then
        if key == "escape" then
            gameState = "menu"
            love.audio.stop(sounds.ambient)
        elseif key == "r" then
            reiniciarJogo()
        elseif key == "t" then
            mudarResolucao()
        elseif key == "f" then
            alternarTelaCheia()
        end
    end
end

-- Adicione estas novas funções no final do arquivo
function mudarResolucao()
    currentResolutionIndex = (currentResolutionIndex % #resolutions) + 1
    local newResolution = resolutions[currentResolutionIndex]
    love.window.setMode(newResolution.width, newResolution.height, {
        fullscreen = isFullscreen,
        resizable = true,
        vsync = true,
        minwidth = 400,
        minheight = 300
    })
    atualizarCamera()
end

function alternarTelaCheia()
    isFullscreen = not isFullscreen
    love.window.setFullscreen(isFullscreen)
    if not isFullscreen then
        local currentResolution = resolutions[currentResolutionIndex]
        love.window.setMode(currentResolution.width, currentResolution.height, {
            fullscreen = false,
            resizable = true,
            vsync = true,
            minwidth = 400,
            minheight = 300
        })
    end
    atualizarCamera()
end

function atualizarCamera()
    local w, h = love.graphics.getDimensions()
    -- Atualiza a posição da câmera para o centro da tela
    local px, py = player.hitbox:getPosition()
    camera:lookAt(px, py)

    -- Ajusta os limites da câmera
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
    world:addCollisionClass('objetivo extra 1',{ignores = {'Player'}})
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
    player.extra_objetivo = 0
    -- Recria as colisões do mapa
    if map.layers["colision"] then
        for _, object in ipairs(map.layers["colision"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setType("static")
            collider:setCollisionClass('Ground')
        end
    end
    objetivosExtras = {}
    if map.layers["objetivo extra 1"] then
        for _, object in ipairs(map.layers["objetivo extra 1"].objects) do
            local collider = world:newRectangleCollider(object.x, object.y, object.width, object.height)
            collider:setCollisionClass('objetivo extra 1')
            collider:setType("static")
            table.insert(objetivosExtras, {collider = collider, collected = false,w= object.width, h= object.height})
        end
    end
    tempoInicio = love.timer.getTime()
    tempoFinal = 0
    jogoFinalizado = false
end

-- Adicione esta nova função
function fimDeJogo()
    local tempoTotal = tempoFinal
    local minutos = math.floor(tempoTotal / 60)
    local segundos = math.floor(tempoTotal % 60)
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(menuFont)
    love.graphics.printf("Parabéns, você chegou ao final do jogo!!!", 0, love.graphics.getHeight() / 2 - 100, love.graphics.getWidth(), "center")
    love.graphics.printf("Extras adquiridos: " .. player.extra_objetivo, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
    love.graphics.printf(string.format("Tempo: %02d:%02d", minutos, segundos), 0, love.graphics.getHeight() / 2 + 50, love.graphics.getWidth(), "center")
    love.graphics.printf("Pressione 'R' para reiniciar ou 'ESC' para voltar ao menu", 0, love.graphics.getHeight() / 2 + 100, love.graphics.getWidth(), "center")
end


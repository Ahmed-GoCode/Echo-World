-- Echo World - A game of navigation through darkness using echolocation
-- Created by Ahmad

function love.load()
    -- Set window title and size
    love.window.setTitle("Echo World - by Ahmad")
    love.window.setMode(1000, 700, {resizable=true})
    
    -- Initialize random seed
    math.randomseed(os.time())
    
    -- Game states
    gameState = "menu"
    currentLevel = 1
    maxEchoes = 20
    echoesUsed = 0
    score = 0
    startTime = 0
    endTime = 0
    
    -- Player properties
    player = {
        x = 50,
        y = 50,
        radius = 12,
        speed = 160,
        color = {0.2, 0.8, 1.0}
    }
    
    -- Echo wave properties
    echoWaves = {}
    echoDuration = 1.8
    echoMaxRadius = 220
    
    -- Map properties
    tileSize = 40
    mapWidth = 22
    mapHeight = 16
    map = {}
    
    -- Game objects
    exit = {}
    enemies = {}
    collectibles = {}
    powerups = {}
    
    -- Visibility tracking
    revealedTiles = {}
    
    -- Generate sounds
    createGameSounds()
    
    -- Generate first level
    generateLevel(currentLevel)
    
    -- Load fonts
    titleFont = love.graphics.newFont(42)
    subtitleFont = love.graphics.newFont(28)
    regularFont = love.graphics.newFont(18)
end

function love.update(dt)
    if gameState == "playing" then
        updatePlayerMovement(dt)
        updateEchoWaves(dt)
        updateEnemies(dt)
        updateRevealedTiles(dt)
        updatePowerups(dt)
        checkAllCollisions()
        endTime = love.timer.getTime()
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.02, 0.02, 0.05)
    
    if gameState == "menu" then
        drawMainMenu()
    elseif gameState == "playing" then
        drawGameWorld()
    elseif gameState == "win" then
        drawGameWorld()
        drawWinScreen()
    elseif gameState == "lose" then
        drawGameWorld()
        drawLoseScreen()
    end
    
    drawHeadsUpDisplay()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    
    if key == "f" or key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
    
    if gameState == "menu" then
        if key == "return" or key == " " then
            startNewGame()
        end
    elseif gameState == "playing" then
        if key == "space" and echoesUsed < maxEchoes then
            createEchoWave()
        end
    elseif gameState == "win" or gameState == "lose" then
        if key == "r" then
            resetGame()
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and gameState == "playing" and echoesUsed < maxEchoes then
        createMouseEcho(x, y)
    end
end

function createMouseEcho(x, y)
    table.insert(echoWaves, {
        x = x,
        y = y,
        radius = 0,
        maxRadius = echoMaxRadius * 0.7,
        duration = 0,
        maxDuration = echoDuration * 0.8
    })
    
    echoSound:play()
    echoesUsed = echoesUsed + 1
    
    revealAreaAroundPoint(x, y, echoMaxRadius * 0.7)
end

function updatePlayerMovement(dt)
    local speed = player.speed * dt
    local newX, newY = player.x, player.y
    
    if love.keyboard.isDown("left", "a") then
        newX = newX - speed
    end
    if love.keyboard.isDown("right", "d") then
        newX = newX + speed
    end
    if love.keyboard.isDown("up", "w") then
        newY = newY - speed
    end
    if love.keyboard.isDown("down", "s") then
        newY = newY + speed
    end
    
    if not checkWallCollision(newX, newY) then
        player.x = newX
        player.y = newY
    end
    
    player.x = math.max(player.radius, math.min(player.x, mapWidth * tileSize - player.radius))
    player.y = math.max(player.radius, math.min(player.y, mapHeight * tileSize - player.radius))
end

function checkWallCollision(x, y)
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1
    
    if gridX >= 1 and gridX <= mapWidth and gridY >= 1 and gridY <= mapHeight then
        if map[gridY][gridX] == 1 then
            return true
        end
    end
    
    return false
end

function createEchoWave()
    table.insert(echoWaves, {
        x = player.x,
        y = player.y,
        radius = 0,
        maxRadius = echoMaxRadius,
        duration = 0,
        maxDuration = echoDuration
    })
    
    echoSound:play()
    echoesUsed = echoesUsed + 1
    
    revealAreaAroundPoint(player.x, player.y, echoMaxRadius)
end

function revealAreaAroundPoint(centerX, centerY, radius)
    for y = 1, mapHeight do
        for x = 1, mapWidth do
            local tileX = (x - 1) * tileSize + tileSize / 2
            local tileY = (y - 1) * tileSize + tileSize / 2
            local distance = math.sqrt((centerX - tileX)^2 + (centerY - tileY)^2)
            
            if distance <= radius then
                revealedTiles[y * mapWidth + x] = echoDuration
            end
        end
    end
    
    for _, enemy in ipairs(enemies) do
        local distance = math.sqrt((centerX - enemy.x)^2 + (centerY - enemy.y)^2)
        if distance <= radius then
            enemy.revealed = echoDuration
        end
    end
    
    for _, collectible in ipairs(collectibles) do
        local distance = math.sqrt((centerX - collectible.x)^2 + (centerY - collectible.y)^2)
        if distance <= radius then
            collectible.revealed = echoDuration
        end
    end
    
    for _, powerup in ipairs(powerups) do
        local distance = math.sqrt((centerX - powerup.x)^2 + (centerY - powerup.y)^2)
        if distance <= radius then
            powerup.revealed = echoDuration
        end
    end
    
    local distance = math.sqrt((centerX - exit.x)^2 + (centerY - exit.y)^2)
    if distance <= radius then
        exit.revealed = echoDuration
    end
end

function updateEchoWaves(dt)
    for i = #echoWaves, 1, -1 do
        local wave = echoWaves[i]
        wave.radius = wave.radius + (wave.maxRadius / wave.maxDuration) * dt
        wave.duration = wave.duration + dt
        
        if wave.duration >= wave.maxDuration then
            table.remove(echoWaves, i)
        end
    end
end

function updateEnemies(dt)
    for _, enemy in ipairs(enemies) do
        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 0 then
            dx = dx / distance
            dy = dy / distance
        end
        
        enemy.x = enemy.x + dx * enemy.speed * dt
        enemy.y = enemy.y + dy * enemy.speed * dt
        
        if enemy.revealed then
            enemy.revealed = enemy.revealed - dt
            if enemy.revealed <= 0 then
                enemy.revealed = nil
            end
        end
    end
end

function updatePowerups(dt)
    for _, powerup in ipairs(powerups) do
        if powerup.revealed then
            powerup.revealed = powerup.revealed - dt
            if powerup.revealed <= 0 then
                powerup.revealed = nil
            end
        end
        
        powerup.pulseTime = (powerup.pulseTime or 0) + dt
    end
end

function updateRevealedTiles(dt)
    for key, timer in pairs(revealedTiles) do
        revealedTiles[key] = timer - dt
        if revealedTiles[key] <= 0 then
            revealedTiles[key] = nil
        end
    end
    
    if exit.revealed then
        exit.revealed = exit.revealed - dt
        if exit.revealed <= 0 then
            exit.revealed = nil
        end
    end
    
    for _, collectible in ipairs(collectibles) do
        if collectible.revealed then
            collectible.revealed = collectible.revealed - dt
            if collectible.revealed <= 0 then
                collectible.revealed = nil
            end
        end
    end
end

function checkAllCollisions()
    for _, enemy in ipairs(enemies) do
        local distance = math.sqrt((player.x - enemy.x)^2 + (player.y - enemy.y)^2)
        if distance < player.radius + enemy.radius then
            gameState = "lose"
            loseSound:play()
            return
        end
    end
    
    for i = #collectibles, 1, -1 do
        local collectible = collectibles[i]
        local distance = math.sqrt((player.x - collectible.x)^2 + (player.y - collectible.y)^2)
        if distance < player.radius + collectible.radius then
            table.remove(collectibles, i)
            score = score + 100
            collectSound:play()
        end
    end
    
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        local distance = math.sqrt((player.x - powerup.x)^2 + (player.y - powerup.y)^2)
        if distance < player.radius + powerup.radius then
            table.remove(powerups, i)
            applyPowerupEffect(powerup.type)
            collectSound:play()
        end
    end
    
    local distance = math.sqrt((player.x - exit.x)^2 + (player.y - exit.y)^2)
    if distance < player.radius + exit.radius then
        gameState = "win"
        score = score + math.max(0, 1000 - math.floor((endTime - startTime) * 10)) + (maxEchoes - echoesUsed) * 50
        winSound:play()
    end
end

function applyPowerupEffect(powerType)
    if powerType == "echo" then
        maxEchoes = maxEchoes + 5
    elseif powerType == "speed" then
        player.speed = player.speed * 1.4
        timer.performAfterDelay(10, function()
            player.speed = player.speed / 1.4
        end)
    elseif powerType == "vision" then
        echoMaxRadius = echoMaxRadius * 1.5
        timer.performAfterDelay(8, function()
            echoMaxRadius = echoMaxRadius / 1.5
        end)
    end
end

function drawMainMenu()
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.2, 0.8, 1.0)
    love.graphics.printf("ECHO WORLD", 0, 120, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.8, 0.8, 1.0)
    love.graphics.printf("by Ahmad", 0, 190, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(regularFont)
    love.graphics.setColor(0.9, 0.9, 1.0)
    love.graphics.printf("Navigate through darkness using echolocation", 0, 280, love.graphics.getWidth(), "center")
    love.graphics.printf("SPACE to echo | Mouse Click for targeted echo", 0, 320, love.graphics.getWidth(), "center")
    love.graphics.printf("Find the exit while avoiding enemies", 0, 360, love.graphics.getWidth(), "center")
    
    love.graphics.setColor(0.2, 1.0, 0.4)
    love.graphics.printf("Press ENTER or SPACE to start", 0, 450, love.graphics.getWidth(), "center")
    
    love.graphics.setColor(0.8, 0.8, 0.2)
    love.graphics.printf("F for fullscreen | ESC to quit", 0, 520, love.graphics.getWidth(), "center")
    
    local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 3)
    love.graphics.setColor(1.0, 1.0, 1.0, pulse)
    love.graphics.circle("line", love.graphics.getWidth()/2, 550, 20 + 5 * math.sin(love.timer.getTime() * 2))
end

function drawGameWorld()
    for y = 1, mapHeight do
        for x = 1, mapWidth do
            local key = y * mapWidth + x
            if revealedTiles[key] then
                local alpha = math.min(1, revealedTiles[key] / echoDuration)
                if map[y][x] == 1 then
                    love.graphics.setColor(0.4, 0.4, 0.5, alpha)
                    love.graphics.rectangle("fill", (x-1)*tileSize, (y-1)*tileSize, tileSize, tileSize)
                else
                    love.graphics.setColor(0.15, 0.15, 0.2, alpha * 0.5)
                    love.graphics.rectangle("fill", (x-1)*tileSize, (y-1)*tileSize, tileSize, tileSize)
                end
            end
        end
    end
    
    if exit.revealed then
        local alpha = math.min(1, exit.revealed / echoDuration)
        love.graphics.setColor(0.2, 1.0, 0.2, alpha)
        love.graphics.circle("fill", exit.x, exit.y, exit.radius)
        love.graphics.setColor(0.8, 1.0, 0.8, alpha * 0.5)
        love.graphics.circle("line", exit.x, exit.y, exit.radius * 1.5)
    end
    
    for _, collectible in ipairs(collectibles) do
        if collectible.revealed then
            local alpha = math.min(1, collectible.revealed / echoDuration)
            love.graphics.setColor(1.0, 0.9, 0.2, alpha)
            love.graphics.circle("fill", collectible.x, collectible.y, collectible.radius)
        else
            love.graphics.setColor(1.0, 1.0, 0.0, 0.15)
            love.graphics.circle("fill", collectible.x, collectible.y, collectible.radius / 2)
        end
    end
    
    for _, powerup in ipairs(powerups) do
        local pulse = 0.7 + 0.3 * math.sin(powerup.pulseTime * 3)
        
        if powerup.revealed then
            local alpha = math.min(1, powerup.revealed / echoDuration)
            if powerup.type == "echo" then
                love.graphics.setColor(0.2, 0.7, 1.0, alpha)
            elseif powerup.type == "speed" then
                love.graphics.setColor(1.0, 0.4, 0.2, alpha)
            elseif powerup.type == "vision" then
                love.graphics.setColor(0.6, 0.2, 1.0, alpha)
            end
            love.graphics.circle("fill", powerup.x, powerup.y, powerup.radius)
        else
            if powerup.type == "echo" then
                love.graphics.setColor(0.2, 0.5, 0.8, 0.2 * pulse)
            elseif powerup.type == "speed" then
                love.graphics.setColor(0.8, 0.3, 0.1, 0.2 * pulse)
            elseif powerup.type == "vision" then
                love.graphics.setColor(0.5, 0.1, 0.8, 0.2 * pulse)
            end
            love.graphics.circle("fill", powerup.x, powerup.y, powerup.radius / 2)
        end
    end
    
    for _, enemy in ipairs(enemies) do
        if enemy.revealed then
            local alpha = math.min(1, enemy.revealed / echoDuration)
            love.graphics.setColor(1.0, 0.2, 0.2, alpha)
            love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius)
        end
    end
    
    for _, wave in ipairs(echoWaves) do
        local alpha = 1 - (wave.duration / wave.maxDuration)
        love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.5)
        love.graphics.circle("line", wave.x, wave.y, wave.radius)
    end
    
    love.graphics.setColor(player.color)
    love.graphics.circle("fill", player.x, player.y, player.radius)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.8)
    love.graphics.circle("line", player.x, player.y, player.radius)
end

function drawHeadsUpDisplay()
    love.graphics.setFont(regularFont)
    love.graphics.setColor(0.9, 0.9, 1.0)
    love.graphics.print("Echoes: " .. echoesUsed .. "/" .. maxEchoes, 20, 20)
    love.graphics.print("Score: " .. score, 20, 50)
    
    if gameState == "playing" then
        local time = endTime - startTime
        love.graphics.print("Time: " .. string.format("%.1f", time), 20, 80)
    end
    
    if gameState == "win" or gameState == "lose" then
        love.graphics.print("Press R to restart", 20, 110)
    end
    
    love.graphics.print("Level: " .. currentLevel, love.graphics.getWidth() - 120, 20)
end

function drawWinScreen()
    love.graphics.setColor(0.0, 0.0, 0.0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.2, 1.0, 0.4)
    love.graphics.printf("LEVEL COMPLETE!", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.8, 1.0, 0.9)
    love.graphics.printf("Score: " .. score, 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(regularFont)
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.printf("Press R to play again", 0, love.graphics.getHeight()/2 + 50, love.graphics.getWidth(), "center")
end

function drawLoseScreen()
    love.graphics.setColor(0.0, 0.0, 0.0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1.0, 0.3, 0.3)
    love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1.0, 0.8, 0.8)
    love.graphics.printf("Score: " .. score, 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(regularFont)
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.printf("Press R to try again", 0, love.graphics.getHeight()/2 + 50, love.graphics.getWidth(), "center")
end

function generateLevel(level)
    echoWaves = {}
    enemies = {}
    collectibles = {}
    powerups = {}
    revealedTiles = {}
    echoesUsed = 0
    
    map = {}
    for y = 1, mapHeight do
        map[y] = {}
        for x = 1, mapWidth do
            if y == 1 or y == mapHeight or x == 1 or x == mapWidth then
                map[y][x] = 1
            else
                if math.random() < 0.12 + (level * 0.04) then
                    map[y][x] = 1
                else
                    map[y][x] = 0
                end
            end
        end
    end
    
    repeat
        player.x = math.random(2, mapWidth - 1) * tileSize - tileSize / 2
        player.y = math.random(2, mapHeight - 1) * tileSize - tileSize / 2
    until not checkWallCollision(player.x, player.y)
    
    repeat
        exit.x = math.random(2, mapWidth - 1) * tileSize - tileSize / 2
        exit.y = math.random(2, mapHeight - 1) * tileSize - tileSize / 2
        exit.radius = 15
        exit.revealed = nil
    until math.sqrt((player.x - exit.x)^2 + (player.y - exit.y)^2) > 200
    
    for i = 1, level + 1 do
        local enemy = {
            x = 0,
            y = 0,
            radius = 9,
            speed = 45 + (level * 12),
            revealed = nil
        }
        
        repeat
            enemy.x = math.random(2, mapWidth - 1) * tileSize - tileSize / 2
            enemy.y = math.random(2, mapHeight - 1) * tileSize - tileSize / 2
        until not checkWallCollision(enemy.x, enemy.y) and 
              math.sqrt((player.x - enemy.x)^2 + (player.y - enemy.y)^2) > 120
        
        table.insert(enemies, enemy)
    end
    
    for i = 1, level + 3 do
        local collectible = {
            x = 0,
            y = 0,
            radius = 6,
            revealed = nil
        }
        
        repeat
            collectible.x = math.random(2, mapWidth - 1) * tileSize - tileSize / 2
            collectible.y = math.random(2, mapHeight - 1) * tileSize - tileSize / 2
        until not checkWallCollision(collectible.x, collectible.y)
        
        table.insert(collectibles, collectible)
    end
    
    for i = 1, math.min(level, 3) do
        local powerup = {
            x = 0,
            y = 0,
            radius = 8,
            revealed = nil,
            pulseTime = 0,
            type = ({"echo", "speed", "vision"})[math.random(1, 3)]
        }
        
        repeat
            powerup.x = math.random(2, mapWidth - 1) * tileSize - tileSize / 2
            powerup.y = math.random(2, mapHeight - 1) * tileSize - tileSize / 2
        until not checkWallCollision(powerup.x, powerup.y)
        
        table.insert(powerups, powerup)
    end
    
    maxEchoes = 25 - (level * 3)
    if maxEchoes < 8 then maxEchoes = 8 end
end

function startNewGame()
    gameState = "playing"
    startTime = love.timer.getTime()
    score = 0
    currentLevel = 1
    generateLevel(currentLevel)
end

function resetGame()
    gameState = "menu"
    score = 0
    currentLevel = 1
    generateLevel(currentLevel)
end

function createGameSounds()
    local function generateTone(duration, frequency)
        local sampleRate = 44100
        local samples = math.floor(duration * sampleRate)
        local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
        
        for i = 0, samples - 1 do
            local time = i / sampleRate
            local value = math.sin(2 * math.pi * frequency * time) * math.exp(-3 * time)
            soundData:setSample(i, value)
        end
        
        return love.audio.newSource(soundData, "static")
    end
    
    echoSound = generateTone(0.6, 440)
    collectSound = generateTone(0.3, 880)
    winSound = generateTone(1.2, 660)
    loseSound = generateTone(1.0, 220)
end

-- Simple timer system
timer = {
    delayedFunctions = {}
}

function timer.performAfterDelay(delay, func)
    table.insert(timer.delayedFunctions, {
        time = love.timer.getTime() + delay,
        func = func
    })
end

function love.update(dt)
    -- Update timers
    local currentTime = love.timer.getTime()
    for i = #timer.delayedFunctions, 1, -1 do
        if currentTime >= timer.delayedFunctions[i].time then
            timer.delayedFunctions[i].func()
            table.remove(timer.delayedFunctions, i)
        end
    end
    
    -- Original update code
    if gameState == "playing" then
        updatePlayerMovement(dt)
        updateEchoWaves(dt)
        updateEnemies(dt)
        updateRevealedTiles(dt)
        updatePowerups(dt)
        checkAllCollisions()
        endTime = love.timer.getTime()
    end
end
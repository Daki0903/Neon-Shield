function love.load()
    love.window.setTitle("Neon Shield")
    love.window.setMode(600, 800)
    love.graphics.setBackgroundColor(0.02, 0.02, 0.05)
    function love.load()
        -- Učitavanje muzike
        music = love.audio.newSource("Music.mp3", "stream") -- Zamenite sa odgovarajućim imenom fajla
        music:setLooping(true)  -- Postavljanje muzike da se ponavlja
        music:play()  -- Pokretanje muzike
    end
    
    showMenu = true
    paused = false

    font = love.graphics.newFont(20)
    bigFont = love.graphics.newFont(36)
    missionFont = love.graphics.newFont(16)

    missions = {
        {desc = "Collect 5 power-ups", done = false, progress = 0, target = 5},
        {desc = "Survive 60 seconds", done = false, timer = 0, target = 60},
        {desc = "Collect 100 points without shield", done = false, score = 0, target = 100, active = true}
    }

    loadData()
end

function startGame()
    player = {
        x = 300,
        y = 700,
        radius = 15,
        speed = 350,
        trail = {}
    }

    obstacles = {}
    powerups = {}

    score = 0
    highscore = highscore or 0
    spawnTimer = 0
    powerupTimer = 0
    spawnRate = 0.9
    level = 1

    shield = false
    shieldTime = 0
    gameOver = false
    slowTime = 0
    magnet = false
    magnetTime = 0
    scoreMultiplier = false
    scoreMultiplierTime = 0

    totalObstacles = 0
    totalPowerups = 0
    gameTime = 0

    for _, m in ipairs(missions) do
        m.done = false
        if m.progress then m.progress = 0 end
        if m.timer then m.timer = 0 end
        if m.score then m.score = 0 end
        if m.active ~= nil then m.active = true end
    end
end

function love.update(dt)
    if showMenu or gameOver or paused then return end
    gameTime = gameTime + dt

    if not missions[2].done then
        missions[2].timer = missions[2].timer + dt
        if missions[2].timer >= missions[2].target then
            missions[2].done = true
        end
    end

    if love.keyboard.isDown("left", "a", "up") then
        player.x = player.x - player.speed * dt
    elseif love.keyboard.isDown("right", "d", "down") then
        player.x = player.x + player.speed * dt
    end

    player.x = math.max(player.radius, math.min(600 - player.radius, player.x))

    table.insert(player.trail, 1, {x = player.x, y = player.y, alpha = 1})
    if #player.trail > 30 then table.remove(player.trail) end
    for _, t in ipairs(player.trail) do
        t.alpha = t.alpha - dt * 2
    end

    spawnTimer = spawnTimer + dt
    if spawnTimer > spawnRate then
        spawnTimer = 0
        spawnObstacle()
    end

    powerupTimer = powerupTimer + dt
    if powerupTimer > 5 then
        powerupTimer = 0
        spawnPowerup()
    end

    if slowTime > 0 then slowTime = slowTime - dt end
    if magnet then
        magnetTime = magnetTime - dt
        if magnetTime <= 0 then magnet = false end
    end
    if scoreMultiplier then
        scoreMultiplierTime = scoreMultiplierTime - dt
        if scoreMultiplierTime <= 0 then scoreMultiplier = false end
    end

    for i = #obstacles, 1, -1 do
        local o = obstacles[i]
        o.y = o.y + (slowTime > 0 and o.speed * 0.3 or o.speed) * dt

        if checkCollisionCircle(player, o) then
            if shield then
                shield = false
                table.remove(obstacles, i)
            else
                gameOver = true
                if score > highscore then
                    highscore = score
                    saveData()
                end
            end
        elseif o.y > 820 then
            table.remove(obstacles, i)
            totalObstacles = totalObstacles + 1
            local earned = scoreMultiplier and 2 or 1
            score = score + earned
            if spawnRate > 0.3 then
                spawnRate = spawnRate - 0.005
            end

            if missions[3].active and not shield then
                missions[3].score = missions[3].score + earned
                if missions[3].score >= missions[3].target then
                    missions[3].done = true
                end
            elseif shield then
                missions[3].score = 0
            end
        end
    end

    for i = #powerups, 1, -1 do
        local p = powerups[i]
        p.y = p.y + p.speed * dt
        if magnet then
            local dx = p.x - player.x
            if math.abs(dx) < 5 then p.x = player.x else p.x = p.x - dx * dt * 2 end
        end

        if checkCollisionCircle(player, p) then
            applyPowerup(p.kind)
            missions[1].progress = missions[1].progress + 1
            if missions[1].progress >= missions[1].target then
                missions[1].done = true
            end
            totalPowerups = totalPowerups + 1
            table.remove(powerups, i)
        elseif p.y > 820 then
            table.remove(powerups, i)
        end
    end

    if shield then
        shieldTime = shieldTime - dt
        if shieldTime <= 0 then shield = false end
    end

    if score % 30 == 0 and score > 0 then
        level = math.floor(score / 30) + 1
        spawnRate = math.max(0.3, spawnRate - 0.02)
    end
end

function spawnObstacle()
    table.insert(obstacles, {
        x = math.random(30, 570),
        y = -10,
        radius = 15,
        speed = 200 + score * 3 + level * 5
    })
end

function spawnPowerup()
    local kinds = {"shield", "slow", "magnet", "multiplier"}
    local kind = kinds[math.random(#kinds)]
    table.insert(powerups, {
        x = math.random(40, 560),
        y = -10,
        radius = 10,
        speed = 100,
        kind = kind
    })
end

function applyPowerup(kind)
    if kind == "shield" then
        shield = true
        shieldTime = 5
    elseif kind == "slow" then
        slowTime = 3
    elseif kind == "magnet" then
        magnet = true
        magnetTime = 6
    elseif kind == "multiplier" then
        scoreMultiplier = true
        scoreMultiplierTime = 10
    end
end

function checkCollisionCircle(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist < a.radius + b.radius
end

function love.draw()
    if showMenu then
        love.graphics.setFont(bigFont)
        love.graphics.printf("Neon Shield", 0, 200, 600, "center")
        love.graphics.setFont(font)
        love.graphics.printf("Press ENTER to Start", 0, 300, 600, "center")
        return
    end

    for i = 0, 800, 40 do
        local alpha = 0.05 + 0.05 * math.sin(love.timer.getTime() + i * 0.1)
        love.graphics.setColor(0, 0.7, 1, alpha)
        love.graphics.rectangle("fill", 0, i, 600, 1)
    end

    for _, t in ipairs(player.trail) do
        love.graphics.setColor(0.2, 1, 1, t.alpha)
        love.graphics.circle("fill", t.x, t.y, player.radius * 0.7)
    end

    love.graphics.setColor(shield and {0, 1, 0.5, 0.8} or {0.4, 0.9, 1})
    love.graphics.circle("fill", player.x, player.y, player.radius)
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.circle("line", player.x, player.y, player.radius + 5)

    for _, o in ipairs(obstacles) do
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.circle("fill", o.x, o.y, o.radius)
    end

    for _, p in ipairs(powerups) do
        love.graphics.setColor(0, 1, 0.5)
        love.graphics.circle("line", p.x, p.y, p.radius)
    end

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 20, 20)
    love.graphics.print("Highscore: " .. highscore, 20, 50)
    love.graphics.print("Level: " .. level, 20, 80)
    if shield then
        love.graphics.print("Shield: " .. math.ceil(shieldTime), 20, 110)
    end
    if paused then
        love.graphics.setFont(bigFont)
        love.graphics.printf("Paused", 0, 350, 600, "center")
        love.graphics.setFont(font)
        love.graphics.printf("Press P to Resume", 0, 400, 600, "center")
        love.graphics.printf("R - Restart | ESC - Exit", 0, 430, 600, "center")
    end
    if gameOver then
        love.graphics.setFont(bigFont)
        love.graphics.printf("Game Over", 0, 300, 600, "center")
        love.graphics.setFont(font)
        love.graphics.printf("R - Restart | ESC - Exit", 0, 360, 600, "center")
        love.graphics.printf("Stats:", 20, 420, 600)
        love.graphics.print("Obstacles Passed: " .. totalObstacles, 20, 450)
        love.graphics.print("Powerups Collected: " .. totalPowerups, 20, 470)
        love.graphics.print("Time Played: " .. math.floor(gameTime) .. " sec", 20, 490)
    end

    local status = m.done and "✔" or "❌"
    local progressText = ""
    if m.progress then
        progressText = string.format(" (%d/%d)", m.progress, m.target)
    elseif m.timer then
        progressText = string.format(" (%.1f/%d sec)", m.timer, m.target)
    elseif m.score then
        progressText = string.format(" (%d/%d)", m.score, m.target)
    end
    love.graphics.print(status .. " " .. m.desc .. progressText, 20, 540 + i * 20)
end



function love.keypressed(key)
    if key == "return" and showMenu then
        showMenu = false
        startGame()
    elseif key == "p" and not gameOver and not showMenu then
        paused = not paused
    elseif key == "r" then
        if not showMenu then
            gameOver = false
            paused = false
            startGame()
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

function saveData()
    local data = {highscore = highscore}
    love.filesystem.write("data.lua", "return " .. table.tostring(data))
end

function loadData()
    if love.filesystem.getInfo("data.lua") then
        local chunk = love.filesystem.load("data.lua")
        local data = chunk()
        highscore = data.highscore or 0
    else
        highscore = 0
    end
end

function table.tostring(tbl)
    local str = "{"
    for k, v in pairs(tbl) do
        str = str .. k .. "=" .. tostring(v) .. ","
    end
    return str .. "}"
end

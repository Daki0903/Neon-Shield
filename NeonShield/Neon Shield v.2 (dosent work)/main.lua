function love.load()
    love.window.setTitle("Neon Shield")
    love.window.setMode(600, 800)
    love.graphics.setBackgroundColor(0.02, 0.02, 0.05) -- Dark background color

    -- Load the background music and set it to loop
    music = love.audio.newSource("Music.mp3", "stream")
    music:setLooping(true)
    music:play()

    -- Game state variables
    showMenu = true
    paused = false

    -- Fonts for various UI elements
    font = love.graphics.newFont(20)
    bigFont = love.graphics.newFont(36)
    missionFont = love.graphics.newFont(16)

    -- Define missions (you can add more or modify as needed)
    missions = {
        {desc = "Collect 5 power-ups", done = false, progress = 0, target = 5},
        {desc = "Survive 60 seconds", done = false, timer = 0, target = 60},
        {desc = "Collect 100 points without shield", done = false, score = 0, target = 100, active = true}
    }

    -- Load any saved data or initialize game state
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

    if love.keyboard.isDown("left", "a") then
        player.x = player.x - player.speed * dt
    elseif love.keyboard.isDown("right", "d") then
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

function love.keypressed(key)
    if showMenu and key == "return" then
        showMenu = false
        startGame()
    elseif key == "p" and not gameOver then
        paused = not paused
    elseif key == "r" and (gameOver or paused) then
        startGame()
        paused = false
        gameOver = false
    elseif key == "escape" then
        love.event.quit()
    end
end

function loadData()
    if love.filesystem.getInfo("save.txt") then
        local contents = love.filesystem.read("save.txt")
        highscore = tonumber(contents) or 0
    else
        highscore = 0
    end
end

function saveData()
    love.filesystem.write("save.txt", tostring(highscore))
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
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", o.x, o.y, o.radius)
    end

    for _, p in ipairs(powerups) do
        love.graphics.setColor(p.kind == "shield" and {0, 0, 1} or p.kind == "slow" and {1, 0.6, 0} or p.kind == "magnet" and {0, 1, 0} or {1, 1, 0})
        love.graphics.circle("fill", p.x, p.y, p.radius)
    end

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Score: " .. score, 0, 20, 600, "center")

    love.graphics.setFont(missionFont)
    for i, mission in ipairs(missions) do
        love.graphics.printf(mission.desc .. (mission.done and " (Completed)" or " (" .. (mission.progress or mission.timer or mission.score) .. "/" .. mission.target .. ")"), 20, 60 + i * 30, 560)
    end

    if gameOver then
        love.graphics.setFont(bigFont)
        love.graphics.printf("GAME OVER", 0, 350, 600, "center")
        love.graphics.setFont(font)
        love.graphics.printf("Highscore: " .. highscore, 0, 400, 600, "center")
        love.graphics.printf("Press 'R' to Restart", 0, 450, 600, "center")
    end

    if paused then
        love.graphics.setFont(bigFont)
        love.graphics.printf("PAUSED", 0, 350, 600, "center")
        love.graphics.setFont(font)
        love.graphics.printf("Press 'P' to Resume", 0, 400, 600, "center")
    end
end

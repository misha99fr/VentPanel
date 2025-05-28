local term = require("term")
local gpu = require("component").gpu
local event = require("event")
local sides = require("sides")
local rs = require("component").redstone
local computer = require("computer")
local thread = require("thread")

-- Инициализация redstone
rs.setOutput(sides.left, 15)
os.sleep(0.2)
rs.setOutput(sides.left, 0)

-- Логотип
function drawLogo()
  gpu.setForeground(0x00FFFF)
  gpu.setBackground(0x000000)
  term.clear()
  gpu.set(2, 2, "╔════════════════════════════╗")
  gpu.set(2, 3, "║     СИСТЕМА ВЕНТИЛЯЦИИ     ║")
  gpu.set(2, 4, "║         v1.0 ONLINE        ║")
  gpu.set(2, 5, "║        OpenComputers       ║")
  gpu.set(2, 6, "╚════════════════════════════╝")
  os.sleep(2)
end

-- Переменные
local screenWidth, screenHeight = gpu.getResolution()
local state, broken, doorClosed = 100, false, false
local repairTime, clicks, clickToBreak = 5, 0, 6
local temperature, temperatureWarning = 21, false
local emergencyActive, paused = false, false
local lureBroken, lureUses, lureBreakThreshold = false, 0, 3
local tempMode = "med"
local targetTemperature = 60

-- Подсчёт потребления
function calculateConsumption()
  local count = 0
  if doorClosed then count = count + 1 end
  if emergencyActive then count = count + 1 end
  return count
end

-- Переключение режима температуры
function cycleTemperatureMode()
  if tempMode == "low" then
    tempMode = "med"
    targetTemperature = 60
  elseif tempMode == "med" then
    tempMode = "high"
    targetTemperature = 120
  else
    tempMode = "low"
    targetTemperature = 10
  end
  drawScreen()
end

-- Интерфейс
function drawScreen()
  if paused then return end
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  term.clear()

  gpu.setForeground(0x00FFFF)
  gpu.set(2, 1, "[ Вентиляция ]")

  gpu.setForeground(0xFFFFFF)
  gpu.set(2, 3, "Состояние вентиляции: " .. math.floor(state) .. "%")
  gpu.set(2, 4, "Потребление: " .. calculateConsumption())
  if temperatureWarning then
    gpu.setForeground(0xFF0000)
    gpu.set(2, screenHeight - 1, "Внимание! Высокая температура, дверь неактивна")
  end
  gpu.setForeground(0xFFFFFF)
  gpu.set(2, screenHeight, "Температура: " .. math.floor(temperature) .. "°C")

  if not broken then
    gpu.setBackground(0xAAAAAA)
    gpu.setForeground(0x000000)
    gpu.fill(2, 5, 30, 1, " ")
    gpu.set(3, 5, temperatureWarning and "Дверь заблокирована" or (doorClosed and "Открыть дверь" or "Закрыть дверь"))

    gpu.fill(2, 7, 30, 1, " ")
    gpu.set(3, 7, "Сломать вентиляцию")

    gpu.fill(2, 9, 30, 1, " ")
    gpu.set(3, 9, emergencyActive and "Откл. экстр. режим" or "Экстренный режим")

    gpu.fill(2, 11, 30, 1, " ")
    gpu.set(3, 11, lureBroken and "Починить приманку" or "Звук. приманка")

    gpu.fill(2, 13, 30, 1, " ")
    gpu.set(3, 13, "Выйти")

    gpu.fill(2, 15, 30, 1, " ")
    gpu.set(3, 15, "Температура: " .. (
      tempMode == "low" and "Низкая" or
      tempMode == "med" and "Средняя" or
      "Высокая"
    ))
  else
    gpu.setBackground(0xFF0000)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(2, 5, 30, 1, " ")
    gpu.set(3, 5, "Вентиляция сломана!")
  end

  gpu.setBackground(0x000000)
end

-- Ремонт вентиляции
function repairVentilation()
  for i = 1, repairTime do
    gpu.setForeground(0x00FF00)
    gpu.set(2, 17, "Ремонт: " .. i .. "/" .. repairTime)
    os.sleep(1)
  end
  broken = false
  state = 100
  drawScreen()
end

-- Дверь
function toggleDoor()
  if temperatureWarning then return end
  doorClosed = not doorClosed
  rs.setOutput(sides.back, doorClosed and 15 or 0)
  drawScreen()
end

-- Экстренный режим
function toggleEmergency()
  emergencyActive = not emergencyActive
  rs.setOutput(sides.left, emergencyActive and 15 or 0)
  drawScreen()
end

-- Приманка
function playLure()
  lureUses = lureUses + 1
  if lureUses >= lureBreakThreshold then
    lureBroken = true
    drawScreen()
    return
  end
  term.clear()
  gpu.setForeground(0xFFFFFF)
  gpu.set(2, screenHeight // 2, "Играем...")
  for i = 1, 3 do
    computer.beep(1000, 0.3)
    os.sleep(1)
  end
  drawScreen()
end

-- Починка приманки
function repairLure()
  lureBroken = false
  lureUses = 0
  drawScreen()
end

-- Скринсейвер
function showScreensaver()
  paused = true
  term.clear()
  gpu.setBackground(0x000000)
  gpu.setForeground(0x00FF00)
  gpu.set(screenWidth // 2 - 5, screenHeight // 2, "УПРАВЛЕНИЕ")
  gpu.setBackground(0xAAAAAA)
  gpu.setForeground(0x000000)
  gpu.fill(2, screenHeight - 2, 30, 1, " ")
  gpu.set(3, screenHeight - 2, "Продолжить")
end

function resumeFromPause()
  paused = false
  drawScreen()
end

-- Обработка нажатий
function handleClick(x, y)
  if paused then
    if y == screenHeight - 2 and x >= 2 and x <= 32 then
      resumeFromPause()
    end
    return
  end
  if broken then return end
  if y == 5 and x >= 2 and x <= 32 then
    toggleDoor()
  elseif y == 7 and x >= 2 and x <= 32 then
    clicks = clicks + 1
    if clicks >= clickToBreak then
      broken = true
      clicks = 0
      drawScreen()
      thread.create(repairVentilation):detach()
    end
  elseif y == 9 and x >= 2 and x <= 32 then
    toggleEmergency()
  elseif y == 11 and x >= 2 and x <= 32 then
    if lureBroken then repairLure() else playLure() end
  elseif y == 13 and x >= 2 and x <= 32 then
    showScreensaver()
  elseif y == 15 and x >= 2 and x <= 32 then
    cycleTemperatureMode()
  end
end

-- Вентиляция
function ventilationDecay()
  while true do
    if not paused then
      local rate = calculateConsumption() >= 2 and 1 or 2
      if doorClosed and not broken and computer.uptime() % rate < 1 then
        state = state - 1
        if state <= 0 then
          state = 0
          broken = true
          doorClosed = false
          rs.setOutput(sides.back, 0)
          drawScreen()
          thread.create(repairVentilation):detach()
        end
        drawScreen()
      end
    end
    os.sleep(1)
  end
end

-- Температура
function temperatureControl()
  while true do
    if not paused then
      if temperature < targetTemperature then
        temperature = temperature + 0.5
      elseif temperature > targetTemperature then
        temperature = temperature - 0.5
      end

      if temperature >= 120 and not temperatureWarning then
        temperatureWarning = true
        doorClosed = false
        rs.setOutput(sides.back, 0)
      elseif temperature <= 100 and temperatureWarning then
        temperatureWarning = false
      end

      drawScreen()
    end
    os.sleep(1)
  end
end

-- Старт
drawLogo()
drawScreen()
thread.create(ventilationDecay):detach()
thread.create(temperatureControl):detach()

while true do
  local _, _, x, y = event.pull("touch")
  handleClick(x, y)
end

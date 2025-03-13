-- http://github.com/dbmrq/dotfiles/

-- Requires you to keep holding Command + Q for a while before closing an app,
-- so you won't do it accidentally.
local M = {}
M.INITIAL_DELAY = 3

local alert_style = {
  strokeWidth     = 0,
  strokeColor     = { white = 0, alpha = 0 },
  fillColor       = { white = 0, alpha = 0 },
  textColor       = hs.drawing.color["red"],
  textFont        = ".AppleSystemUIFont",
  textSize        = 27,
  radius          = 0,
  atScreenEdge    = 0,
  fadeInDuration  = 0.15,
  fadeOutDuration = 0.15,
  padding         = -50,
}

local delay = M.INITIAL_DELAY
local killed_it = false
local timer
local alert

local function press_q()
  killed_it = false
  timer = hs.timer.doEvery(0.5, Tick)
  timer:fire()
end

local function hold_q()
  if delay <= 0 and not killed_it then
    killed_it = true
    timer:stop()
    hs.alert.closeSpecific(alert)
    hs.application.frontmostApplication():kill()
  end
end

local function release_q()
  killed_it = false
  timer:stop()
  delay = M.INITIAL_DELAY
  hs.alert.closeSpecific(alert)
end

function Tick()
  hs.alert.closeSpecific(alert)
  alert = hs.alert("Closing application in... " .. delay - 1, alert_style, nil, 1)
  delay = delay - 1
end

hs.hotkey.bind('cmd', 'Q', press_q, release_q, hold_q)

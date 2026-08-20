-- RingMenu (Classic Era 1.15.9) – Lua-only Options (NO XML)
-- Options included:
--   - Key Binding
--   - Close on Click
--   - First Slot
--   - Number of Slots
--   - Radius
--   - Angle
--   - Backdrop Scale
--   - Backdrop Color
--
-- NEW: Scroll/overflow support via UIPanelScrollFrameTemplate

local RingMenu_AddonName, RingMenu = ...

-- -------------------------
-- Backdrop helpers (safe)
-- -------------------------
local HAS_BACKDROP_TEMPLATE = (type(_G.BackdropTemplateMixin) == "table")
local function OptBackdropTemplate() return HAS_BACKDROP_TEMPLATE and "BackdropTemplate" or nil end

local function ApplyTooltipBackdrop(f, alpha)
  if f and f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, alpha or 0.5)
  end
end

-- -------------------------
-- Config helpers
-- -------------------------
local UI = {}
local RING_ID = 1

local function EnsureConfig()
  RingMenu_ringConfig = RingMenu_ringConfig or {}
  RingMenu_ringConfig[RING_ID] = RingMenu_ringConfig[RING_ID] or {}
  local cfg = RingMenu_ringConfig[RING_ID]

  if cfg.firstSlot == nil then cfg.firstSlot = 13 end
  if cfg.closeOnClick == nil then cfg.closeOnClick = true end
  if cfg.numSlots == nil then cfg.numSlots = 12 end
  if cfg.radius == nil then cfg.radius = 100 end
  if cfg.angle == nil then cfg.angle = 0 end
  if cfg.backdropScale == nil then cfg.backdropScale = 1.5 end
  if cfg.backdropColor == nil then
    cfg.backdropColor = { r = 0.0, g = 0.0, b = 0.0, a = 0.5 }
  else
    cfg.backdropColor.r = cfg.backdropColor.r or 0.0
    cfg.backdropColor.g = cfg.backdropColor.g or 0.0
    cfg.backdropColor.b = cfg.backdropColor.b or 0.0
    cfg.backdropColor.a = cfg.backdropColor.a or 0.5
  end

  return cfg
end

local function ApplyRingUpdate()
  if RingMenu_UpdateRing then
    RingMenu_UpdateRing(RING_ID)
  elseif RingMenu_UpdateAllRings then
    RingMenu_UpdateAllRings()
  end
end

-- -------------------------
-- Options integration helpers
-- -------------------------
local function AddOptionsCategory(panel, name)
  if _G.Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, name)
    Settings.RegisterAddOnCategory(category)
    panel.name = name
    RingMenu.optionsCategoryID = (category.GetID and category:GetID()) or name
    return category
  end

  panel.name = name
  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  elseif InterfaceOptionsFrame_AddCategory then
    InterfaceOptionsFrame_AddCategory(panel)
  end
  RingMenu.optionsCategoryID = name
  return panel
end

local function OpenOptionsTo(panel)
  if _G.Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(RingMenu.optionsCategoryID or panel.name or "RingMenu")
    return
  end
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

-- -------------------------
-- Binding helpers
-- -------------------------
local function ToggleButtonName()
  if RingMenu.ringFrame and RingMenu.ringFrame[RING_ID] and RingMenu.ringFrame[RING_ID].toggleButton then
    return RingMenu.ringFrame[RING_ID].toggleButton:GetName()
  end
  return "RingMenuToggleRing" .. tostring(RING_ID)
end

local function BindingCommand()
  return "CLICK " .. ToggleButtonName() .. ":LeftButton"
end

local function BindingKeys()
  local k1, k2 = GetBindingKey(BindingCommand())
  local t = {}
  if k1 then t[#t+1] = k1 end
  if k2 then t[#t+1] = k2 end
  return t
end

local function SaveBindingsSafe()
  if AttemptToSaveBindings and GetCurrentBindingSet then
    AttemptToSaveBindings(GetCurrentBindingSet())
  elseif SaveBindings and GetCurrentBindingSet then
    SaveBindings(GetCurrentBindingSet())
  end
end

local function DisplayBinding()
  local keys = BindingKeys()
  if #keys > 0 then
    return GetBindingText(keys[1])
  end
  return "(not bound)"
end

local function IsModifierKey(k)
  return k == "LSHIFT" or k == "RSHIFT" or k == "LCTRL" or k == "RCTRL" or k == "LALT" or k == "RALT"
end

local function WithModifiers(key)
  local prefix = ""
  if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
  if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
  if IsAltKeyDown() then prefix = prefix .. "ALT-" end
  return prefix .. key
end

local function NormalizeMouseButton(button)
  if button == "LeftButton" then return "BUTTON1" end
  if button == "RightButton" then return "BUTTON2" end
  if button == "MiddleButton" then return "BUTTON3" end
  local n = button:match("^Button(%d+)$")
  if n then return "BUTTON" .. n end
  return nil
end

local function ClearBindingForCommand()
  for _, key in ipairs(BindingKeys()) do
    SetBinding(key)
  end
end

local function ApplyBindingKey(key)
  local cfg = EnsureConfig()
  ClearBindingForCommand()

  if not key or key == "" then
    cfg.keyBind = nil
    SaveBindingsSafe()
    return
  end

  cfg.keyBind = key

  if SetBindingClick then
    SetBindingClick(key, ToggleButtonName(), "LeftButton")
  else
    SetBinding(key, BindingCommand())
  end

  SaveBindingsSafe()
end

-- -------------------------
-- UI helpers
-- -------------------------
local function MakeSlider(parent, labelText, helpText, minV, maxV, step, valueFormatter)
  local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetText(labelText)

  local help = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetText(helpText or "")
  help:SetJustifyH("LEFT")

  local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(step or 1)
  slider:SetObeyStepOnDrag(true)

  -- Hide built-in low/high/text regions from OptionsSliderTemplate
  if slider.Low then slider.Low:Hide() end
  if slider.High then slider.High:Hide() end
  if slider.Text then slider.Text:Hide() end

  local val = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")

  local function fmt(v)
    if valueFormatter then return valueFormatter(v) end
    return tostring(v)
  end

  return { label = label, help = help, slider = slider, val = val, fmt = fmt }
end

-- -------------------------
-- UI build
-- -------------------------
local function BuildPanel()
  local panel = CreateFrame("Frame", "RingMenuOptionsPanel", UIParent, OptBackdropTemplate())

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
  title:SetText("RingMenu")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Configure your RingMenu settings.")

  -- Scroll frame container (this is the "overflow" area)
  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 12)

  -- Content frame inside the scroll frame
  local content = CreateFrame("Frame", nil, scrollFrame, OptBackdropTemplate())
  scrollFrame:SetScrollChild(content)
  content:SetWidth(620) -- will be resized in OnSizeChanged
  content:SetHeight(900)

  -- Backdrop box inside content (so it scrolls nicely)
  local box = CreateFrame("Frame", nil, content, OptBackdropTemplate())
  ApplyTooltipBackdrop(box, 0.5)
  box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  box:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, 0)
  box:SetHeight(880)

  -- Keep content width in sync so controls size correctly
  scrollFrame:SetScript("OnSizeChanged", function(_, w)
    if not w then return end
    content:SetWidth(w)
    box:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, 0)
  end)

  -- Keybind
  local keyLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  keyLabel:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -12)
  keyLabel:SetText("Key Binding")

  local keyHelp = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  keyHelp:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -2)
  keyHelp:SetText("Click the button, then press a key (or mouse button). ESC clears.")

  local keyBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
  UI.keyBtn = keyBtn
  keyBtn:SetSize(280, 24)
  keyBtn:SetPoint("TOPLEFT", keyHelp, "BOTTOMLEFT", 0, -6)
  keyBtn:RegisterForClicks("AnyUp")
  keyBtn:EnableMouse(true)
  keyBtn:EnableMouseWheel(true)
  keyBtn:EnableKeyboard(false)
  keyBtn:SetPropagateKeyboardInput(true)

  local capturing = false
  local function StopCapture()
    capturing = false
    keyBtn:EnableKeyboard(false)
    keyBtn:SetPropagateKeyboardInput(true)
    keyBtn:SetText(DisplayBinding())
  end

  local function StartCapture()
    if InCombatLockdown and InCombatLockdown() then
      UIErrorsFrame:AddMessage("Cannot change bindings in combat.", 1, 0.2, 0.2)
      return
    end
    capturing = true
    keyBtn:SetText("Press a key…")
    keyBtn:EnableKeyboard(true)
    keyBtn:SetPropagateKeyboardInput(false)
  end

  keyBtn:SetScript("OnClick", StartCapture)
  keyBtn:SetScript("OnKeyDown", function(_, key)
    if not capturing or not key or key == "" then return end
    if key == "ESCAPE" then ApplyBindingKey(nil); StopCapture(); return end
    if IsModifierKey(key) then return end
    ApplyBindingKey(WithModifiers(key))
    StopCapture()
  end)
  keyBtn:SetScript("OnMouseDown", function(_, button)
    if not capturing or not button then return end
    if button == "LeftButton" or button == "RightButton" then return end
    local key = NormalizeMouseButton(button)
    if not key then return end
    ApplyBindingKey(WithModifiers(key))
    StopCapture()
  end)
  keyBtn:SetScript("OnMouseWheel", function(_, delta)
    if not capturing then return end
    ApplyBindingKey(WithModifiers(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    StopCapture()
  end)

  panel:SetScript("OnHide", function() if capturing then StopCapture() end end)

  -- Close on click
  local closeCB = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
  closeCB:SetPoint("TOPLEFT", keyBtn, "BOTTOMLEFT", -2, -14)
  closeCB:SetScript("OnClick", function(self)
    local cfg = EnsureConfig()
    cfg.closeOnClick = self:GetChecked() and true or false
    ApplyRingUpdate()
  end)
  local closeText = closeCB:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  closeText:SetPoint("LEFT", closeCB, "RIGHT", 2, 0)
  closeText:SetText("Close ring when a button is clicked")

  local anchor = closeCB
  local function placeSlider(s)
    s.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -16)
    s.help:SetPoint("TOPLEFT", s.label, "BOTTOMLEFT", 0, -2)
    s.help:SetPoint("RIGHT", box, "RIGHT", -12, 0)
    s.slider:SetPoint("TOPLEFT", s.help, "BOTTOMLEFT", 0, -10)
    s.val:SetPoint("LEFT", s.slider, "RIGHT", 10, 0)
    anchor = s.slider
  end

  local first = MakeSlider(box, "First Button Slot", "Action slot for the ring's first button.", 1, 180, 1)
  placeSlider(first)
  first.slider:SetScript("OnValueChanged", function(_, v)
    local cfg = EnsureConfig()
    v = math.floor(v + 0.5)
    cfg.firstSlot = v
    first.val:SetText(v)
    ApplyRingUpdate()
  end)

  local num = MakeSlider(box, "Number of Slots", "How many buttons are shown on the ring.", 1, 24, 1)
  placeSlider(num)
  num.slider:SetScript("OnValueChanged", function(_, v)
    local cfg = EnsureConfig()
    v = math.floor(v + 0.5)
    cfg.numSlots = v
    num.val:SetText(v)
    ApplyRingUpdate()
  end)

  local radius = MakeSlider(box, "Radius", "Distance from center to buttons.", 40, 220, 1)
  placeSlider(radius)
  radius.slider:SetScript("OnValueChanged", function(_, v)
    local cfg = EnsureConfig()
    v = math.floor(v + 0.5)
    cfg.radius = v
    radius.val:SetText(v)
    ApplyRingUpdate()
  end)

  local angle = MakeSlider(box, "Angle", "Rotation of the ring in degrees.", -180, 180, 1)
  placeSlider(angle)
  angle.slider:SetScript("OnValueChanged", function(_, v)
    local cfg = EnsureConfig()
    v = math.floor(v + 0.5)
    cfg.angle = v
    angle.val:SetText(v)
    ApplyRingUpdate()
  end)

  local scale = MakeSlider(box, "Backdrop Scale", "Scale of the ring backdrop.", 0.5, 3.0, 0.05, function(v) return string.format("%.2f", v) end)
  placeSlider(scale)
  scale.slider:SetScript("OnValueChanged", function(_, v)
    local cfg = EnsureConfig()
    cfg.backdropScale = v
    scale.val:SetText(string.format("%.2f", v))
    ApplyRingUpdate()
  end)

  -- Backdrop color
  local colorLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", scale.slider, "BOTTOMLEFT", 2, -18)
  colorLabel:SetText("Backdrop Color")

  local colorHelp = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  colorHelp:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -2)
  colorHelp:SetText("Color and transparency of the ring backdrop (default: black @ 50%).")

  local colorBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
  colorBtn:SetSize(120, 24)
  colorBtn:SetPoint("TOPLEFT", colorHelp, "BOTTOMLEFT", 0, -6)
  colorBtn:SetText("Pick…")

  local swatch = colorBtn:CreateTexture(nil, "ARTWORK")
  swatch:SetSize(16, 16)
  swatch:SetPoint("RIGHT", colorBtn, "RIGHT", -10, 0)
  swatch:SetTexture("Interface/ChatFrame/ChatFrameColorSwatch")

  local function UpdateSwatch()
    local cfg = EnsureConfig()
    local c = cfg.backdropColor or {}
    swatch:SetVertexColor(c.r or 0, c.g or 0, c.b or 0, 1)
  end

  local function OpenColorPicker()
    if InCombatLockdown and InCombatLockdown() then
      UIErrorsFrame:AddMessage("Cannot open color picker in combat.", 1, 0.2, 0.2)
      return
    end

    local cfg = EnsureConfig()
    local c = cfg.backdropColor
    local r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 0.5

    local function apply()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      local na = 1
      if OpacitySliderFrame and OpacitySliderFrame.GetValue then
        na = 1 - OpacitySliderFrame:GetValue()
      elseif ColorPickerFrame.GetColorAlpha then
        na = ColorPickerFrame:GetColorAlpha()
      end
      c.r, c.g, c.b, c.a = nr, ng, nb, na
      UpdateSwatch()
      ApplyRingUpdate()
    end

    local function cancel(prev)
      if type(prev) == "table" then
        c.r, c.g, c.b, c.a = prev.r, prev.g, prev.b, prev.a
        UpdateSwatch()
        ApplyRingUpdate()
      end
    end

    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - a
    ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
    ColorPickerFrame.func = apply
    ColorPickerFrame.opacityFunc = apply
    ColorPickerFrame.cancelFunc = cancel

    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Show()
  end

  colorBtn:SetScript("OnClick", OpenColorPicker)

  local function Refresh()
    local cfg = EnsureConfig()

    keyBtn:SetText(DisplayBinding())
    closeCB:SetChecked(cfg.closeOnClick and true or false)

    first.slider:SetValue(cfg.firstSlot); first.val:SetText(cfg.firstSlot)
    num.slider:SetValue(cfg.numSlots); num.val:SetText(cfg.numSlots)
    radius.slider:SetValue(cfg.radius); radius.val:SetText(cfg.radius)
    angle.slider:SetValue(cfg.angle); angle.val:SetText(cfg.angle)
    scale.slider:SetValue(cfg.backdropScale); scale.val:SetText(string.format("%.2f", cfg.backdropScale))

    UpdateSwatch()

    -- Resize content height to fit everything (simple, fixed)
    content:SetHeight(920)
    box:SetHeight(900)
  end

  panel:SetScript("OnShow", Refresh)
  panel.refresh = Refresh

  AddOptionsCategory(panel, "RingMenu")
  UI.panel = panel
end

function RingMenuOptions_SetupPanel()
  if UI.panel then return end
  EnsureConfig()
  BuildPanel()
end

-- Final safety net after login (don't swallow keys) + /ringmenu opens correctly
local safety = CreateFrame("Frame")
safety:RegisterEvent("PLAYER_LOGIN")
safety:SetScript("OnEvent", function()
  if UI.keyBtn then
    UI.keyBtn:EnableKeyboard(false)
    UI.keyBtn:SetPropagateKeyboardInput(true)
  end

  SLASH_RINGMENU1 = "/ringmenu"
  SlashCmdList.RINGMENU = function()
    if InCombatLockdown and InCombatLockdown() then
      UIErrorsFrame:AddMessage("Cannot open options in combat.", 1, 0.2, 0.2)
      return
    end
    if UI.panel then OpenOptionsTo(UI.panel) end
  end
end)

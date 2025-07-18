local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent.BaseClass)

local rainbowSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(1 / 3, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(2 / 3, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 0, 0)),
})

local ColorPicker = {}
ColorPicker.__index = ColorPicker
setmetatable(ColorPicker, BaseClass)

local hexInputSize = UI.compute(function()
	local fontSize = UI.Theme.FontSize()
	local padding = UI.Theme.Padding().Offset
	return UDim2.fromOffset(math.max(80, 3.5 * fontSize + padding), fontSize + padding)
end)

local hueSliderSize = UI.compute(function()
	local padding = UI.Theme.Padding().Offset
	local height = UI.Theme.FontSize() + padding
	return UDim2.new(0, height, 0, UI.Theme.FontSize() + hexInputSize().X.Offset + padding * 2)
end)

local svSize = UI.compute(function()
	local size = hexInputSize().X.Offset
	return UDim2.fromOffset(size, size)
end)

local inputColor = UI.compute(function()
	return if UI.getLuminance(UI.Theme.Primary()) > 0.5 then Color3.new() else Color3.new(1, 1, 1)
end)

local menuCornerRadius = UI.compute(function()
	return UDim.new(0, UI.Theme.CornerRadius().Offset + UI.Theme.Padding().Offset)
end)

function ColorPicker.new(definition)
	local new = UI.makeStatefulDefaults({
		Adornee = false,
		RightAlign = false,
		Visible = false,
		Value = Color3.new(1, 0, 0),
		Selected = Color3.new(1, 0, 0),
	}, definition)

	new.Selected._value = UI.raw(new.Value)

	local dragging = UI.state(false)

	local hue = 0
	local hueSlider = UI.new "Slider" {
		Name = "HueSlider",
		Vertical = true,
		Size = hueSliderSize,
		Value = function()
			local h, s, v = new.Value():ToHSV()
			if h == 1 and hue == 0 then
				h = 0
			end
			hue = if s > 0 and v > 0 then h else hue
			return hue
		end,

		UI.new "Frame" {
			Name = "Rainbow",
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},
			UI.new "Stroke" {},
			UI.new "UIGradient" {
				Color = rainbowSequence,
				Rotation = 90,
			},
		},

		[UI.Hook] = {
			Selected = function(value)
				local _, s, v = new.Value._value:ToHSV()
				local color = Color3.fromHSV(value, s, v)
				hue = value
				new.Selected(color, true)
				new.Value(color, true)
			end,
		},
	}

	local hueColor = UI.compute(function()
		return Color3.fromHSV(hueSlider.Value(), 1, 1)
	end)
	UI.edit(hueSlider._slider, {
		BackgroundColor3 = hueColor,
		UI.new "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 1.5,
		},
	})
	hueSlider._instance:FindFirstChild("Filled"):Destroy()

	local hexInput = UI.new "Input" {
		Font = UI.Theme.FontMono,
		BackgroundColor3 = inputColor,
		TextColor3 = inputColor,
		Size = hexInputSize,
		Padding = UDim.new(0, 5),
		Validate = function(value)
			return pcall(Color3.fromHex, value)
		end,
		Value = function()
			return `#{new.Value():ToHex()}`
		end,

		[UI.Hook] = {
			Selected = function(value)
				local color = Color3.fromHex(value)
				new.Selected(color, true)
				new.Value(color, true)
			end,
		},
	}

	local sv, dragInput
	local sX = UI.state(0)
	local function update(input)
		if not dragInput then
			return
		end

		local x = math.clamp((input.Position.X - sv.AbsolutePosition.X - 8) / (sv.AbsoluteSize.X - 16), 0, 1)
		local y = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y - 8) / (sv.AbsoluteSize.Y - 16), 0, 1)
		sX(x, true)

		local color = Color3.fromHSV(hue, x, y)
		new.Selected(color, true)
		new.Value(color, true)
	end

	local function inputBegan(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UI.Sound.Hover03:Play()
			dragInput = input
			dragging(true)
			local con
			con = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					con:Disconnect()
					if dragInput == input then
						UI.Sound.Hover01:Play()
						dragInput = nil
						dragging(false)
					end
				end
			end)
			update(input)
		end
	end

	UserInputService.InputChanged:Connect(update)

	sv = UI.new "Frame" {
		Name = "SaturationValue",
		BackgroundColor3 = hueColor,
		Size = svSize,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "Stroke" {},
		UI.new "Frame" {
			Name = "Saturation",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 1, 0),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIGradient" {
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new(0, 1),
			},
		},
		UI.new "Frame" {
			Name = "Value",
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 2,

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},
			UI.new "UIGradient" {
				Color = ColorSequence.new(Color3.new()),
				Transparency = NumberSequence.new(0, 1),
				Rotation = -90,
			},
		},
		UI.new "Frame" {
			Name = "PickerContainer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 3,

			UI.new "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			UI.new "Frame" {
				Name = "Picker",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = new.Value,
				Size = UI.tween(function()
					return if dragging() then UDim2.new(0, 16, 0, 16) else UDim2.new(0, 8, 0, 8)
				end, UI.Theme.TweenOut),
				Position = UI.tween(function()
					local _, s, v = new.Value():ToHSV()
					local x = sX()
					return UDim2.new(if v == 0 then x else s, 0, 1 - v, 0)
				end, UI.Theme.TweenOut),

				UI.new "UICorner" {
					CornerRadius = UI.Theme.CornerDiameter,
				},
				UI.new "UIStroke" {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.new(1, 1, 1),
					Thickness = 1.5,
				},

				InputBegan = inputBegan,
			},
		},

		InputBegan = inputBegan,
	}

	new._menu = UI.new "Menu" {
		Name = "ColorPicker",
		Adornee = new.Adornee,
		RightAlign = new.RightAlign,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Visible = new.Visible,

		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},

		hueSlider,
		UI.new "Frame" {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UI.Theme.Padding,
			},

			sv,
			hexInput,
		},
	}
	new._menu._list.FillDirection = Enum.FillDirection.Horizontal
	new._menu._content.AutomaticSize = Enum.AutomaticSize.XY
	UI.edit(new._menu._list, { Padding = UI.Theme.Padding })
	new._instance = new._menu._instance
	UI.edit(new._instance.UICorner, { CornerRadius = menuCornerRadius })

	return setmetatable(new, ColorPicker)
end

return ColorPicker

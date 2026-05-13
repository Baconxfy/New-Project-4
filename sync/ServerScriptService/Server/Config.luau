local Config = {
	Base = require(script.Base),
	Brainrots = require(script.Brainrots),
	LuckPool = require(script.LuckPool),
	Luckyblocks = require(script.Luckyblocks),
	Mutations = require(script.Mutations),
	Pads = require(script.Pads),

	Conveyor = {
		Speed = 80,
	},

	Brainrot = {
		DefaultMoneyPerSecond = 1,
		CollectJumpHeight = 1.25,
		CollectJumpUpTime = 0.14,
		CollectJumpDownTime = 0.22,
	},

	RateLimits = {
		-- Fallback if no more-specific rule matches
		-- burst = bucket capacity, refill = tokens added per 'every' seconds (default every=1s)
		Default = { burst = 20, refill = 10, every = 1 },

		-- Service rules (client -> server).
		-- Matches in this order:
		--   "<Service>/Client/<Method>"
		--   "<Service>/Client/*"
		--   "<Service>/*"
		--   "*"
		Service = {
			["*"] = { burst = 100, refill = 100 }, -- global catch-all

			-- ["SomeService/*"] = { burst = 50, refill = 25 },
			-- ["SomeService/Client/*"] = { burst = 40, refill = 20 },
		},
	},

	Shared = {

		DataVersion = "BrainrotTycoon-v1",
		DataVersionStudio = "BrainrotTycoon-v1-studio",
		LeaderstatsCategories = {
			"Cash",
		},
		ProfileTemplate = {
			Cash = 0,
			PadsUnlocked = 1,
			BaseStage = 1,
		},
		ControllerCallTimeout = 4.0,

		Inventory = {
			ItemTypeAttribute = "ItemType",
			DefaultEquipOffset = CFrame.new(0, -0.75, -1) * CFrame.Angles(0, math.rad(90), 0),
			BrainrotHold = {
				HoldOffset = Vector3.new(0, -0.15, -0.65),
				HoldRotation = Vector3.new(0, 0, 0),
				HoldOffsetAttributes = {
					X = "BrainrotHoldOffsetX",
					Y = "BrainrotHoldOffsetY",
					Z = "BrainrotHoldOffsetZ",
				},
				HoldRotationAttributes = {
					X = "BrainrotHoldRotationX",
					Y = "BrainrotHoldRotationY",
					Z = "BrainrotHoldRotationZ",
				},
			},
			LuckyblockHold = {
				AnimationNames = {
					"HoldingLuckyblock",
					"LuckyblockHolding",
					"LuckyblockHold",
					"HoldLuckyblock",
				},
				AnimationIdAttribute = "HoldAnimationId",
				HoldPadding = 0.65,
				HoldOffsetY = -0.2,
				HoldOffsetAttributes = {
					X = "HoldOffsetX",
					Y = "HoldOffsetY",
					Padding = "HoldPadding",
				},
				HoldRotationAttributes = {
					X = "HoldRotationX",
					Y = "HoldRotationY",
					Z = "HoldRotationZ",
				},
			},
		},

		Pads = {
			EnabledAttribute = "PadEnabled",
			IndexAttribute = "PadIndex",
		},

		Button = {
			Enabled = true,
			HoverEnabled = true,
			PressEnabled = true,
			HoverScale = 1.06,
			PressScale = 0.94,
			HoverTime = 0.12,
			PressDownTime = 0.07,
			PressUpTime = 0.10,
			ClickSlopPx = 6,
			HoverEasingStyle = Enum.EasingStyle.Quint,
			HoverEasingDirection = Enum.EasingDirection.Out,
			PressDownEasingStyle = Enum.EasingStyle.Quint,
			PressDownEasingDirection = Enum.EasingDirection.Out,
			PressUpEasingStyle = Enum.EasingStyle.Back,
			PressUpEasingDirection = Enum.EasingDirection.Out,
		},

		Microwave = {
			PromptName = "MicrowavePrompt",
			SetPowerGuiName = "SetPower",
			StopMicrowaveGuiName = "StopMicrowave",
			Minigame = {
				CookTime = 5,
				StopReadyPadding = 0.25,
				PerfectThreshold = 0.91,
				OkayThreshold = 0.68,
				SetPowerSpeed = 1.4,
				StopMicrowaveSpeed = 1.7,
				ClickTimingEdgeSpeedScale = 0.38,
				ClickTimingCenterSpeedScale = 1.85,
				PopupTime = 0.65,
			},
			Client = {
				RevealTime = 1.85,
				RollTime = 2.35,
				CameraTweenTime = 0.55,
				UiHandoffDelay = 0.15,
				StartCameraOffset = Vector3.new(0, 1.6, 4.5),
				CookCameraOffset = Vector3.new(0, 1.25, 3.35),
				RevealCameraOffset = Vector3.new(0, 1.08, 2.85),
				FocusOffset = Vector3.new(0, 0.75, 0),
				CookColor = Color3.fromRGB(255, 158, 60),
				HotColor = Color3.fromRGB(255, 65, 25),
				RevealColor = Color3.fromRGB(255, 245, 150),
				TrayNames = {
					"MicrowaveTray",
					"Turntable",
					"Tray",
					"Plate",
				},
			},
			Roll = {
				BaseLuck = 0,
				TierLuckJump = 25,
				InTierLuckBonus = 20,
				PowerLuckBonus = 25,
				PreviewCount = 18,
				RarityOrder = {
					Common = 1,
					Rare = 2,
					Epic = 3,
					Legendary = 4,
					Mythic = 5,
					Godly = 6,
					Secret = 7,
					Divine = 8,
					Celestine = 9,
					Forbidden = 10,
				},
				RarityColors = {
					Common = Color3.fromRGB(235, 235, 235),
					Rare = Color3.fromRGB(75, 155, 255),
					Epic = Color3.fromRGB(185, 95, 255),
					Legendary = Color3.fromRGB(255, 185, 65),
					Mythic = Color3.fromRGB(255, 70, 95),
					Godly = Color3.fromRGB(255, 245, 95),
					Secret = Color3.fromRGB(80, 255, 230),
					Divine = Color3.fromRGB(255, 255, 255),
					Celestine = Color3.fromRGB(105, 170, 255),
					Forbidden = Color3.fromRGB(255, 45, 45),
				},
			},
		},

		Mutations = require(script.Mutations),

	},

	Microwave = {
		ModelName = "Microwave",
		SessionBlockFolderName = "InsertedLuckyblock",
		ResultFolderName = "MicrowaveResult",
		LuckyblockSlotName = "LuckyblockSlot",
		InteractDistancePadding = 6,
		DefaultRewardName = "Noobini Pizzanini",
	},
}

return Config

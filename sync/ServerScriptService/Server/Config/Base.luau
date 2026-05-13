local Base = {
	StageDataKey = "BaseStage",
	DefaultStage = 1,

	Stages = {
		[1] = {
			Name = "Stage 1",
			TemplateName = "Stage 1",
			Pads = 8,
		},
		[2] = {
			Name = "Stage 2",
			TemplateName = "Stage 2",
			Pads = 16,
		},
	},
}

return Base

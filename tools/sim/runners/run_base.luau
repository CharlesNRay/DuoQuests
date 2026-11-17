local m = {
	Hooks = require("./Combat/Hooks"), Entity = require("./Combat/Entity"), Rng = require("./Combat/Rng"),
	Simulation = require("./Combat/Simulation"), StatCalc = require("./Combat/StatCalc"),
	Abilities = require("./Config/Abilities"), Statuses = require("./Config/Statuses"), Classes = require("./Config/Classes"),
	Rarities = require("./Config/Rarities"), Skills = require("./Skills"), ProfileTemplate = require("./ProfileTemplate"),
	TableUtil = require("./Util/TableUtil"), Stages = require("./Stages"), Progression = require("./Progression"),
	Economy = require("./Economy"), StageRunner = require("./StageRunner"), EconomyConfig = require("./Config/Economy"), StagesConfig = require("./Config/Stages"),
	BalanceTool = require("./BalanceTool"), Wishing = require("./Wishing"), SkillProgress = require("./SkillProgress"), PartyCore = require("./PartyCore"), Party = require("./Party"), Offline = require("./Offline"), OfflineConfig = require("./Config/Offline"),
}
require("./ProfileTests")(m) require("./CombatTests")(m) require("./AbilityTests")(m) require("./StageTests")(m)
require("./PartyTests")(m)
require("./PacingTests")(m)
require("./PartyCoreTests")(m)

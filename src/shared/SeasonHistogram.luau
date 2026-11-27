--[[
	SeasonHistogram (ModuleScript)
	Location: ReplicatedStorage > Shared > SeasonHistogram

	Counting players per stage for the season's Top 10%..100% brackets (SeasonResultsService keeps the shared histogram
	in a DataStore). Each PLAYER must count once, whichever server they are on and however many characters they have,
	so the score a player is counted at lives in their save: Permanent.SeasonHist = { Season = id, Score = n }.

	A server keeps, per season:
	  pending  = { [score] = change }               moves not written to the shared histogram yet
	  inflight = { [userId] = { Profile, Score } }   whose moves those are (the save is updated only once written)

	  SeasonHistogram.Counted(profile, seasonId, userId, inflight) -> score | nil
	  SeasonHistogram.Move(pending, inflight, profile, seasonId, userId, score, minStage) -> true when it changed pending
	  SeasonHistogram.Commit(inflight, seasonId)     -- the write worked: remember each move in the player's save
]]

local SeasonHistogram = {}

function SeasonHistogram.Counted(profile, seasonId, userId, inflight)
	local moving = inflight[userId]
	if moving then
		return moving.Score
	end
	local h = profile.Permanent.SeasonHist
	if type(h) == "table" and h.Season == seasonId then
		return h.Score
	end
	return nil
end

function SeasonHistogram.Move(pending, inflight, profile, seasonId, userId, score, minStage)
	if score < minStage then
		return false
	end
	local counted = SeasonHistogram.Counted(profile, seasonId, userId, inflight)
	if counted ~= nil and counted >= score then
		return false
	end
	if counted ~= nil then
		pending[counted] = (pending[counted] or 0) - 1
	end
	pending[score] = (pending[score] or 0) + 1
	inflight[userId] = { Profile = profile, Score = score }
	return true
end

function SeasonHistogram.Commit(inflight, seasonId)
	for userId, moving in pairs(inflight) do
		moving.Profile.Permanent.SeasonHist = { Season = seasonId, Score = moving.Score }
		inflight[userId] = nil
	end
end

return SeasonHistogram

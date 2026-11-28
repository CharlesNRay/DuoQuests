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
	  SeasonHistogram.Commit(inflight, seasonId, isLive?, pending?)
	      the write worked: remember each move in the player's save. isLive(userId, profile) -> false when that save is
	      gone already (the player left during the write: their last save kept the old score), then the player's moves
	      are undone in `pending` instead, so the shared histogram matches what their save says (2026-11-28: a commit
	      lost this way counted the player again on their next join, and the histogram grew every session)
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
	-- Saved: the score the player's save holds (kept across moves made before a commit), to undo them all if needed
	local saved = if inflight[userId] then inflight[userId].Saved else counted
	inflight[userId] = { Profile = profile, Score = score, Saved = saved }
	return true
end

function SeasonHistogram.Commit(inflight, seasonId, isLive, pending)
	for userId, moving in pairs(inflight) do
		if isLive == nil or isLive(userId, moving.Profile) then
			moving.Profile.Permanent.SeasonHist = { Season = seasonId, Score = moving.Score }
		elseif pending then
			pending[moving.Score] = (pending[moving.Score] or 0) - 1
			if moving.Saved ~= nil then
				pending[moving.Saved] = (pending[moving.Saved] or 0) + 1
			end
		end
		inflight[userId] = nil
	end
end

return SeasonHistogram

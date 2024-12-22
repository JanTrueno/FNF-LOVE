local bgMusic
local cutsceneTimer
local isVideo = ClientPrefs.data.lowQuality
local cutscene

function create()
	if isVideo then return end
	local dadX, dadY = state.stage.dadPos.x, state.stage.dadPos.y
	if state.dad then
		dadX, dadY, state.dad.alpha = state.dad.x, state.dad.y, 0
	end
	state.camHUD.visible, state.camNotes.visible = false, false

	tankman = Sprite(dadX + 100, dadY)
	tankman:setFrames(paths.getSparrowAtlas('stages/tank/cutscenes/'
		.. paths.formatToSongPath(PlayState.SONG.song)))
	tankman:addAnimByPrefix('wellWell', 'TANK TALK 1 P1', 24, false)
	tankman:addAnimByPrefix('killYou', 'TANK TALK 1 P2', 24, false)
	tankman:play('wellWell', true)
	if state.dad then
		state:insert(state:indexOf(state.dad) + 1, tankman)
	else
		state:add(tankman)
	end

	state.camFollow:set(dadX + 380, dadY + 170)
end

function postCreate()
	if isVideo then
		cutscene = Video(0, 0, "ughCutscene", true, true)
		cutscene:setScrollFactor()
		cutscene.cameras = {state.camOther}
		cutscene:play()
		state:add(cutscene)
		cutscene.onComplete = function()
			close()
		end
		return
	end
	bgMusic = Sound():load(paths.getMusic('gameplay/DISTORTO'), 0.5, true, true)
	bgMusic:play()
	game.camera.zoom = game.camera.zoom * 1.2

	Timer(timer):start(0.1, function()
		game.sound.play(paths.getSound('gameplay/wellWellWell'), ClientPrefs.data.vocalVolume / 100)
	end)

	Timer(timer):start(3, function()
		state.camFollow.x = state.camFollow.x + 650
		state.camFollow.y = state.camFollow.y + 100
	end)

	Timer(timer):start(4.5, function()
		if state.boyfriend then
			state.boyfriend:playAnim('singUP', true)
		end
		game.sound.play(paths.getSound('gameplay/bfBeep'), ClientPrefs.data.vocalVolume / 100)
	end)

	Timer(timer):start(5.2, function()
		if state.boyfriend then
			state.boyfriend:playAnim('idle', true)
		end
	end)

	Timer(timer):start(6, function()
		state.camFollow.x = state.camFollow.x - 650
		state.camFollow.y = state.camFollow.y - 100

		tankman:play('killYou', true)
		tankman.x = tankman.x - 36
		tankman.y = tankman.y - 10
		game.sound.play(paths.getSound('gameplay/killYou'), ClientPrefs.data.vocalVolume / 100)
	end)

	Timer(timer):start(12, function()
		tankman:destroy()
		if state.dad then
			state.dad.alpha = 1
		end
		state.camHUD.visible, state.camNotes.visible = true, true

		local times = PlayState.conductor.crotchet / 1000 * 4.5
		state.tween:tween(game.camera, {zoom = state.stage.camZoom}, times, {ease = 'quadInOut'})
		close()
	end)
end

function songStart()
	if not isVideo then
		bgMusic:stop()
		close()
	end
end

function pause() if isVideo then cutscene:pause() end end

function substateClosed() if isVideo then cutscene:play() end end

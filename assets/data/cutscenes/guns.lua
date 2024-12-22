local bgMusic

function create()
	local dadX, dadY = state.stage.dadPos.x, state.stage.dadPos.y
	if state.dad then
		dadX, dadY, state.dad.alpha = state.dad.x, state.dad.y, 0
	end
	state.camHUD.visible, state.camNotes.visible = false, false

	tankman = Sprite(dadY + 100, dadY)
	tankman:setFrames(paths.getSparrowAtlas('stages/tank/cutscenes/'
		.. paths.formatToSongPath(PlayState.SONG.song)))
	tankman:addAnimByPrefix('tightBars', 'TANK TALK 2', 24, false)
	tankman:play('tightBars', true)
	if state.dad then
		state:insert(state:indexOf(state.dad) + 1, tankman)
	else
		state:add(tankman)
	end

	state.camFollow:set(dadY + 380, dadY + 170)
end

function postCreate()
	bgMusic = game.sound.load(paths.getMusic('gameplay/DISTORTO'), 0.5, true)
	bgMusic:play()

	game.sound.play(paths.getSound('gameplay/tankSong2'), ClientPrefs.data.vocalVolume / 100)
	tween:tween(game.camera, {zoom = state.stage.camZoom * 1.2}, 4, {ease = Ease.quadInOut})

	Timer(timer):start(4, function()
		tween:tween(game.camera, {zoom = state.stage.camZoom * 1.2 * 1.2}, 0.5, {ease = Ease.quadInOut})
		if state.gf then
			state.gf:playAnim('sad', true)
		end
	end)

	Timer(timer):start(4.5, function()
		tween:tween(game.camera, {zoom = state.stage.camZoom * 1.2}, 1, {ease = Ease.quadInOut})
	end)

	Timer(timer):start(11.5, function()
		tankman:destroy()
		if state.dad then
			state.dad.alpha = 1
		end
		state.camHUD.visible, state.camNotes.visible = true, true

		tween:tween(game.camera, {zoom = state.stage.camZoom},
			PlayState.conductor.crotchet / 1000 * 4.5, {ease = Ease.quadInOut})
		state:startCountdown()
	end)
end

function songStart()
	bgMusic:stop()
	close()
end

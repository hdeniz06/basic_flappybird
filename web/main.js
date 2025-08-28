/* Flippy Bird - Web (Canvas) */
(() => {
	'use strict';

	/** @type {HTMLCanvasElement} */
	const canvas = document.getElementById('game');
	const ctx = canvas.getContext('2d');

	const W = canvas.width;
	const H = canvas.height;
	const FLOOR_Y = 80;

	const levels = [
		{ name: 'Seviye 1', pipeSpeed: -140, spawnInterval: 1800, gap: 180, pipeWidth: 60, gravity: -0.38, flapV: 6.5 },
		{ name: 'Seviye 2', pipeSpeed: -170, spawnInterval: 1600, gap: 165, pipeWidth: 60, gravity: -0.40, flapV: 6.6 },
		{ name: 'Seviye 3', pipeSpeed: -200, spawnInterval: 1500, gap: 150, pipeWidth: 58, gravity: -0.42, flapV: 6.7 },
		{ name: 'Seviye 4', pipeSpeed: -230, spawnInterval: 1350, gap: 135, pipeWidth: 56, gravity: -0.44, flapV: 6.9 },
		{ name: 'Seviye 5', pipeSpeed: -260, spawnInterval: 1200, gap: 120, pipeWidth: 54, gravity: -0.46, flapV: 7.1 },
	];

	let levelIndex = 0;
	let lastSpawn = 0;
	let pipes = [];
	let score = 0;
	let started = false;
	let gameOver = false;

	const bird = {
		x: W * 0.35,
		y: H * 0.6,
		r: 14,
		vy: 0,
		color: '#ffdf40',
	};

	function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
	function circleRectCollide(cx, cy, cr, rx, ry, rw, rh) {
		const nearestX = clamp(cx, rx, rx + rw);
		const nearestY = clamp(cy, ry, ry + rh);
		const dx = cx - nearestX;
		const dy = cy - nearestY;
		return (dx*dx + dy*dy) <= cr*cr;
	}

	function roundRect(x, y, w, h, r) {
		r = Math.min(r, h/2, w/2);
		ctx.beginPath();
		ctx.moveTo(x + r, y);
		ctx.arcTo(x + w, y, x + w, y + h, r);
		ctx.arcTo(x + w, y + h, x, y + h, r);
		ctx.arcTo(x, y + h, x, y, r);
		ctx.arcTo(x, y, x + w, y, r);
		ctx.closePath();
	}

	function resetToMenu() {
		pipes = [];
		score = 0;
		started = false;
		gameOver = false;
		levelIndex = 0; // daima Seviye 1'e dön
		bird.x = W * 0.35;
		bird.y = H * 0.6;
		bird.vy = 0;
		lastSpawn = 0;
	}

	function startGame(i) {
		levelIndex = Math.max(0, Math.min(levels.length - 1, i|0));
		resetToMenu();
		started = true;
	}

	function flap() {
		if (!started || gameOver) return;
		bird.vy = levels[levelIndex].flapV;
	}

	function spawnPipePair() {
		const L = levels[levelIndex];
		const centerY = Math.random() * (H - 240) + 120;
		const gap = L.gap;
		const w = L.pipeWidth;
		const topH = Math.max(40, H - centerY - gap / 2);
		const bottomH = Math.max(40, centerY - gap / 2 - FLOOR_Y);
		const x = W + w;
		pipes.push({ x, w, topH, bottomH, passed: false });
	}

	function update(dt) {
		const L = levels[levelIndex];
		if (started && !gameOver) {
			// Gravity
			bird.vy += L.gravity;
			bird.y += bird.vy;

			// Bounds
			if (bird.y - bird.r < FLOOR_Y) {
				bird.y = FLOOR_Y + bird.r;
				gameOver = true;
			}
			if (bird.y + bird.r > H) {
				bird.y = H - bird.r;
				gameOver = true;
			}

			// Pipes
			for (const p of pipes) {
				p.x += (L.pipeSpeed) * dt;
				// Score when fully passed
				if (!p.passed && p.x + p.w/2 < bird.x - bird.r) {
					p.passed = true;
					score += 1;
					// Auto level-up every 10 points up to level 5
					const targetLevel = Math.min(levels.length - 1, Math.floor(score / 10));
					if (targetLevel > levelIndex) {
						levelIndex = targetLevel;
						// optional: reset spawn timer burst
						lastSpawn = 0;
					}
				}
				// Collision with precise circle-rect
				const rx = p.x - p.w/2;
				// top pipe rect in physics
				const topRect = { x: rx, y: H - p.topH, w: p.w, h: p.topH };
				// bottom pipe rect in physics
				const bottomRect = { x: rx, y: FLOOR_Y, w: p.w, h: p.bottomH };
				if (circleRectCollide(bird.x, bird.y, bird.r, topRect.x, topRect.y, topRect.w, topRect.h) ||
					circleRectCollide(bird.x, bird.y, bird.r, bottomRect.x, bottomRect.y, bottomRect.w, bottomRect.h)) {
					gameOver = true;
				}
			}
			// Remove offscreen pipes
			pipes = pipes.filter(p => p.x + p.w/2 > -10);

			// Spawn timing
			lastSpawn += dt * 1000;
			if (lastSpawn >= L.spawnInterval) {
				spawnPipePair();
				lastSpawn = 0;
			}
		}
	}

	function draw() {
		// Sky
		ctx.fillStyle = '#8ec5ff';
		ctx.fillRect(0, 0, W, H);

		// Ground (physics: 0..FLOOR_Y) => canvas: y = H - FLOOR_Y
		ctx.fillStyle = '#55c462';
		ctx.fillRect(0, H - FLOOR_Y, W, FLOOR_Y);

		// Pipes (physics -> canvas)
		// Top pipe occupies physics [H - topH, H] => canvas y = 0, height = topH
		// Bottom pipe occupies physics [FLOOR_Y, FLOOR_Y + bottomH] => canvas y = H - (FLOOR_Y + bottomH)
		ctx.fillStyle = '#51cc5c';
		for (const p of pipes) {
			const x = Math.round(p.x - p.w/2);
			// top
			ctx.fillRect(x, 0, p.w, p.topH);
			// bottom
			ctx.fillRect(x, H - (FLOOR_Y + p.bottomH), p.w, p.bottomH);
		}

		// Bird
		ctx.fillStyle = bird.color;
		ctx.beginPath();
		ctx.arc(bird.x, H - bird.y, bird.r, 0, Math.PI*2);
		ctx.fill();

		// UI
		ctx.fillStyle = '#fff';
		ctx.font = 'bold 20px system-ui, -apple-system, Segoe UI, Roboto, Arial';
		ctx.textAlign = 'left';
		ctx.textBaseline = 'alphabetic';
		ctx.fillText(`Skor: ${score}`, 12, 26);

		// level pill (top-right) — sadece oyun başladıysa
		if (started) {
			const lvl = levels[levelIndex].name; // e.g., "Seviye 3"
			ctx.font = '600 14px system-ui, -apple-system, Segoe UI, Roboto, Arial';
			const metrics = ctx.measureText(lvl);
			const padX = 12, padY = 8;
			const h = 28;
			const w = Math.ceil(metrics.width) + padX * 2;
			const x = W - w - 12;
			const y = 10;
			ctx.globalAlpha = 0.35;
			ctx.fillStyle = '#000';
			roundRect(x, y, w, h, 12);
			ctx.fill();
			ctx.globalAlpha = 1;
			ctx.strokeStyle = '#ffffff66';
			ctx.lineWidth = 1;
			roundRect(x, y, w, h, 12);
			ctx.stroke();
			ctx.fillStyle = '#fff';
			ctx.textAlign = 'center';
			ctx.textBaseline = 'middle';
			ctx.fillText(lvl, x + w/2, y + h/2);
		}

		// Start/game-over texts
		ctx.textAlign = 'center';
		ctx.textBaseline = 'alphabetic';
		ctx.font = 'bold 20px system-ui, -apple-system, Segoe UI, Roboto, Arial';
		if (!started) {
			ctx.fillText('Oyuna Başla', W/2, H*0.35);
			ctx.fillText('Tıkla ya da Space', W/2, H*0.35 + 28);
		} else if (gameOver) {
			ctx.fillText('Oyun Bitti! Yeniden başlamak için tıklayın', W/2, H*0.35);
		}
	}

	let lastTs = performance.now();
	function loop(ts) {
		const dt = Math.min(0.05, (ts - lastTs) / 1000);
		lastTs = ts;
		update(dt);
		draw();
		requestAnimationFrame(loop);
	}
	requestAnimationFrame(loop);

	// Input
	canvas.addEventListener('mousedown', e => {
		if (!started) { startGame(0); return; }
		if (gameOver) { resetToMenu(); return; }
		flap();
	});
	window.addEventListener('keydown', e => {
		if (e.code === 'Space') {
			if (!started) { startGame(0); return; }
			if (gameOver) { resetToMenu(); return; }
			flap();
		}
	});
	canvas.addEventListener('click', e => {
		if (!started) { startGame(0); return; }
		if (gameOver) { resetToMenu(); return; }
	});
	document.getElementById('reset').addEventListener('click', () => {
		resetToMenu();
	});
})(); 
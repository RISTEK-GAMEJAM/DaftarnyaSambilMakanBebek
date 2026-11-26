extends Node

signal language_changed(lang_code: String)

var current: String = "id" # "id" (IND) or "en" (EN)

const STRINGS := {
	"id": {
		# Main Menu
		"menu_play": "MULAI MAIN",
		"menu_tutorial": "CARA MAIN",
		"menu_quit": "KELUAR",
		"lang_tooltip": "Ganti Bahasa (IND / EN)",

		# Tutorial Overlay
		"tut_title": "CARA MAIN — TWIN-LABYRINTH",
		"tut_c1_title": "1. DADU & GERAK KEMBAR",
		"tut_c1_body": "• Tiap giliran lempar 2 dadu (Space), lalu bagi 1 dadu ke Labirin A dan 1 ke Labirin B.\n• Klik tombol panah di bawah (Tab) jika ingin menukar jatah dadu kedua labirin.\n• Klik petak lantai untuk memilih rute kedua Elf (klik kanan = undo), lalu tekan 'Jalan!'.\n• Setelah Elf jalan, Snatcher ikut mengejar sesuai nilai & selisih dadu!",
		"tut_c2_title": "2. PETAK PENTING DI LABIRIN",
		"tut_exit_title": "Gerbang Keluar (Exit Gate)",
		"tut_exit_desc": "Tujuan akhir! Bawa kedua Elf masuk ke sini untuk menang.",
		"tut_safe_title": "Safe Spot (Rune Bulan)",
		"tut_safe_desc": "Petak aman! Snatcher tidak bisa menangkap Elf di sini.",
		"tut_lair_title": "Sarang Snatcher (Bahaya!)",
		"tut_lair_desc": "Jika Elf kalah Duel & terseret sampai sini → GAME OVER!",
		"tut_c3_title": "3. DUEL GAME 24",
		"tut_c3_body": "• Jika Snatcher & Elf di 1 petak yang sama (di luar Safe Spot), ekor Snatcher akan melilit Elf!\n• Kamu mendapat 4 kartu (A=1 s.d. 10) yang DIJAMIN punya solusi tepat 24.\n• Klik Kartu 1 → Operator (+ - × :) → Kartu 2 hingga tersisa 1 kartu bernilai 24 sebelum waktu habis (25 dtk).",
		"tut_c4_title": "4. MENANG & GAME OVER",
		"tut_c4_body": "• MENANG 24: Elf lepas dari ekor, maju ke Exit (4 petak jika cepat, 2 biasa) & Snatcher stun.\n• KALAH / HABIS WAKTU: Elf tetap kebawa ekor & diseret mundur ke Sarang, lalu Duel lagi tiap giliran sampai menang.\n• MENANG GAME: Kedua Elf masuk Exit Gate.\n• GAME OVER: Salah satu Elf terseret sampai Sarang Snatcher!",
		"tut_close": "MENGERTI - TUTUP",

		# Board & HUD
		"lane_a": "Labirin A",
		"lane_b": "Labirin B",
		"btn_roll": "Lempar Dadu",
		"btn_confirm": "Jalan!",
		"btn_start_duel": "Mulai Duel!",
		"btn_swap_elves": "Tukar Elf",
		"btn_play_again": "Main Lagi",
		"btn_tutorial_tip": "Cara Main (Tutorial)",
		"btn_menu": "Menu",
		"btn_swap_dice_tip": "Tukar Dadu Labirin A & B (Tab)",
		"dice_title_a": "DADU LABIRIN A",
		"dice_title_b": "DADU LABIRIN B",

		# HUD Status
		"hud_roll_banner": "%s  |  Tekan Lempar Dadu",
		"hud_roll_first": "Fase Lempar Dadu  •  Klik 'Tukar Elf' jika ingin ganti posisi",
		"hud_roll_next": "Fase Lempar Dadu  •  Tekan 'Lempar Dadu' (Space)",
		"hud_move_captured": "Elf masih terikat Snatcher — tekan 'Mulai Duel!' untuk main Game 24!",
		"hud_move_pick": "Pilih rute kedua Elf di papan  •  Klik panah di bawah untuk tukar dadu",
		"hud_duel": "DUEL GAME 24 di %s! Capai tepat 24 untuk lepas dari ekor Snatcher!",
		"hud_won": "MENANG! Kedua Elf berhasil lolos dari Twin-Labyrinth!",
		"hud_lost": "GAME OVER! Elf di %s terseret sampai Sarang Snatcher!",

		# Panel status & Dice tray echo
		"status_escaped": "LOLOS!",
		"status_captured": "TERTANGKAP!",
		"status_ready": "Siap! (%d/%d)",
		"status_steps": "Langkah: %d/%d",
		"status_stun": "Snatcher Stun (%d)",
		"status_tiles": "%d petak",
		"tray_escaped": "Elf %s sudah lolos ke Exit Gate!",
		"tray_captured": "Elf %s terikat ekor — Duel Game 24!",
		"tray_stun": "Snatcher %s Stun (%d giliran)",
		"tray_wait_roll": "Tekan 'Lempar Dadu' untuk mulai giliran",
		"tray_move_info": "Jalan %d petak  •  %s",
		"tray_snatcher_stun": "Snatcher %s: STUN",
		"tray_snatcher_echo": "Snatcher %s: +%d",

		# Game 24 Duel Modal
		"duel_title": "GAME 24 — %s",
		"duel_timer": "Sisa Waktu: %.1f dtk",
		"duel_hint": "Gabungkan semua 4 kartu pakai  +  -  ×  :  hingga hasilnya tepat 24!",
		"duel_prompt_start": "Pilih kartu pertama → operator (+ − × :) → kartu kedua",
		"duel_pick_op": "Kartu %s dipilih — sekarang pilih operator (+ − × :)",
		"duel_cancel": "Pilihan dibatalkan — pilih kartu pertama",
		"duel_div_zero": "Tidak bisa membagi dengan 0! Pilih kartu atau operator lain.",
		"duel_not_24": "%s = %s (belum 24!) — klik Undo atau Ulang Kartu",
		"duel_continue": "%s = %s  •  lanjutkan gabung kartu!",
		"duel_pick_first": "Pilih kartu pertama dulu sebelum memilih operator!",
		"duel_pick_second": "%s %s ?  •  pilih kartu kedua",
		"duel_undone": "Langkah terakhir dibatalkan.",
		"duel_cleared": "Kartu diulang ke posisi awal!",
		"btn_undo": "Undo",
		"btn_reset_cards": "Ulang Kartu",
		"btn_giveup": "Menyerah",

		# Duel Outcomes & Banners
		"res_fast_win": "TEPAT 24 (CEPAT)! %s = 24\nLepas dari ekor, maju 4 petak & Snatcher stun 2 giliran!",
		"res_win": "TEPAT 24! %s = 24\nLepas dari ekor, maju 2 petak & Snatcher stun 1 giliran!",
		"res_loss_gameover": "KALAH DUEL! Contoh solusi: %s = 24\nElf terseret sampai Sarang Snatcher — GAME OVER!",
		"res_loss_drag": "KALAH DUEL! Contoh solusi: %s = 24\nElf tetap terikat ekor & diseret mundur!",
		"banner_fast_win": "Menang cepat Game 24 di %s!",
		"banner_win": "Menang Game 24 di %s!",
		"banner_gameover": "GAME OVER di %s!",
		"banner_loss": "Kalah Game 24 di %s — Elf tetap kebawa Snatcher!",
	},
	"en": {
		# Main Menu
		"menu_play": "PLAY",
		"menu_tutorial": "HOW TO PLAY",
		"menu_quit": "QUIT",
		"lang_tooltip": "Switch Language (IND / EN)",

		# Tutorial Overlay
		"tut_title": "HOW TO PLAY — TWIN-LABYRINTH",
		"tut_c1_title": "1. DICE & TWIN MOVEMENT",
		"tut_c1_body": "• Roll 2 dice each turn (Space), then assign 1 die to Labyrinth A and 1 to Labyrinth B.\n• Click the swap arrows below (Tab) to swap the dice between both labyrinths.\n• Click floor tiles to plan each Elf's path (right-click = undo), then click 'Move!'.\n• After the Elves move, both Snatchers chase based on the dice values & difference!",
		"tut_c2_title": "2. IMPORTANT LABYRINTH TILES",
		"tut_exit_title": "Exit Gate",
		"tut_exit_desc": "Final goal! Guide both Elves here to win the game.",
		"tut_safe_title": "Safe Spot (Moon Rune)",
		"tut_safe_desc": "Safe tile! The Snatcher cannot capture an Elf standing here.",
		"tut_lair_title": "Snatcher Lair (Danger!)",
		"tut_lair_desc": "If a captured Elf is dragged all the way here → GAME OVER!",
		"tut_c3_title": "3. GAME 24 DUEL",
		"tut_c3_body": "• If a Snatcher & Elf meet on the same tile (outside a Safe Spot), its tail wraps the Elf!\n• You are dealt 4 cards (A=1 to 10) GUARANTEED to have an exact 24 solution.\n• Click Card 1 → Operator (+ - × :) → Card 2 until 1 card equals 24 before time runs out (25s).",
		"tut_c4_title": "4. VICTORY & GAME OVER",
		"tut_c4_body": "• WIN 24: Elf breaks free, dashes toward Exit (4 tiles if fast, 2 normal) & stuns Snatcher.\n• LOSE / TIME UP: Elf stays bound in the tail & gets dragged toward the Lair, dueling again each turn until winning.\n• VICTORY: Both Elves reach their Exit Gates.\n• GAME OVER: Either Elf is dragged into the Snatcher Lair!",
		"tut_close": "GOT IT - CLOSE",

		# Board & HUD
		"lane_a": "Labyrinth A",
		"lane_b": "Labyrinth B",
		"btn_roll": "Roll Dice",
		"btn_confirm": "Move!",
		"btn_start_duel": "Start Duel!",
		"btn_swap_elves": "Swap Elves",
		"btn_play_again": "Play Again",
		"btn_tutorial_tip": "How to Play (Tutorial)",
		"btn_menu": "Menu",
		"btn_swap_dice_tip": "Swap Labyrinth A & B Dice (Tab)",
		"dice_title_a": "LABYRINTH A DIE",
		"dice_title_b": "LABYRINTH B DIE",

		# HUD Status
		"hud_roll_banner": "%s  |  Press Roll Dice",
		"hud_roll_first": "Roll Phase  •  Click 'Swap Elves' to switch positions",
		"hud_roll_next": "Roll Phase  •  Press 'Roll Dice' (Space)",
		"hud_move_captured": "Elf is still bound by Snatcher — click 'Start Duel!' to play Game 24!",
		"hud_move_pick": "Plan both Elves' paths on the board  •  Click the arrows below to swap dice",
		"hud_duel": "GAME 24 DUEL in %s! Reach 24 to break free from the Snatcher's tail!",
		"hud_won": "VICTORY! Both Elves escaped the Twin-Labyrinth!",
		"hud_lost": "GAME OVER! The Elf in %s was dragged into the Snatcher Lair!",

		# Panel status & Dice tray echo
		"status_escaped": "ESCAPED!",
		"status_captured": "CAPTURED!",
		"status_ready": "Ready! (%d/%d)",
		"status_steps": "Steps: %d/%d",
		"status_stun": "Snatcher Stun (%d)",
		"status_tiles": "%d tiles",
		"tray_escaped": "Elf %s reached the Exit Gate!",
		"tray_captured": "Elf %s is tail-bound — Game 24 Duel!",
		"tray_stun": "Snatcher %s Stunned (%d turns)",
		"tray_wait_roll": "Press 'Roll Dice' to begin turn",
		"tray_move_info": "Move %d tiles  •  %s",
		"tray_snatcher_stun": "Snatcher %s: STUNNED",
		"tray_snatcher_echo": "Snatcher %s: +%d",

		# Game 24 Duel Modal
		"duel_title": "GAME 24 — %s",
		"duel_timer": "Time Left: %.1fs",
		"duel_hint": "Combine all 4 cards using  +  -  ×  :  to reach exactly 24!",
		"duel_prompt_start": "Pick first card → operator (+ − × :) → second card",
		"duel_pick_op": "Card %s selected — now pick an operator (+ − × :)",
		"duel_cancel": "Selection cleared — pick your first card",
		"duel_div_zero": "Cannot divide by 0! Pick another card or operator.",
		"duel_not_24": "%s = %s (not 24 yet!) — click Undo or Reset Cards",
		"duel_continue": "%s = %s  •  keep combining cards!",
		"duel_pick_first": "Pick a first card before selecting an operator!",
		"duel_pick_second": "%s %s ?  •  pick the second card",
		"duel_undone": "Last step undone.",
		"duel_cleared": "Cards reset to starting hand!",
		"btn_undo": "Undo",
		"btn_reset_cards": "Reset Cards",
		"btn_giveup": "Give Up",

		# Duel Outcomes & Banners
		"res_fast_win": "EXACT 24 (FAST)! %s = 24\nFreed from tail, advance 4 tiles & stun Snatcher 2 turns!",
		"res_win": "EXACT 24! %s = 24\nFreed from tail, advance 2 tiles & stun Snatcher 1 turn!",
		"res_loss_gameover": "DUEL LOST! Example solution: %s = 24\nDragged into the Snatcher Lair — GAME OVER!",
		"res_loss_drag": "DUEL LOST! Example solution: %s = 24\nElf remains bound & dragged backward!",
		"banner_fast_win": "Fast Game 24 win in %s!",
		"banner_win": "Won Game 24 in %s!",
		"banner_gameover": "GAME OVER in %s!",
		"banner_loss": "Lost Game 24 in %s — Elf stays captured!",
	},
}


func button_label() -> String:
	return "EN" if current == "en" else "IND"


func toggle() -> void:
	current = "en" if current == "id" else "id"
	language_changed.emit(current)


func t(key: String, args: Array = []) -> String:
	var table: Dictionary = STRINGS.get(current, STRINGS["id"])
	var raw: String = String(table.get(key, key))
	if args.is_empty():
		return raw
	return raw % args

# DaftarnyaSambilMakanBebek

Backend lokal prototipe **Twin-Labyrinth: Gambit & Escape** untuk Godot 4.7. Buat satu instance `TwinLabyrinth.new()` per pertandingan.

1. Panggil `roll_dice()` dan baca hasilnya lewat `get_state().dice`.
2. Panggil `move_runners(die_for_a, route_a, route_b)`. Indeks dadu `0` atau `1` diberikan ke bidak A dan dadu lainnya ke bidak B. Setiap rute berisi petak `Vector2i` yang akan diinjak setelah posisi saat ini. Gunakan rute kosong untuk bidak yang sudah lolos.
3. Saat fase `TwinLabyrinth.Phase.DUEL`, baca kartu lewat `get_duel()`, lalu panggil `hit()` atau `stand()`. Hasil duel tersedia di `get_state().duel_results` hingga lemparan berikutnya. Fase berubah menjadi `WON` saat kedua bidak lolos.

Aksi yang dipanggil pada fase yang salah atau dengan rute tidak valid mengembalikan `false` tanpa mengubah posisi. Layout sementara ada di `scripts/labyrinth.gd`. Simbol `S` menandai awal bidak, `H` titik awal Snatcher, `o` Safe Spot, `E` Exit Gate, dan `#` dinding.

Untuk prototipe ini, Snatcher mengambil kartu hingga minimal 17, seri dihitung sebagai kalah, dan Snatcher yang bust memberi kemenangan tanpa langkah bonus. Bonus maju mengikuti jalur terpendek ke pintu keluar. Saat kalah, jarak dua langkah dari Snatcher dibatasi oleh titik awal Snatcher.

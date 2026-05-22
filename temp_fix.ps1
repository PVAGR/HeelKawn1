# PowerShell script to replace adaptive_frame_tick_cap function
$file = "autoloads/GameManager.gd"
$content = Get-Content $file -Raw
$oldFunc = 'func _adaptive_frame_tick_cap\(base_cap: int\) -> int:[\s\S]*?return base_cap'
$newFunc = "func _adaptive_frame_tick_cap(base_cap: int) -> int:`n" +
"	# Desktop relaxed: most throttling removed; still prevents one-frame freeze`n" +
"	if GameManager == null:`n" +
"		return base_cap`n" +
"	var gs: float = GameManager.game_speed`n" +
"	if gs >= 100.0:`n" +
"		return maxi(1, int(base_cap * 0.8))`n" +
"	if gs >= 50.0:`n" +
"		return maxi(1, int(base_cap * 0.9))`n" +
"	if gs >= 26.0:`n" +
"		return maxi(1, int(base_cap * 0.95))`n" +
"	return base_cap"
$content = $content -replace $oldFunc, $newFunc
Set-Content $file $content -Encoding UTF8
Write-Host "Done"
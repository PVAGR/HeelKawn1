Write-Host "=== 🌐 HeelKawn AI Startup Suite ===" -ForegroundColor Magenta
Write-Host "Working Directory: C:\Users\user\Documents\GitHub\HeelKawn1" -ForegroundColor White
Write-Host ""

Write-Host " Launching services in separate windows..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "& 'C:\Users\user\Documents\GitHub\HeelKawn1\start_aedir.ps1'"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "& 'C:\Users\user\Documents\GitHub\HeelKawn1\start_qwen.ps1'"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "& 'C:\Users\user\Documents\GitHub\HeelKawn1\start_letta.ps1'"

Write-Host ""
Write-Host "✅ All services launched. Close this window when done." -ForegroundColor Green
Read-Host "Press Enter to exit launcher"

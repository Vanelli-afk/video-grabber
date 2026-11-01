@echo off
rem Liga o servidor do VideoGrabber. De dois cliques neste arquivo e deixe a janela aberta.
chcp 65001 > nul
cd /d "%~dp0"
title Servidor do VideoGrabber

if not exist ".venv\Scripts\python.exe" (
    echo [ERRO] O ambiente Python ^(.venv^) nao foi encontrado nesta pasta.
    echo Veja a secao "Backend" do README.md para cria-lo.
    pause
    exit /b 1
)
if not exist ".env" (
    echo [ERRO] O arquivo .env com o token nao foi encontrado.
    echo Copie o .env.example para .env e preencha o API_TOKEN.
    pause
    exit /b 1
)

set "PATH=%~dp0.venv\Scripts;%PATH%"

echo.
echo  ==============================================================
echo   Servidor do VideoGrabber
echo  ==============================================================
echo   No app do iPhone, em Ajustes, use um destes enderecos:
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -in 'Dhcp','Manual' -and $_.IPAddress -notlike '169.*' } | ForEach-Object { '      ' + $_.IPAddress + ':8080    (' + $_.InterfaceAlias + ')' }"
echo.
echo   O token esta no arquivo .env desta pasta (linha API_TOKEN=).
echo.
echo   Deixe esta janela ABERTA enquanto usa o app.
echo   Para desligar o servidor, feche a janela.
echo  ==============================================================
echo.

".venv\Scripts\python.exe" -m uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8080

echo.
echo O servidor parou.
pause

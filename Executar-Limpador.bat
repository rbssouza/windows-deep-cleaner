@echo off
title Windows Deep Cleaner

:: Verifica se esta rodando como Administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :run
) else (
    echo Solicitando privilegios de Administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:run
echo Iniciando o Windows Deep Cleaner...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeepCleaner.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Ocorreu um erro ao executar o script.
    pause
)

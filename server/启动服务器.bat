@echo off
chcp 65001 >nul
title Aurora 网页服务器
cd /d "%~dp0"
aurora_server.exe %*
pause

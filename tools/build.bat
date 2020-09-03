@echo off
pushd %~dp0
clang -O3 -D_CRT_SECURE_NO_WARNINGS vaporize.c -o vaporize.exe
popd

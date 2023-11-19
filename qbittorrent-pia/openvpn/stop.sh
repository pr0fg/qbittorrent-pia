#!/bin/bash

echo "[WARNING] Killing OpenVPN daemon due to disconnect..." | ts '%Y-%m-%d %H:%M:%.S'
/usr/bin/kill 1

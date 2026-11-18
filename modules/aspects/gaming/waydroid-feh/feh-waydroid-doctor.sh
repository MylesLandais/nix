echo "== status =="; waydroid status || true
echo "== service =="; systemctl --no-pager --full status waydroid-container.service || true
echo "== properties =="; waydroid prop get ro.product.cpu.abilist || true; waydroid prop get ro.dalvik.vm.native.bridge || true
echo "== FEH =="
sudo waydroid shell -- dumpsys package @NIX1@ 2>/dev/null | grep -E 'version(Name|Code)=|primaryCpuAbi|secondaryCpuAbi' || echo "FEH not installed"
echo "== recent crashes =="
sudo waydroid shell -- logcat -d -t 500 2>/dev/null | grep -Ei '@NIX2@|FATAL EXCEPTION|native bridge|SIG(SEGV|ABRT)' | tail -n 100 || true

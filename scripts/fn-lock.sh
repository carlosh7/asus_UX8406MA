#!/bin/bash
# ASUS Zenbook Duo - Fn Lock Toggle
# Hardware fn-lock: Fn+Esc to toggle

FN_DEFAULT=$(cat /sys/module/asus_wmi/parameters/fnlock_default 2>/dev/null)

echo "╔══════════════════════════════════════════════╗"
echo "║           FN LOCK STATUS                     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Default: $FN_DEFAULT"
echo ""

if [ "$FN_DEFAULT" = "Y" ]; then
    echo "  ✅ Fn Lock HABILITADO por defecto"
    echo "  → F1-F12 funcionan directamente sin presionar Fn"
    echo "  → Fn+Esc para alternar temporalmente"
else
    echo "  ❌ Fn Lock DESHABILITADO por defecto"
    echo "  → Necesitas presionar Fn + tecla de función"
    echo "  → Fn+Esc para alternar temporalmente"
fi

echo ""
echo "  Para alternar: Fn+Esc (combinación de hardware)"
echo "  No hay control por software en este modelo."

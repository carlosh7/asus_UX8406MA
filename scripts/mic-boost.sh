#!/bin/bash
# %U en unidades de sistema expande a 0 (root): derivar el runtime de PipeWire
# del UID efectivo del servicio (User=)
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR
sleep 3
MIC_ID=$(pw-dump 2>/dev/null | python3 -c "
import json,sys
data = json.load(sys.stdin)
for obj in data:
    props = obj.get('info',{}).get('props',{})
    if props.get('media.class') == 'Audio/Source' and 'Digital' in props.get('node.nick','') and 'Headphone' not in props.get('node.nick',''):
        print(obj['id'])
        break
" 2>/dev/null)
if [ -n "$MIC_ID" ]; then
    wpctl set-volume "$MIC_ID" 1.0 >/dev/null 2>&1
    pw-cli set-param "$MIC_ID" Props "{ volume: 1.0, channelVolumes: [10.0, 10.0], softVolumes: [5.0, 5.0], mute: false, softMute: false }" >/dev/null 2>&1
fi

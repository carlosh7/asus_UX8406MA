#!/bin/bash
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

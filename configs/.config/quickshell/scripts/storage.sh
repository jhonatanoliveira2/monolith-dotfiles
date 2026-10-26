#!/usr/bin/env bash
# Settings > Storage data, two JSON lines:
#   1) lsblk tree in bytes            2) health per whole disk, from UDisks2 (no root needed):
#      {"/dev/nvme0n1": {"bus":"nvme","temp":C,"hours":h,"used":%,"spare":%,"warn":[...],"errors":n}, "/dev/sda": {"bus":"ata","failing":bool,...}}
export LC_ALL=C
lsblk -J -b -o NAME,PATH,TYPE,SIZE,FSTYPE,FSSIZE,FSUSED,FSAVAIL,MOUNTPOINTS,LABEL,MODEL,TRAN,RM,HOTPLUG,ROTA 2>/dev/null | tr -d '\n'
echo
command -v busctl >/dev/null && command -v jq >/dev/null || { echo '{}'; exit 0; }
objs=$(busctl --system --json=short call org.freedesktop.UDisks2 /org/freedesktop/UDisks2 \
       org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null) || { echo '{}'; exit 0; }
# whole-disk block device -> drive object, plus the drive's SMART properties
base=$(jq -c '
  .data[0] as $o
  | [ $o | to_entries[]
      | select(.value["org.freedesktop.UDisks2.Block"] and (.value["org.freedesktop.UDisks2.Partition"] | not))
      | .value["org.freedesktop.UDisks2.Block"] as $b
      | select($b.Drive.data != "/")
      | { dev: ($b.Device.data | map(select(. != 0)) | implode), drive: $b.Drive.data } ]
  | map(. as $d | $o[$d.drive] as $dr
      | { key: $d.dev, value: (
          if $dr["org.freedesktop.UDisks2.NVMe.Controller"] then
            ($dr["org.freedesktop.UDisks2.NVMe.Controller"]) as $n
            | { bus: "nvme", drive: $d.drive, temp: (($n.SmartTemperature.data // 0) - 273), hours: $n.SmartPowerOnHours.data,
                warn: $n.SmartCriticalWarning.data }
          elif $dr["org.freedesktop.UDisks2.Drive.Ata"] then
            ($dr["org.freedesktop.UDisks2.Drive.Ata"]) as $a
            | { bus: "ata", enabled: $a.SmartEnabled.data, failing: $a.SmartFailing.data,
                temp: (if ($a.SmartTemperature.data // 0) > 0 then (($a.SmartTemperature.data - 273.15) | floor) else null end),
                hours: (($a.SmartPowerOnSeconds.data // 0) / 3600 | floor), badSectors: $a.SmartNumBadSectors.data }
          else { bus: "other" } end) })
  | from_entries' <<<"$objs" 2>/dev/null) || base='{}'
# NVMe wear (percent used, spare, media errors): one SmartGetAttributes call per controller
for dev in $(jq -r 'to_entries[] | select(.value.bus == "nvme") | .key' <<<"$base"); do
    drive=$(jq -r --arg d "$dev" '.[$d].drive' <<<"$base")
    attrs=$(busctl --system --json=short call org.freedesktop.UDisks2 "$drive" org.freedesktop.UDisks2.NVMe.Controller \
            SmartGetAttributes 'a{sv}' 0 2>/dev/null | jq -c '.data[0] | {used: .percent_used.data, spare: .avail_spare.data, errors: .media_errors.data}' 2>/dev/null)
    [ -n "$attrs" ] && base=$(jq -c --arg d "$dev" --argjson a "$attrs" '.[$d] += $a' <<<"$base")
done
echo "$base"

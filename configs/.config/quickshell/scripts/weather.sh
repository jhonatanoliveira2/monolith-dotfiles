#!/usr/bin/env bash
# weather.sh <place> <lat> <lon> <name> <lang> [by-ip] - Open-Meteo (no API key), for services/Weather.qml.
# Known coordinates skip the lookup; otherwise <place> is geocoded ("" = located by IP through ipinfo.io,
# unless by-ip is 0: then nothing is requested and the exit code is 3). Prints three lines:
#   1) name<TAB>lat<TAB>lon   2) forecast JSON   3) air quality JSON ({} when unavailable)
export LC_ALL=C
q=${1%%,*} lat=$2 lon=$3 name=$4 lang=${5:-pt} byip=${6:-1}
get() { curl -fsS --max-time 10 "$@"; }

if [[ -z $lat || -z $lon ]]; then
    if [[ -n $q ]]; then
        r=$(get -G https://geocoding-api.open-meteo.com/v1/search --data-urlencode "name=$q" -d count=1 -d "language=$lang") || exit 1
        IFS=$'\t' read -r name lat lon < <(jq -r '.results[0] | [.name, .latitude, .longitude] | @tsv' <<<"$r" 2>/dev/null)
    else
        [[ $byip == 1 ]] || exit 3
        r=$(get https://ipinfo.io/json) || exit 1
        IFS=$'\t' read -r name lat lon < <(jq -r '[.city, (.loc | split(",")[0]), (.loc | split(",")[1])] | @tsv' <<<"$r" 2>/dev/null)
    fi
fi
[[ -n $lat && $lat != null ]] || exit 2

# air quality in parallel with the forecast
exec 3< <(get "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi,pm2_5,pm10&timezone=auto" || echo '{}')
f=$(get "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&timezone=auto&forecast_days=7&forecast_hours=24\
&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index\
&hourly=temperature_2m,weather_code,precipitation_probability,is_day\
&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,sunrise,sunset,uv_index_max") || exit 1

printf '%s\t%s\t%s\n' "$name" "$lat" "$lon"
jq -c . <<<"$f"
jq -c . <&3 2>/dev/null || echo '{}'

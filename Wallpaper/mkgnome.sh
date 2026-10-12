#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

declare -A pkgmap=(
    ["AuroraLayers"]="parch-wallpaper-auroralayers"
    ["Cultural"]="parch-wallpaper-cultural"
    ["damavand"]="parch-wallpaper-damavand"
    ["Geometric-wallpapers"]="parch-wallpaper-geometric"
    ["Imaginary_landscape"]="parch-wallpaper-imaginary-landscape"
    ["Natural-wallpapers"]="parch-wallpaper-natural"
    ["Paisley"]="parch-wallpaper-paisley"
    ["parch-fifth-anniversary"]="parch-wallpaper-fifth-anniversary"
    ["parch-forth-anniversary"]="parch-wallpaper-forth-anniversary"
    ["Parch-wallpaper"]="parch-wallpaper-parch-wallpaper"
    ["Parch"]="parch-wallpaper-parch"
    ["PArch2"]="parch-wallpaper-parch2"
    ["Sketchy-background"]="parch-wallpaper-sketchy-background"
)

generate_xml_for_files() {
    local output="$1"
    shift
    local files=("$@")

    if [[ ${#files[@]} -eq 0 ]]; then
        return
    fi

    declare -A pairs seen
    local re_light_end='^(.*)[-_ ](light|lite)$'
    local re_dark_end='^(.*)[-_ ](dark)$'
    local re_light_mid='^(.*)[-_ ](light|lite)[-_ ](.*)$'
    local re_dark_mid='^(.*)[-_ ](dark)[-_ ](.*)$'

    for f in "${files[@]}"; do
        local base dir stem lstem key
        base=$(basename "$f")
        dir=$(dirname "$f")
        stem="${base%.*}"
        lstem=$(echo "$stem" | tr '[:upper:]' '[:lower:]')

        if [[ $lstem =~ $re_light_end ]]; then
            local prefix="${BASH_REMATCH[1]}"
            key="$dir/${stem:0:${#prefix}}"
            pairs["$key,light"]="$f"
            seen["$key"]=1
        elif [[ $lstem =~ $re_dark_end ]]; then
            local prefix="${BASH_REMATCH[1]}"
            key="$dir/${stem:0:${#prefix}}"
            pairs["$key,dark"]="$f"
            seen["$key"]=1
        elif [[ $lstem =~ $re_light_mid ]]; then
            local p1="${BASH_REMATCH[1]}"
            local p2="${BASH_REMATCH[3]}"
            key="$dir/${p1}_${p2}"
            pairs["$key,light"]="$f"
            seen["$key"]=1
        elif [[ $lstem =~ $re_dark_mid ]]; then
            local p1="${BASH_REMATCH[1]}"
            local p2="${BASH_REMATCH[3]}"
            key="$dir/${p1}_${p2}"
            pairs["$key,dark"]="$f"
            seen["$key"]=1
        else
            key="$dir/$stem"
            pairs["$key,single"]="$f"
            seen["$key"]=1
        fi
    done

    cat > "$output" <<EOF
<?xml version="1.0"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
EOF

    mapfile -t sorted_keys < <(printf '%s\n' "${!seen[@]}" | sort)

    for key in "${sorted_keys[@]}"; do
        local light="${pairs[$key,light]:-}"
        local dark="${pairs[$key,dark]:-}"
        local single="${pairs[$key,single]:-}"

        local pretty_name folder_name
        pretty_name=$(basename "$key")
        folder_name=$(basename "$(dirname "$key")")

        echo "  <wallpaper deleted=\"false\">" >> "$output"
        echo "    <name>${folder_name} - ${pretty_name}</name>" >> "$output"

        if [[ -n "$light" && -n "$dark" ]]; then
            echo "    <filename>/usr/share/wallpapers/${light#./}</filename>" >> "$output"
            echo "    <filename-dark>/usr/share/wallpapers/${dark#./}</filename-dark>" >> "$output"
        elif [[ -n "$light" ]]; then
            echo "    <filename>/usr/share/wallpapers/${light#./}</filename>" >> "$output"
        elif [[ -n "$dark" ]]; then
            echo "    <filename>/usr/share/wallpapers/${dark#./}</filename>" >> "$output"
        elif [[ -n "$single" ]]; then
            echo "    <filename>/usr/share/wallpapers/${single#./}</filename>" >> "$output"
        fi

        cat >> "$output" <<EOF
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#000000</scolor>
  </wallpaper>
EOF
    done

    echo "</wallpapers>" >> "$output"
    echo "✅ Generated: $output"
}

# Generate per-package XML files
for folder in "${!pkgmap[@]}"; do
    pkgname="${pkgmap[$folder]}"
    if [[ -d "$folder" ]]; then
        mapfile -t folder_files < <(find "$folder" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.svg' \) | sort)
        if [[ ${#folder_files[@]} -gt 0 ]]; then
            generate_xml_for_files "${pkgname}.xml" "${folder_files[@]}"
        fi
    fi
done

# Generate meta XML containing all wallpapers
mapfile -t all_files < <(find . -mindepth 2 -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.svg' \) ! -path "./build/*" ! -path "./packages/*" | sort)
generate_xml_for_files "parch-wallpapers.xml" "${all_files[@]}"

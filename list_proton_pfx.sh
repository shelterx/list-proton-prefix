#!/bin/bash
#
# This script finds all Steam and Non-Steam Proton prefixes.
#

# Function to get all Steam library paths from libraryfolders.vdf
get_library_paths() {
    local library_folders_file="$HOME/.steam/steam/steamapps/libraryfolders.vdf"
    local paths=()

    if [ -f "$library_folders_file" ]; then
        while IFS= read -r line; do
            if [[ $line =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
                paths+=("${BASH_REMATCH[1]}/steamapps")
            fi
        done < <(grep '"path"' "$library_folders_file")
    fi

    paths+=("$HOME/.steam/steam/steamapps")
    printf "%s\n" "${paths[@]}" | sort -u
}

main() {
    echo -e "\nExisting Proton prefixes (Steam & Non-Steam)"
    echo "--------------------------------------------"

    local -A official_app_ids
    local library_paths
    readarray -t library_paths < <(get_library_paths)

    for path in "${library_paths[@]}"; do
        for manifest in "$path"/appmanifest_*.acf; do
            if [ -f "$manifest" ]; then
                local app_id
                app_id=$(grep -oP '"appid"\s*"\K[0-9]+' "$manifest")
                if [ -n "$app_id" ]; then
                    official_app_ids["$app_id"]=1
                fi
            fi
        done
    done

    {
        for path in "${library_paths[@]}"; do
            for dir in "$path/compatdata"/*; do
                if [ ! -d "$dir" ]; then continue; fi

                local app_id
                app_id=$(basename "$dir")
                if ! [[ "$app_id" =~ ^[0-9]+$ ]]; then continue; fi

                if [[ -v official_app_ids["$app_id"] ]]; then
                    local manifest_file="$path/appmanifest_$app_id.acf"
                    if [ -f "$manifest_file" ]; then
                        local game_name
                        game_name=$(grep -oP '"name"\s*"\K[^"]+' "$manifest_file" | head -n 1)
                        if [[ "$game_name" != "Proton "* ]] && [ -n "$game_name" ]; then
                            printf "%s\t%s\n" "$game_name" "$dir"
                        fi
                    fi
                else
                    if [[ "$app_id" -gt 2000000000 ]]; then
                        printf "%s\t%s\n" "Non-Steam Game (ID: $app_id)" "$dir"
                    fi
                fi
            done
        done
    } | sort -t $'\t' -k1,1 -u | column -t -s $'\t'

    echo
}

# Call main shebang
main

#!/usr/bin/env bash
# Native Mini vMac: Macintosh Plus (68000) with System 6.0.8.
# Choose which disks from Disks/ to mount and remember the last selection.
set -euo pipefail
cd "$(dirname "$0")"

# If launched without a terminal (for example from the app menu),
# open one so the list can be displayed.
if [[ ! -t 0 || ! -t 1 ]]; then
	self=$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")
	if command -v omarchy-launch-tui >/dev/null 2>&1; then
		exec omarchy-launch-tui --app-id=org.fede.minivmac "$self" "$@"
	fi
	if command -v foot >/dev/null 2>&1; then
		exec foot -e "$self" "$@"
	fi
	echo "A terminal is needed to choose the disks." >&2
	exit 1
fi

state_file=".selected-disks"
# Read the old Spanish name once, so an existing selection is not lost.
read_state_file=$state_file
if [[ ! -f $read_state_file && -f .discos-seleccionados ]]; then
	read_state_file='.discos-seleccionados'
fi

# --- available disks (including subfolders) -----------------------------

shopt -s nullglob

all_files=()
while IFS= read -r path; do
	[[ -f $path ]] || continue
	ext=${path##*.}
	ext=${ext,,}
	case $ext in
		dsk|disk|img|dmg|dc42|image)
			all_files+=("${path#Disks/}")
			;;
	esac
done < <(find Disks -type f -print 2>/dev/null | sort -f)

if (( ${#all_files[@]} == 0 )); then
	echo "No disks found in $(pwd)/Disks." >&2
	exit 1
fi

# Folders (and subfolders) that contain at least one disk.
declare -A is_dir=()
all_dirs=()
for f in "${all_files[@]}"; do
	d=$(dirname "$f")
	while [[ $d != "." ]]; do
		if [[ -z ${is_dir[$d]+x} ]]; then
			is_dir[$d]=1
			all_dirs+=("$d")
		fi
		d=$(dirname "$d")
	done
done
if (( ${#all_dirs[@]} )); then
	mapfile -t all_dirs < <(printf '%s\n' "${all_dirs[@]}" | sort -f)
fi

# Tree: children of each folder, with subfolders before files.
declare -A children=()
declare -A file_count=()
root_dirs=()
root_files=()
for d in "${all_dirs[@]}"; do
	parent=$(dirname "$d")
	if [[ $parent == "." ]]; then
		root_dirs+=("$d")
	else
		children[$parent]+="$d"$'\n'
	fi
done
for f in "${all_files[@]}"; do
	parent=$(dirname "$f")
	if [[ $parent == "." ]]; then
		root_files+=("$f")
	else
		children[$parent]+="$f"$'\n'
	fi
	d=$parent
	while true; do
		file_count[$d]=$(( ${file_count[$d]:-0} + 1 ))
		[[ $d == "." ]] && break
		d=$(dirname "$d")
	done
done

# At the root: system disks first, then folders, then the rest.
sys_root=()
other_root=()
for f in "${root_files[@]}"; do
	if [[ ${f,,} == *system* ]]; then
		sys_root+=("$f")
	else
		other_root+=("$f")
	fi
done
children["."]=''
for x in "${sys_root[@]}" "${root_dirs[@]}" "${other_root[@]}"; do
	children["."]+="$x"$'\n'
done

# --- visible tree -------------------------------------------------------

declare -A expanded=()
vis_path=()
vis_depth=()
vis_is_dir=()

walk_tree() {
	local parent=$1 depth=$2 child list
	list=${children[$parent]-}
	[[ -n $list ]] || return 0
	while IFS= read -r child; do
		[[ -n $child ]] || continue
		vis_path+=("$child")
		vis_depth+=("$depth")
		if [[ -n ${is_dir[$child]+x} ]]; then
			vis_is_dir+=(1)
			if [[ -n ${expanded[$child]+x} ]]; then
				walk_tree "$child" $((depth + 1))
			fi
		else
			vis_is_dir+=(0)
		fi
	done <<< "$list"
}

build_visible() {
	vis_path=()
	vis_depth=()
	vis_is_dir=()
	walk_tree "." 0
}

# --- last saved selection -----------------------------------------------

declare -A saved=()
first_saved=""
if [[ -f $read_state_file ]]; then
	while IFS= read -r line; do
		if [[ -n $line ]]; then
			saved[$line]=1
			if [[ -z $first_saved ]]; then
				first_saved=$line
			fi
		fi
	done < "$read_state_file"
fi

declare -A selected=()
for f in "${all_files[@]}"; do
	if [[ -n ${saved[$f]+x} ]]; then
		selected[$f]=1
	fi
done

have_selection() {
	local f
	for f in "${all_files[@]}"; do
		if [[ -n ${selected[$f]+x} ]]; then
			return 0
		fi
	done
	return 1
}

# On first run, start with the system disk.
if [[ ! -f $read_state_file ]]; then
	for f in "${all_files[@]}"; do
		if [[ ${f,,} == *system* ]]; then
			selected[$f]=1
			first_saved=$f
			break
		fi
	done
fi

# If the saved state matches no disk, start with the system disk.
if ! have_selection; then
	for f in "${all_files[@]}"; do
		if [[ ${f,,} == *system* ]]; then
			selected[$f]=1
			first_saved=$f
			break
		fi
	done
fi
if ! have_selection; then
	selected[${all_files[0]}]=1
	first_saved=${all_files[0]}
fi

# Startup Disk: the saved one (first line) or the first selected.
boot_path=""
if [[ -n $first_saved && -n ${selected[$first_saved]+x} ]] && [[ -z ${is_dir[$first_saved]+x} ]]; then
	boot_path=$first_saved
fi
if [[ -z $boot_path ]]; then
	for f in "${all_files[@]}"; do
		if [[ -n ${selected[$f]+x} ]]; then
			boot_path=$f
			break
		fi
	done
fi

# Last disk marked with S; remembered even if everything is unselected.
last_boot=$boot_path

# Open every folder containing a selected disk (and its parents) on startup,
# so the selection is visible even in nested folders.
for f in "${all_files[@]}"; do
	if [[ -n ${selected[$f]+x} ]]; then
		d=$(dirname "$f")
		while [[ $d != "." ]]; do
			expanded[$d]=1
			d=$(dirname "$d")
		done
	fi
done

# --- menu ---------------------------------------------------------------

# Number of selected disks inside each folder, including subfolders.
declare -A sel_count=()
compute_sel_counts() {
	local f d
	sel_count=()
	for f in "${all_files[@]}"; do
		if [[ -n ${selected[$f]+x} ]]; then
			d=$(dirname "$f")
			while true; do
				sel_count[$d]=$(( ${sel_count[$d]:-0} + 1 ))
				[[ $d == "." ]] && break
				d=$(dirname "$d")
			done
		fi
	done
}

find_current() {
	local i path=$1
	for i in "${!vis_path[@]}"; do
		if [[ ${vis_path[i]} == "$path" ]]; then
			cur=$i
			return
		fi
	done
}

# Empty folders close when the cursor moves out of them. Going up reaches the
# folder's own row and closes it; going down walks its disks and closes it only
# after the last one. Folders with a selection (at any depth) stay open.
collapse_empty_folders() {
	local stay=$1 nav_dir=$2 p
	local -a folders=("${!expanded[@]}")
	for p in "${folders[@]}"; do
		[[ ${sel_count[$p]:-0} -eq 0 ]] || continue
		if [[ $stay == "$p/"* ]]; then
			continue
		elif [[ $stay == "$p" ]]; then
			[[ $nav_dir == up ]] || continue
		fi
		unset 'expanded[$p]'
	done
}

draw_help() {
	local w1=22 w2=16 inner i hline='' arrows='[↑/↓] move'
	inner=$(( w1 + w2 + 4 ))
	for ((i = 0; i < inner; i++)); do
		hline+='─'
	done
	printf '┌─ Shortcuts %s┐\n' "${hline:12}"
	printf '│ %s%*s  %-*s │\n' "$arrows" $(( w1 - ${#arrows} )) '' "$w2" '[S] Startup Disk'
	printf '│ %-*s  %-*s │\n' "$w1" '[Space] Select' "$w2" '[Enter] start'
	printf '│ %-*s  %-*s │\n' "$w1" '[Ctrl+A] all/none' "$w2" '[Esc] cancel'
	printf '│ %-*s  %-*s │\n' "$w1" '[L] lock' "$w2" ''
	printf '└%s┘\n' "$hline"
}

draw() {
	build_visible
	compute_sel_counts
	if (( cur >= ${#vis_path[@]} )); then
		cur=$(( ${#vis_path[@]} - 1 ))
	fi
	printf '\033[H\033[2J'
	printf 'Disks to mount\n\n'
	draw_help
	printf '\n'
	local i p mark check note label lock total selected_n
	for i in "${!vis_path[@]}"; do
		p=${vis_path[i]}
		mark=' '
		if (( i == cur )); then
			mark='>'
		fi
		note=''
		if (( vis_is_dir[i] )); then
			if [[ -n ${expanded[$p]+x} ]]; then
				check='-'
			else
				check='+'
			fi
			label="${p##*/}/"
			total=${file_count[$p]:-0}
			selected_n=${sel_count[$p]:-0}
			note="   ($total disk"
			(( total > 1 )) && note+='s'
			if (( selected_n > 0 )); then
				note+=", $selected_n selected"
				(( selected_n > 1 )) && note+='s'
			fi
			note+=')'
		else
			if [[ -n ${selected[$p]+x} ]]; then
				check='x'
			else
				check=' '
			fi
			label=${p##*/}
			lock=''
			if [[ ! -w Disks/$p ]]; then
				lock='ø '
			fi
			if [[ $p == "$boot_path" ]]; then
				note+='   (Startup Disk)'
			fi
		fi
		printf '%s %*s[%s] %s%s%s\n' "$mark" $(( vis_depth[i] * 2 )) '' "$check" "$lock" "$label" "$note"
	done
	if [[ -n $msg ]]; then
		printf '\n%s\n' "$msg"
	fi
}

toggle_current() {
	local path=${vis_path[cur]}
	if (( vis_is_dir[cur] )); then
		if [[ -n ${expanded[$path]+x} ]]; then
			unset 'expanded[$path]'
		else
			expanded[$path]=1
		fi
		build_visible
		local i
		for i in "${!vis_path[@]}"; do
			if [[ ${vis_path[i]} == "$path" ]]; then
				cur=$i
				break
			fi
		done
		return
	fi

	if [[ -n ${selected[$path]+x} ]]; then
		unset 'selected[$path]'
		# If it was the Startup Disk, clear its mark.
		# last_boot is kept to restore the mark if it is selected again.
		if [[ $path == "$boot_path" ]]; then
			boot_path=''
		fi
	else
		# Was any disk selected before this one?
		local had_selection=0 f
		for f in "${all_files[@]}"; do
			if [[ -n ${selected[$f]+x} ]]; then
				had_selection=1
				break
			fi
		done
		selected[$path]=1
		# If there is no Startup Disk and none was selected, the disk
		# being selected becomes the Startup Disk.
		# If the last Startup Disk is selected again, it also becomes the Startup Disk.
		if [[ -z $boot_path ]]; then
			if (( ! had_selection )) || [[ $path == "$last_boot" ]]; then
				boot_path=$path
				last_boot=$path
			fi
		fi
	fi
}

boot_is_selected() {
	[[ -n $boot_path && -n ${selected[$boot_path]+x} ]]
}

set_boot() {
	local path=${vis_path[cur]}
	if (( vis_is_dir[cur] )); then
		msg='Only disks can be set as the Startup Disk.'
		return
	fi
	selected[$path]=1
	boot_path=$path
	last_boot=$path
}

toggle_lock() {
	local file="Disks/${vis_path[cur]}"
	if (( vis_is_dir[cur] )); then
		msg='Only disks can be locked.'
		return
	fi
	if [[ -w $file ]]; then
		if chmod a-w -- "$file"; then
			msg='Disk locked (read-only).'
		else
			msg='Could not lock the disk.'
		fi
	else
		if chmod u+w -- "$file"; then
			msg='Disk unlocked.'
		else
			msg='Could not unlock the disk.'
		fi
	fi
}

toggle_all() {
	local f all=1
	for f in "${all_files[@]}"; do
		if [[ -z ${selected[$f]+x} ]]; then
			all=0
			break
		fi
	done
	if (( all )); then
		selected=()
		boot_path=''
	else
		for f in "${all_files[@]}"; do
			selected[$f]=1
		done
		# When selecting all from none, restore the last Startup Disk marked with S.
		boot_path=''
		if [[ -n $last_boot && -n ${selected[$last_boot]+x} ]]; then
			boot_path=$last_boot
		fi
		# If none was ever marked, the first one (the system disk) is used.
		if [[ -z $boot_path ]]; then
			for f in "${all_files[@]}"; do
				if [[ ${f,,} == *system* ]]; then
					boot_path=$f
					break
				fi
			done
		fi
		if [[ -z $boot_path ]]; then
			boot_path=${all_files[0]}
		fi
	fi
}

exec 3</dev/tty
printf '\033[?25l'
cleanup() {
	printf '\033[?25h\033[0m'
}
trap cleanup EXIT

cur=0
confirm=0
msg=''
draw

while true; do
	if ! IFS= read -rsN1 key <&3; then
		break
	fi

	if [[ $key == $'\033' ]]; then
		k2=''
		IFS= read -rsN1 -t 0.05 k2 <&3 || true
		if [[ $k2 == '[' ]]; then
			nav_dir=''
			k3=''
			IFS= read -rsN1 -t 0.05 k3 <&3 || true
			case $k3 in
				A)
					nav_dir=up
					if (( cur > 0 )); then
						cur=$((cur - 1))
					fi
					;;
				B)
					nav_dir=down
					if (( cur < ${#vis_path[@]} - 1 )); then
						cur=$((cur + 1))
					fi
					;;
			esac
			stay_path=${vis_path[cur]}
			collapse_empty_folders "$stay_path" "$nav_dir"
			build_visible
			find_current "$stay_path"
			draw
			continue
		fi
		break
	fi

	case $key in
		$'\n')
			if ! have_selection; then
				msg='Select at least one disk to start.'
				draw
				continue
			fi
			if ! boot_is_selected; then
				msg='Mark a Startup Disk with S.'
				draw
				continue
			fi
			confirm=1
			break
			;;
		' ')
			msg=''
			toggle_current
			;;
		s|S)
			msg=''
			set_boot
			;;
		l|L)
			msg=''
			toggle_lock
			;;
		$'\001')
			msg=''
			toggle_all
			;;
		q|Q)
			break
			;;
	esac

	draw
done

if (( ! confirm )); then
	exit 0
fi

# If no Startup Disk was chosen with S, or it was unselected,
# use the first selected disk.
if [[ -z $boot_path || -z ${selected[$boot_path]+x} ]]; then
	boot_path=''
	for f in "${all_files[@]}"; do
		if [[ -n ${selected[$f]+x} ]]; then
			boot_path=$f
			break
		fi
	done
fi

# Save the selection: first line = Startup Disk.
{
	if [[ -n $boot_path ]]; then
		printf '%s\n' "$boot_path"
	fi
	for f in "${all_files[@]}"; do
		if [[ $f == "$boot_path" ]]; then
			continue
		fi
		if [[ -n ${selected[$f]+x} ]]; then
			printf '%s\n' "$f"
		fi
	done
} > "$state_file"

# Build the arguments, with the Startup Disk first.
args=()
if [[ -n $boot_path ]]; then
	args+=("Disks/$boot_path")
fi
for f in "${all_files[@]}"; do
	if [[ $f == "$boot_path" ]]; then
		continue
	fi
	if [[ -n ${selected[$f]+x} ]]; then
		args+=("Disks/$f")
	fi
done

# Open on a new Hyprland desktop, if we are in a session.
# Hyprland 0.56+ accepts Lua in "hyprctl dispatch"; keep a classic fallback.
hypr_ws() {
	hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })" >/dev/null 2>&1 && return 0
	hyprctl dispatch workspace "$1" >/dev/null 2>&1
}

prev_ws=''
new_ws=''
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE-} ]] && command -v hyprctl >/dev/null 2>&1; then
	prev_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || true)
	if [[ -n $prev_ws && $prev_ws != null ]]; then
		hypr_ws e+1 || true
		new_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || true)
		if [[ $new_ws == "$prev_ws" ]]; then
			new_ws=''
		fi
	fi
fi

status=0
./minivmac -r Mac-Plus.rom "${args[@]}" || status=$?

# If we are still on the desktop we opened and it is empty, go back.
if [[ -n $new_ws ]]; then
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		cur_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || true)
		wins=$(hyprctl clients -j 2>/dev/null |
			jq --argjson ws "$new_ws" '[.[] | select(.workspace.id == $ws)] | length' 2>/dev/null || echo 1)
		if [[ $cur_ws == "$new_ws" && $wins == 0 ]]; then
			break
		fi
		sleep 0.1
	done
	if [[ $cur_ws == "$new_ws" && $wins == 0 ]]; then
		hypr_ws "$prev_ws" || true
	fi
fi

exit "$status"

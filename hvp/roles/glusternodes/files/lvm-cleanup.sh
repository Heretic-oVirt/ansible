#!/bin/bash
# Script to cleanup VDO/LVM configuration outside of the OS PV/VG/LVs

# Variables
unset vol2rm_name vol2rm_vg vol2rm_mnt pv2rm_dev vdo2rm_name vdo2rm_disk

# Define some useful commands
wait_cmd="udevadm settle --timeout=5"
trigger_cmd="udevadm trigger --verbose"

# Detect VDO availability
if [ -n "$(which vdo 2>/dev/null)" ]; then
        has_vdo="true"
else
        has_vdo="false"
fi

# Note: autodetecting root volume group as that which holds the "/" LVM logical volume
root_dev=$(mount | awk '{if ($3 == "/") {print $1}}')
if echo "${root_dev}" | grep -q 'mapper' ; then
	root_vg=$(echo "${root_dev}" | sed -e 's%^/dev/mapper/%%' -e 's/^\([^-]*\)-.*$/\1/')
else
	root_vg=$(echo "${root_dev}" | sed -e 's%^/dev/\([^/]*\)/.*$%\1%')
fi

# Linux LVM discovery
if [ -n "${root_vg}" ]; then
	# Find all LVM physical volumes belonging to non-root volume groups
	i=0
	for pv_name in $(pvs --noheadings -o pv_name); do
		pv_vgname=$(pvs --noheadings -o vg_name "${pv_name}" | tr -d '[[:space:]]')
		# Skip root volume group (does not belong to additional disk configuration)
		if [ "${pv_vgname}" != "${root_vg}" ]; then
			pv2rm_dev[${i}]="${pv_name}"
			i=$((${i}+1))
		fi
	done
	# Find all non-root LVM volume groups and their logical volumes (with corresponding mountpoints)
	# TODO: disk could be already in use also as: a raw partition or a Linux software RAID member - detect accordingly
	j=0
	for vg_name in $(vgs --noheadings -o vg_name); do
		# Skip root volume group (does not belong to additional disk configuration)
		if [ "${vg_name}" = "${root_vg}" ]; then
			continue
		fi
		for lv_name in $(lvs --noheadings -o lv_name "${vg_name}"); do
			vol2rm_name[${j}]="${lv_name}"
			vol2rm_vg[${j}]="${vg_name}"
			vol2rm_mnt[${j}]=$(mount | sed -e 's%mapper/\([^-]*\)-%\1/%' | grep "^/dev/${vg_name}/${lv_name}[[:space:]]" | awk '{print $3}')
			# Detect swap volume (does not show up in mount output)
			# Note: inactive swap volumes will not be specially detected here but will not need swapoff-ing later either
			if [ -z "${vol2rm_mnt[${j}]}" ]; then
				for swapdev in $(grep '[[:space:]]partition[[:space:]]' /proc/swaps | sed -e 's%mapper/\([^-]*\)-%\1/%' | awk '{print $1}'); do
					# Note: newer kernels list swap volumes using their dm-N node - normalizing here
					if echo "${swapdev}" | grep -q '^/dev/dm-' ; then
						for devlink in /dev/mapper/*; do
							realdev=$(stat -c "%N" "${devlink}" | sed -e "s%^.*-> \`.*/\\([^/']*\\)'.*\$%\\1%")
							if [ "/dev/${realdev}" = "${swapdev}" ]; then
								swapdev=$(echo "${devlink}" | sed -e 's%mapper/\([^-]*\)-%\1/%')
								break
							fi
						done
					fi
					if echo "${swapdev}" | grep -q "^/dev/${vg_name}/${lv_name}\$" ; then
						vol2rm_mnt[${j}]="swap"
						break
					fi
				done
			fi
			j=$((${j}+1))
		done
	done
else
	echo "Unable to determine root volume group - exiting." 1>&2
	exit 255
fi

# VDO discovery
if [ "${has_vdo}" = "true" ]; then
	i=0
	for vdo_volname in $(vdo list --all); do
		# TODO: detect whether the VDO volume is used inside the root VG and skip
		vdo2rm_name[${i}]="${vdo_volname}"
		vdo2rm_disk[${i}]="$(dmsetup status ${vdo_volname} | awk '{print $4}')"
		i=$((${i}+1))
	done
fi

# Unmount all found LVM logical volumes and remove their mountpoints (first loop for currently mounted filesystems)
# Note: this must be done in inverse mountpoint alpabetical order to guarantee successfull unmounting/removing of nested mountpoints
# Note: bind mounts are not supported nor searched for
# TODO: unmount any bind mounts first
# TODO: disk could be already in use also as: a raw partition or a Linux software RAID member - stop/deactivate accordingly
# Note: checking number of found mountpoints to avoid issuing an empty command
if [ "${#vol2rm_mnt[*]}" -gt 0 ]; then
	# Note: cycling on logical volume names since some could be in use as raw volume (no corresponding mountpoint)
	for (( k=0; k<${#vol2rm_name[*]}; k=k+1 )); do
		if [ -n "${vol2rm_mnt[${k}]}" ]; then
			# Note: assuming that all swap areas are only inside LVM logical volumes
			if [ "${vol2rm_mnt[${k}]}" = "swap" ]; then
				swapoff "/dev/${vol2rm_vg[${k}]}/${vol2rm_name[${k}]}"
			else
				echo "${vol2rm_mnt[${k}]}"
			fi
		fi
	done | sort -r | xargs -I % sh -c '{ umount -l % ; rmdir % ; }'
fi

# Remove all found LVM logical volumes
# Note: detecting mount points again using configured fstab entries
# Note: bind mounts are not supported nor searched for
# TODO: remove any bind mounts
# Note: cycling on volume names since some could be in use as raw volume (no corresponding mountpoint)
for (( k=0; k<${#vol2rm_name[*]}; k=k+1 )); do
	# Detect LVM logical volume mount point from fstab
	vol2rm_mnt[${k}]=$(grep "^/dev/${vol2rm_vg[${k}]}/${vol2rm_name[${k}]}[[:space:]]" /etc/fstab | awk '{print $2}')
	# Remove LVM logical volume from fstab
	sed -i -e "/^\\/dev\\/${vol2rm_vg[${k}]}\\/${vol2rm_name[${k}]}\\s/d"  /etc/fstab
	# Remove LVM logical volume from volume group
	# Note: this could fail if some logical volume has failed unmounting before
	lvremove -v -f -y "/dev/${vol2rm_vg[${k}]}/${vol2rm_name[${k}]}"
	${wait_cmd}
done
# Remove all configured mount points detected above (second loop for configured but not currently mounted filesystems)
# Note: this must be done in inverse mountpoint alpabetical order to guarantee successfull removing of nested mountpoints
# Note: cycling on logical volume names since some could be in use as raw volume (no corresponding mountpoint)
mnt2rmdir=$(for (( k=0; k<${#vol2rm_name[*]}; k=k+1 )); do if [ -n "${vol2rm_mnt[${k}]}" -a -d "${vol2rm_mnt[${k}]}" ]; then echo "${vol2rm_mnt[${k}]}"; fi ; done | sort -r | uniq | tr '\n' ' ' | sed -e 's/^\s*//g' -e 's/\s*$//g')
# Note: checking found mountpoints to avoid issuing an empty command
if [ -n "${mnt2rmdir}" ]; then
	rmdir ${mnt2rmdir}
fi

# Remove all non-root LVM volume groups
# Note: this could fail if some logical volume has failed unmounting/removing before
for vg_name in $(vgs --noheadings -o vg_name); do
	# Skip root volume group (does not belong to additional disk configuration)
	if [ "${vg_name}" = "${root_vg}" ]; then
		continue
	fi
	# Remove LVM volume group
	vgremove -v -y "${vg_name}"
	${wait_cmd}
done

# Remove all found LVM physical volumes
# Note: this could fail if some logical volume has failed unmounting/removing before
for (( k=0; k<${#pv2rm_dev[*]}; k=k+1 )); do
	# Remove LVM physical volume
	pvremove -v -ff -y "${pv2rm_dev[${k}]}"
	${wait_cmd}
done

# Remove all found VDO volumes
# Note: this could fail if something failed unmounting/removing before
for (( k=0; k<${#vdo2rm_name[*]}; k=k+1 )); do
	# Stop VDO volume
	vdo stop --force --verbose --name="${vdo2rm_name[${k}]}"
	${wait_cmd}
	# Remove VDO volume
	vdo remove --force --verbose --name="${vdo2rm_name[${k}]}"
	${wait_cmd}
done

# Reinitialize all non-OS disks
# Note: assuming that OS is confined to one disk and that there is no other active use for further disks (whose LVs/VGs/PVs/VDOs have been removed above)
sleep 10
for (( i=0; i<${#pv2rm_dev[*]}; i=i+1 )); do
	# Note: excluding partition vs whole-disk detection for devices under /dev/mapper
	# TODO: find a strategy to detect whole-disk vs partition
	if [ "$(dirname ${pv2rm_dev[${i}]})" = "/dev/mapper" ]; then
		base_dev="${pv2rm_dev[${i}]}"
	else
		base_dev="$(echo ${pv2rm_dev[${i}]} | sed -e 's/[0-9]*$//')"
	fi
	if [ -b "${base_dev}" ]; then
		# Clean up whole device
		dd if=/dev/zero of=${base_dev} bs=1M count=10
		dd if=/dev/zero of=${base_dev} bs=1M count=10 seek=$(($(blockdev --getsize64 ${base_dev}) / (1024 * 1024) - 10))
		${wait_cmd}
	fi
	partprobe
	${wait_cmd}
done
if [ "${has_vdo}" = "true" ]; then
	for (( i=0; i<${#vdo2rm_disk[*]}; i=i+1 )); do
	        # Note: excluding partition vs whole-disk detection for devices under /dev/mapper
	        # TODO: find a strategy to detect whole-disk vs partition
	        if [ "$(dirname ${vdo2rm_disk[${i}]})" = "/dev/mapper" ]; then
	                base_dev="${vdo2rm_disk[${i}]}"
	        else
	                base_dev="$(echo ${vdo2rm_disk[${i}]} | sed -e 's/[0-9]*$//')"
	        fi
	        if [ -b "${base_dev}" ]; then
	                # Clean up whole device
	                dd if=/dev/zero of=${base_dev} bs=1M count=10
	                dd if=/dev/zero of=${base_dev} bs=1M count=10 seek=$(($(blockdev --getsize64 ${base_dev}) / (1024 * 1024) - 10))
	                ${wait_cmd}
	        fi
	        partprobe
	        ${wait_cmd}
	done
fi

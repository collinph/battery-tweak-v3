#!/system/bin/sh


#Added Beta Code 1.0s4 for usb-ac charging variants by Decad3nce
#Battery Tweak Beta by collin_ph
#configurable options
#moved to /system/etc/batt.conf
# s0be - Added lookup table to replace math.

echo "test1"
. ../../system/etc/batt.conf
echo "test2"
if [ "$enabled" -gt "0" ] 
 then
echo "test3"
echo $audio_fix
 echo "test4"
if [ "$audio_fix" -gt "0" ]
   then
	 log "collin_ph: audiofix enabled, disabling stagefright"
	 setprop media.stagefright.enable-player false
	 else
	 log "collin_ph: audiofix disabled, enabling stagefright"
	 setprop media.stagefright.enable-player true
fi

for s in `seq 0 100`
do
  setvar Speed$s 400000
done

genSpeedTable() {

GoodSpeeds="";
GoodSpeedCount=0;

MinMaxSpeed=`expr  "(" 100 "-" $cpu_max_underclock_perc ")" "*" $max_freq_on_battery "/" 100`;
for freq in `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies`
do
  if [ "$freq" -le "$max_freq_on_battery" ] && [ "$freq" -ge "$MinMaxSpeed" ]
  then
    if [ "$GoodSpeedCount" -gt "0" ]
	then
	  GoodSpeeds="$GoodSpeeds $freq";
	else
	  GoodSpeeds="$freq"
	fi
	GoodSpeedCount=`expr $GoodSpeedCount "+" 1`;
  fi
done

log "collin_ph: Max Speeds: $GoodSpeeds"
log "collin_ph: Max Max Speed: $max_freq_on_battery"
log "collin_ph: Min Max Speed: $MinMaxSpeed"
SmallBucket=`expr 100 "%" $GoodSpeedCount`
BucketWidth=`expr 100 "/" $GoodSpeedCount`
Buckets=$GoodSpeedCount
EndBucket=1
if [ "$SmallBucket" -ne "0" ]
then
  log "collin_ph: Remaining Buckets: $BucketWidth"
  log "collin_ph: Last Bucket: $SmallBucket"
else
  log "collin_ph: All Buckets: $BucketWidth"
fi

log "collin_ph: Populating $Buckets Buckets"

SpeedIndex=$GoodSpeedCount
	  setvar Speed100 `echo $GoodSpeeds | awk '{ print $a }' -v a=$SpeedIndex`
	  eval dump=\$Speed100
	  log "collin_ph: Speed100 = $dump"

for Bucket in `seq $Buckets -1 $EndBucket`
do
	bstart=`expr 100 "-" "(" $BucketWidth "*" "(" $Buckets "-" $Bucket ")" "+" $SmallBucket  ")"`
	bend=`expr 100 "-" "(" $BucketWidth "*" "(" $Buckets "-" $Bucket "+" 1 ")" "+" $SmallBucket  ")" "+" 1 `
	for Bin in `seq $bstart -1 $bend`
	do
	  SpeedIndex=$Bucket
	  setvar Speed$Bin `echo $GoodSpeeds | awk '{ print $a }' -v a=$SpeedIndex`
	  eval dump=\$Speed$Bin
	  log "collin_ph: Speed$Bin = $dump"
	done
done

if [ "$SmallBucket" -ne "0" ]
then
	bstart=`expr $SmallBucket "-" 1`
	bend=0
	for Bin in `seq $bstart -1 $bend`
	do
	  SpeedIndex=1
	  setvar Speed$Bin `echo $GoodSpeeds | awk '{ print $a }' -v a=$SpeedIndex`
	  eval dump=\$Speed$Bin
	  log "collin_ph: Speed$Bin = $dump"
	done
else
	  SpeedIndex=1
	  setvar Speed0 `echo $GoodSpeeds | awk '{ print $a }' -v a=$SpeedIndex`
	  eval dump=\$Speed0
	  log "collin_ph: Speed0 = $dump"
fi
}
#Initialization variables
#Dont mess with these.
charging_source="unknown!"
last_source="unknown";
batt_life=0;
current_polling_interval=5;
current_max_clock=0
bias=0;
last_bias=0;
last_capacity=0;
#End of init variables
genSpeedTable;
launchMOUNToptions()
{
log "collin_ph: remounting file systems $1"

mount -o $1 / -t rootfs
mount -o $1 /dev -t devpts
mount -o $1 /proc -t proc
mount -o $1 /sys -t sysfs
mount -o $1 /mnt/asec -t tmpfs
mount -o $1 /system -t yaffs2
mount -o $1 /data -t yaffs2
mount -o $1 /cache -t yaffs2
mount -o $1 /mnt/sdcard -t vfat
mount -o $1 /mnt/secure/asec -t vfat
mount -o $1 /mnt/sdcard/.android_secure -t tmpfs
}

launchCFStweaks()
{
mount -t debugfs none /sys/kernel/debug
#NEW_WAIT_SLEEPER and GENTLE_FAIR_SLEEPERS dont exist in sched_features
#echo "NO_ASYM_GRAN" > /sys/kernel/debug/sched_features
echo "NO_NORMALIZED_SLEEPER" > /sys/kernel/debug/sched_features
echo "NO_NEW_FAIR_SLEEPER" > /sys/kernel/debug/sched_features
log "collin_ph: Changed sched_features"
echo 600000 > /proc/sys/kernel/sched_latency_ns
echo 400000 > /proc/sys/kernel/sched_min_granularity_ns
echo 2000000 > /proc/sys/kernel/sched_wakeup_granularity_ns
log "collin_ph: Changed sched epoch duration/granularity in CFS"
umount /sys/kernel/debug
}

increase_battery()
{
log "collin_ph: Increasing Battery"
#New Performance Tweaks
mount -o remount,rw -t yaffs2 /dev/block/mtdblock3
if [ $LEDfix ] 
   then
   echo 0 > /sys/class/leds/amber/brightness
   echo 0 > /sys/class/leds/green/brightness
fi
current_polling_interval=$polling_interval_on_battery;
echo 0 > /proc/sys/vm/swappiness
echo 0 > /proc/sys/vm/dirty_expire_centisecs
echo 0 > /proc/sys/vm/dirty_writeback_centisecs
echo 60 > /proc/sys/vm/dirty_background_ratio
echo 95 > /proc/sys/vm/dirty_ratio
echo 10 > /proc/sys/vm/vfs_cache_pressure
echo $max_freq_on_battery > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo $min_freq_on_battery > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 95 > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/up_threshold
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/powersave_bias
last_capacity=0;
current_max_clock=$max_freq_on_battery
genSpeedTable;;
mount -o remount,ro -t yaffs2 /dev/block/mtdblock3
log "collin_ph: Done Increasing Battery"
}

increase_performanceUSB()
{
log "collin_ph: Increasing Performance For USB Charging"

#mount -o remount,rw /
current_polling_interval=$polling_interval_on_USBpower;
echo 30 > /proc/sys/vm/swappiness
echo 1500 > /proc/sys/vm/dirty_expire_centisecs
echo 250 > /proc/sys/vm/dirty_writeback_centisecs
echo 10 > /proc/sys/vm/dirty_background_ratio
echo 40 > /proc/sys/vm/dirty_ratio
echo 10 > /proc/sys/vm/vfs_cache_pressure
echo $max_freq_on_USBpower > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo $min_freq_on_USBpower > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 45 > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/up_threshold
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/powersave_bias
last_capacity=0;
current_max_clock=$max_clock_on_USBpower
genSpeedTable;;
#mount -o remount,ro /
log "collin_ph: Done Increasing Performance on USB Charging"
}

increase_performance()
{
log "collin_ph: Increasing Performance"
#mount -o remount,rw /
current_polling_interval=$polling_interval_on_power;
echo 30 > /proc/sys/vm/swappiness
echo 3000 > /proc/sys/vm/dirty_expire_centisecs
echo 500 > /proc/sys/vm/dirty_writeback_centisecs
echo 10 > /proc/sys/vm/dirty_background_ratio
echo 40 > /proc/sys/vm/dirty_ratio
echo 10 > /proc/sys/vm/vfs_cache_pressure
echo $max_freq_on_power > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo $min_freq_on_power > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 50 > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/up_threshold
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/powersave_bias
last_capacity=0;
current_max_clock=$max_clock_on_power
genSpeedTable;;
#mount -o remount,ro /
log "collin_ph: Done Increasing Performance"
}
set_powersave_bias()
{
    capacity=`expr $capacity '*' 10`
    bias=`expr 1000 "-" $capacity`
    bias=`expr $bias "/" $battery_divisor`
    bias=`echo $bias | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}'`
    if [ "$bias" != "$last_bias" ]
       then
       log "collin_ph: Setting powersave bias to $bias"
       #mount -o remount,rw /
       echo $bias > /sys/devices/system/cpu/cpu0/cpufreq/ondemand/powersave_bias
       #mount -o remount,ro /
       last_bias=$bias;
      log "collin_ph: Done Setting powersave bias"
       
    fi

}

set_max_clock()
{
  eval temp=\$Speed$capacity
   
    if [ "$temp" != "$current_max_clock" ]
       then
       current_max_clock=$temp
       log "collin_ph: Setting Max Clock to $temp";
       echo $temp > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
       log "collin_ph: Done Setting Max Clock";
	   else
	   log "collin_ph: Not changing to $temp";
    fi
}

case $MOUNToptions in
   "1") launchMOUNToptions remount,noatime,nodiratime;;
     *) launchMOUNToptions remount,atime,diratime;;
esac

case $CFStweaks in
   "1") launchCFStweaks;;
     *) log "collin_ph: CFStweaks not enabled"
esac


while [ 1 ] 
do
charging_source=$(cat /sys/class/power_supply/battery/charging_source);
capacity=$(cat /sys/class/power_supply/battery/capacity);

sleep $current_polling_interval
if [ "$charging_source" != "$last_source" ]
  then
     last_source=$charging_source;
     log "collin_ph status= Charging Source: 1=USB 2=AC 0=Battery"
     log "collin_ph status= Charging Source: charging_source=$charging_source"
       case $charging_source in
          "0") increase_battery;;
          "1") increase_performanceUSB;;
          "2") increase_performance;;
       esac


fi


if [ "$charging_source" = "0" ]
  then
  if [ "$capacity" != "$last_capacity" ]
    then
    last_capacity=$capacity
    log "collin_ph: status = Charging Source: charging_source=$charging_source"
    case $cpu_limiting_method in
       "1") set_max_clock;;
       "2") set_powersave_bias;;
    esac

  fi
fi

done


fi #end here if enabled

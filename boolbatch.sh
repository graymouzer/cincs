somevar="samba_export_all_rw"
somevar2="cdrecord_read_content"
somevar3=""
on="=1"
off="=0"
declare -a bools
i=0
mybool=`echo $somevar`
#read -p "Do you want to  make the change persistant? Y/N ? : " YN
#if [[ $YN == "Y" ]] && [[ $mybool -ne "" ]]
#then 
	#echo $i
	bools[$i]=`echo $somevar$on`
	((i++))
#	echo $i
#fi

mybool=`echo $somevar2`
#read -p "Do you want to  make the change persistant? Y/N ? : " YN
#if [[ $YN == "Y" ]] && [[ $mybool -ne "" ]]
#then 
#	echo $i
	bools[$i]=`echo $mybool$off`
	((i++))
#		echo $i
#fi

#mybool=`echo $somevar3`
#read -p "Do you want to  make the change persistant? Y/N ? : " YN
#if [[ $YN == "Y" ]] && [[ $mybool -ne "" ]]
#then 
#	${bools[$i]}=`echo $mybool`
#	i=($i + 1)
#fi
	
#for x in "${bools[@]}"; do printf --"%s=1";done
#printf "%s=1 " "${bools[@]}"
#setsebool -P | `printf "%s=1 " "${bools[@]}"` 
setsebool -P  `echo ${bools[*]}`




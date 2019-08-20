####################################################################################################################################
####################################################################################################################################
########       			CINCS (CINCS Is Not a Configuration Script)                                               ##########
########			A utility to configure SELinux for supported services                                     ##########
########			by Jeffrey Kendrick	3/22/2014							  ##########
####################################################################################################################################
#!/bin/bash

#heading#################################   Variable Declarations   ################################################################

# variables used to check for services and configuration files
policycoreutils_Installed=Maybe
Samba_Installed=Maybe
NFS_Installed=Maybe
vsftpd_Installed=Maybe
CincsDir="/tmp/cincs"
SambaConf="/etc/samba/smb.conf"
SambaConfStatus=Maybe
# Variables used in booleans menu
DesiredState=Maybe
PersistanceFlag=Maybe

Uname=""	#variable for creating users

# Variables for setting samba file types
ShareOption1="samba_share_t"
ShareOption2="public_content_t"
ShareOption3="public_content_rw_t"

Sambabool="Maybe"
declare -a bools 
# array used to store boolean value pairs for semanage batch in samba boolean menu
#i=0 # incrementer used for bools array
#curbool="" #the name of the current boolean
on="=1"
off="=0"




#heading#################################   Functions     ###########################################################################


# function to create and refresh a file with boolean infomation which can be read more quickly than the results of the semanage command

function BoolStatus()
{
	mkdir -p $CincsDir
	rm -f $CincsDir/boolstatus.txt # Not sure why (no clobber is not set in .bashrc) but > results in an empty file
	#have to rm the file and recreate it
	echo "Generating a list of booleans and their statuses. This may take a while."
	semanage boolean -l | cat -n >> $CincsDir/boolstatus.txt
}


# function to display title, help message, SELinux mode and policy type

function DisplayHeader()
{
SEstatus=`echo $(sestatus | grep status | cut -d: -f2)`
SEmode=`getenforce`
SEPolicyType=`echo $(sestatus | grep "Policy from config file:" | cut -d: -f2)`

echo "			CINCS" 
echo "This program will help configure SELinux for selected services."
echo ""
echo "SELinux status is:" $SEstatus "  SELinux mode is:" $SEmode "  Policy Type is:" $SEPolicyType
}

# function to map unix logins to selinux users and check context ( assuming time permits)

function DisplayUsers ()
{
clear
# find the lines with underscores in them   add a header format the output of awk to columns of 20 spaces and tee the output to the screen and a file
rm -f $CincsDir/users.txt
rm -f $CincsDir/login_users.txt
semanage login -l >> $CincsDir/users.txt
semanage login -l | grep _  | awk 'BEGIN {print "Login id             SELinux User\n"}; {printf("%- 20s %- 20s\n",  $1, $2);}' | tee $CincsDir/login_users.txt

}


# function to check the context of the default, root, and system users
#In previous versions I had inserted additional text into users.txt which made the fields different. field 1 was 2 and field 2 was 9
function CheckUsers ()
{
clear
DisplayHeader
echo ""
echo "**************** Context for SELinux Users **************"
echo ""
DefaultUser=`awk '{if ($1 ~ "default" && $2 ~ "unconfined_u") print  "YES"}' $CincsDir/users.txt`
RootUser=`awk '{if ($1 ~ "root" && $2 ~ "unconfined_u") print "YES"}' $CincsDir/users.txt`
SystemUser=`awk '{if ($1 ~ "system_u" && $2 ~ "system_u") print "YES"}' $CincsDir/users.txt`
}



function GetSambaShares ()
{
if [ -e $CincsDir/sambashares.txt ]; then 
rm -f $CincsDir/sambashares.txt
fi
#Get all of the share labels and the paths to the shares in them and output those to a text file
readarray -t dirs < <( awk '               /^\[/ { gsub(/[][]/,""); gr=$0; }
/^[ \t]*path[ \t]*=/ { gsub(/^[ \t]*path[ \t]*=[ \t]*/, "" );
                print gr"|"$0; }' /etc/samba/smb.conf ) 
for x in "${dirs[@]}"; do printf -- "%s %s \n" "${x%%|*}" "${x#*|}"; done | cat -n >> $CincsDir/sambashares.txt

}
function CheckServices ()
{

echo "******** Status of Packages and Configuration Files  *************************************************************************"
rpm -q policycoreutils

if [[ $? = 0 ]]
then
   	policycoreutils_installed=Yes
	echo 	"  is installed"
else
   	policycoreutils_installed=No
	read -p "Policycoreutils_installed is required for this script. Policycoreutils is not installed. Would you like to install it now? Y/N: " Ans
		if [[ $Ans = Y ]] 
			then 
				echo "Installing policycoreutils"
				yum install -y policycoreutils
			else
				echo "Have it your way. policycoreutils will not be installed."
				echo "However, this script cannot continue. Fare the well."
				exit 1
		fi				
fi

rpm -q samba

if [[ $? = 0 ]]
	then
    		Samba_Installed=Yes
			if [ -e "$SambaConf" ]; then
				SambaConfStatus=Yes
				echo 	" is installed	and its configuration file	`echo $SambaConf` exists  "
			else
				echo " WARNING!! is installed but 		`echo $SambaConf is not present` "
			fi
	else
	    	Samba_Installed=No
		read -p " Samba is not installed. Would you like to install it now? Y/N: " Ans
			if [[ $Ans = Y ]] 
				then 
					echo "Installing Samba"
					yum install -y samba samba-client
				else
					echo "Have it your way. Samba will not be installed."
			fi				
fi

rpm -q vsftpd
if  [[  $? = 0 ]]
        then
            	vsftpd_Installed=Yes
                echo    " is installed"
        else
            	vsftpd_Installed=No
                read -p " vsftpd is not installed. Would you like to install it now? Y/N: " Ans
                        if [[ $Ans = Y ]]
                                then
                                    	echo "Installing vsftpd"  
                                        yum install -y vsftpd
                                else
                                    	echo "Have it your way. vsftpd will not be installed"
                        fi
fi
	
# Change to NFS
rpm -q nfs-utils
if  [[  $? = 0 ]]
	then 
		rpm -q nfs4-acl-tools
		if  [[  $? = 0 ]]
        		then
            			NFS_Installed=Yes
                		echo    "NFS is installed"
			else
				NFS_Installed=No
                		read -p " NFS is not installed. Would you like to install it now? Y/N: " Ans
				Ans=$(echo $Ans | tr '[:lower:]' '[:upper:]')
                	        if [[ $Ans = Y ]]
                	                then
                	                    	echo "Installing NFS"  
                	                        yum groupinstall -y "NFS file server"
                	                else
                	                    	echo "Have it your way. NFS will not be installed"
                	        fi
		fi
        else
            	NFS_Installed=No
                read -p " NFS is not installed. Would you like to install it now? Y/N: " Ans
		Ans=$(echo $Ans | tr '[:lower:]' '[:upper:]')
                        if [[ $Ans = Y ]]
                                then
                                    	echo "Installing NFS"  
                                        yum groupinstall -y "NFS file server"
                                else
                                    	echo "Have it your way. NFS will not be installed"
                        fi
fi
echo "************************************* MAIN MENU*********************************** ******************************************"
}

function SetNFSbools ()
{
								
								echo ""
								echo ""

								#curbool="samba_export_all_ro"
								echo "$curbool  is the value of curbool"
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														NFSbools[$i]=`echo $curbool$on`
														echo ${NFSbools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) NFSbools[$i]=`echo $curbool$off`
															 echo ${NFSbools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
}

function SetFTPbools ()
{
								
								echo ""
								echo ""

								echo "$curbool  is the value of curbool"
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														FTPbools[$i]=`echo $curbool$on`
														echo ${FTPbools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) FTPbools[$i]=`echo $curbool$off`
															 echo ${FTPbools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
}

#heading###########################    Main Section     ###########################################################################

# Check for root
if [ "$(id -u)" != "0" ]; then
echo "You must be root to run this script. Try SU -  and remember, with great power comes great responsibility." 1>&2
exit 1
fi

clear
DisplayHeader
echo " "
CheckServices
echo ""
echo "Checking Services..."

#Menu Loop Start

while :

	do

		DisplayHeader
		echo ""
		echo "1  Boolean menu"
		echo "2  User menu"
		echo "3  Configure SELinux for Samba"
		echo "4  Configure SELinux for NFS  (boolean configuration under development) "
		echo "5  Configure SELinux for vsFTP (not available)"
		echo "6  Switch SELinux Mode"
		echo "7  Force relabel upon reboot"
		echo "8  Exit"		
		echo ""
		echo ""
		read -p "Choose an option from the list (type the number)" OuterChoice
		

#	Start Boolean Menu	
		case $OuterChoice in
			1)	BoolStatus
				while :
					do	
						
						echo ""						
						echo "1 Build or refresh boolean list"
						echo ""
						echo "2 Show a list of all booleans"
						echo "*****Space bar to advance one page or Q to quit*****"
						echo ""
						echo "3 Search the list of booleans for a text string"
						echo ""
						echo "4 Toggle a boolean"
						echo ""
						echo "5 Go back one level"
						echo ""
						read -p "Choose an option from the list   " InnerChoice1


					
						case $InnerChoice1 in 


							1)
								BoolStatus
								;;
							2)
								awk '{print $1 "\t" $2}' $CincsDir/boolstatus.txt | less
								clear
								;;
							3)
								clear
								read -p "Enter search string:  " SearchStr
								grep $SearchStr $CincsDir/boolstatus.txt
								echo ""
								;;
							4)	read -p "Enter bool to toggle: " boolnum
								
								boolToToggle=`awk -v bool_awk=$boolnum '{if ($1 == bool_awk) print $2}' $CincsDir/boolstatus.txt`
								boolTargetState=`awk -v bool_awk=$boolnum '{if ($1 == bool_awk) print $3}' $CincsDir/boolstatus.txt | tr -d [:punct:]`
								boolTargetPstate=`awk -v bool_awk=$boolnum '{if ($1 == bool_awk) print $5}' $CincsDir/boolstatus.txt | tr -d [:punct:]`
								echo "You have chosen to toggle " $boolToToggle ".  It's current state is " $boolTargetState ".  It's persistant or default state is " $boolTargetPstate ". "
								echo ""
								DesiredState=Maybe
								PersistanceFlag=Maybe

								while [[ $DesiredState != "on" ]] && [[ $DesiredState != "off" ]]
								do 
									read -p "Type off or on for the desired state of "$boolToToggle": " DesiredState
								done
								while [[ $PersistanceFlag != "Y" ]] && [[ $PersistanceFlag != "N" ]]
								do
									echo "Would you like to make the default state match the new state for this boolean?"
									read -p "Type Y or N to choose whether the change will persist following a reboot:   " PersistanceFlag
									PersistanceFlag=$(echo $PersistanceFlag | tr '[:lower:]' '[:upper:]')
								done
									
								if [[ $PersistanceFlag == "Y" ]]
									then
										echo "We will now set a boolean and write its default state to the SELinux database. Go get a cup of coffee and maybe a magazine or two."
										setsebool -P $boolToToggle $DesiredState 
										if [[ $? -ne 1 ]]
											then
												clear
												echo "The selected boolean "$boolToToggle " has been changed to "$DesiredState " and the change  will persist between reboots. "
										else
											clear
											echo "There was a problem changing the state of this boolean."
										fi
								elif [[ $PersistanceFlag == "N" ]]
									then
										setsebool $boolToToggle $DesiredState
										if [[ $? -ne 1 ]]
											then
												clear
												echo "The selected boolean "$boolToToggle " has been changed to "$DesiredState " and the change  will not persist between reboots. "
										
										else
											echo "Invalid Input"
										fi
													
								fi
								;;
							
							5)	
								clear
								break
								;;
							esac
					done
					;;	

#	End Boolean Menu

#	Start User Menu
			
			2) 	clear
				echo "SELinux in targeted mode is more concerned with object context and less so with user contexts.."
				echo "However, three users are very important: system, root, and default."
				echo "The first two submenus will help you check the context of these users."
				echo "The next two submenus will help you create users whose abilities are restricted by SELinux."
				echo ""
				
				while :

		
					do  
						echo "1 Display context for login users"
						echo "2 Check context for login users"
						echo "3 Add a confined user"
						echo "4.Add a guest user"
						echo "5 Up one level"
						echo ""
						read -p "Choose an option from the list   " InnerChoice2
						
						case $InnerChoice2 in
						
							1)
								DisplayUsers
								;;
							2)
								CheckUsers
								echo "Default user (most regular users) correct? $DefaultUser"
								echo "Root User context correct? $RootUser"
								echo "System User context correct? $SystemUser"
								echo ""
								echo ""
								echo "Correct, here, means they map to the what they should default to. If you or another admin"
								echo "did not change them on a red hat based system you have a problem. Any files created by these users will"
								echo "have the wrong selinux context and the user may not have permissions required to perform his or her role or permissions"
								echo "beyond those needed."
								;;
							3) echo "Add a confined user"
							   echo "This option adds a confined user (mapped to user_u)."
							   echo "This means this user will not be able to use su or sudo."
							echo "You can accomplish the same thing from the command line by adding -Z guest_u to a"
							echo "useradd command."
							echo ""
							read -p "Enter the desired username:  " Uname
							/usr/sbin/useradd -Z user_u $Uname
							echo ""
							if [[ $? -eq 0 ]]
							then
								/usr/bin/passwd $Uname
							else
								echo "Error adding confined user " $Uname
							fi
								;;
							4) echo "Add a guest user"
							   echo "This option adds a guest user (mapped to guest_u)."
							   echo "This means this user will not be able to use su or sudo."
							   echo "Nor will this user be able to use the X Windows system or execute programs"
							   echo "in his home directory nor /tmp as regular users are able to do."
							echo "You can accomplish the same thing from the command line by adding -Z guest_u to a"
							echo "useradd command."
							echo ""
							read -p "Enter the desired username:  " Uname
							/usr/sbin/useradd -Z guest_u $Uname
							echo ""
							if [[ $? -eq 0 ]]
							then
								/usr/bin/passwd $Uname
							else
								echo "Error adding guest user " $Uname
							fi
								;;
							5)
								clear
								break
								;;
						esac
						done
				
				;;

#	End User Menu



#	Start Samba Menu

			3) 	clear
				echo "This Submenu configures Samba for SELinux"
				echo ""
				while :
					do
						echo "1 Get a list of samba shares and their contexts"
						echo "2 Change context of a share"
						echo "3 Boolean configuration"
						echo "4 Up one level"
						echo ""
						read -p "Choose an option from the list   " InnerChoice3
						
						case $InnerChoice3 in
							1)	clear			
								GetSambaShares
								# Now read the share names into a variable one at a time and check thier contexts
								echo "The Following shares were found. As a general rule samba shares should be of the "
								echo "type samba_share_t. Only relabel files and directories you create. "
								echo "DO NOT RELABEL SYSTEM FILES. If more than one file sharing protocol is used for" 
								echo "the same directory the context must be set to public_content_t or public_content_rw_t."
								echo ""
								while read Record
								do
									smbLabel=`echo $Record | cut -d" " -f2`					
									fpath=`echo $Record | cut -d" " -f3`
									contx=$(stat $fpath --printf=%C)
								
									echo "The directory listed in [" $smbLabel "]	" `echo $fpath` "has the context:  " $contx
								done < $CincsDir/sambashares.txt

								echo ""
								echo "This Submenu configures Samba for SELinux"
								echo ""
								;;
				
							2) 
								clear
								#echo "Label    "   "Share         \t" "  SELinux type" | column -ts
								echo ""
								while read Record
								do
									
									smbLabel=`echo $Record | cut -d" " -f2`					
									fpath=`echo $Record | cut -d" " -f3`
									contx=$(stat $fpath --printf=%C)
									ShareIdx=`echo $Record | cut -d" " -f1`
								
									 printf '%-5s %-20s %-25s %-20s\n' $ShareIdx $smbLabel  `echo $fpath`  $contx 
								done < $CincsDir/sambashares.txt
								echo ""
								read -p "Choose the number of the share whose type you wish to change: " sharenum
								ShareToChange=`awk -v share_awk=$sharenum '{if ($1 == share_awk) print $3}' $CincsDir/sambashares.txt`
								echo ""
								echo "There are many context types for directories. Only these three are usually appropriate."
								echo ""
								echo "Please take a moment to look over the descriptions"
								echo ""
								echo "1. " $ShareOption1 "This is appropriate when you just want to share the directory via samba."
								echo ""
								echo "2. " $ShareOption2 "This will allow FTP, Apache, NFS, Samba, and rsync to read the files in this directory."
								echo ""
								echo "3. " $ShareOption3 "This will allow FTP, Apache, NFS, Samba, and rsync to write to the  files in this directory."
								echo "         However, each service must have the approprate boolean turned on as well."
								echo ""
								read -p "Choose a type from the list above type the number:  " ShareChangeChoice
								case $ShareChangeChoice in
									1) SambaDirType=`echo $ShareOption1`
										;;
									2) SambaDirType=`echo $ShareOption2`
										;;
									3) SambaDirType=`echo $ShareOption3`
										;;
								esac
								echo ""
								echo "Note: A relabel occurs when SELinux has been disabled and re-enabled, when switching"
	 							echo "between policy types, or manually when an admin is attempting to correct a problem "
								echo "with application or file labels." 
								echo "" 
								read -p "Do you want make this change survive a relabel? (Not sure? choose Y)Y/N"  RelabelFlag
								RelabelFlag=$(echo $RelabelFlag | tr '[:lower:]' '[:upper:]')
								echo "You have chosen to change " $ShareToChange "to type: " $SambaDirType 
								read -p "Do you wish to proceed with this? Y/N" ShareChangeConfirm
								ShareChangeConfirm=$(echo $ShareChangeConfirm | tr '[:lower:]' '[:upper:]')
									case $ShareChangeConfirm in
										Y) if [[ $RelabelFlag -eq "Y" ]]
										 	then
												chcon -R -t $SambaDirType $ShareToChange
												semanage fcontext -a -t $SambaDirType $ShareToChange
											else
												chcon -R -t $SambaDirType $ShareToChange
											fi
											;;
										N) echo "Aborting all changes"
											;;
											
										  *) echo "Invalid Input"
											;;
									esac
								
									
								;;
				
							3) echo "Samba Boolean Configuration"
# Better safe than sorry								
								unset bools
								declare -a bools
								i=0
								echo "i is $i"
								

# samba boolean walkthrough intro					
# Main reference Red Hat's RHEL 6 Managing Confined Services
#https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Managing_Confined_Services/sect-Managing_Confined_Services-Samba-Booleans.html		
								echo ""
								echo "This menu will walk you through configuring the SELinux booleans pertaining to Samba"
								echo ""
								echo "First, if you know the boolean you would like to toggle, you should use the boolean menu."
								echo "Every Samba related boolean except qemenu _use_cifs will show up in a search of the list "
								echo "using the string 'samba'." "This menu assumes no prior knowledge but since we are changing"
								echo "SELinux it does assume you have some time on your hands."
								echo ""
								echo ""
# samba_export_all_ro
								echo "The boolean samba_export_all_ro will let samba read every file on your computer including system files"
								echo "This allows Samba to share files not labeled samba_share_t. A scenario on the Red Hat site"
								echo "that might call for this is sharing a web directory where the files are of type httpd_sys"
								echo "and the policy denies samba access. The type cannot be changed if httpd is to use them."
								echo "If both this boolean is on and samba_export_all_rw is off, write access to samba shares"
								echo "is disabled, even if it is explicitly allowed in smb.conf and through Linux permissions."
								echo ""
								echo ""

								curbool="samba_export_all_ro"
					
								echo "If you would like samba to be able to read  all the files on your system type the number of your selection: : "
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
# samba_export_all_rw	

								echo "The boolean samba_export_all_rw will allow any file or directory to be exported with read" 									echo "and write permissions."
								echo "Dan Walsh, the head of the SELinux project at Red Hat, notes that a "
								echo "compromised server would be 'very dangerous'. However, for someone to write to the files"
								echo "share permissions in smb.conf and Linux permissions would have to permit it."
								echo ""
								curbool="samba_export_all_rw"

echo "If you would like samba to be able to read  all the files on your system type the number of your selection: : "
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														 break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool samba_export_all_ro 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
								done
# allow_smbd_anon_write
								
								
								echo ""
								echo ""
								echo ""
								echo "When you create a directory and confgure it to be shared by multiple"
								echo "file sharing services such as ftp, nfs, and samba by giving it the type"
								echo "public_content_rw_t, Samba still needs this boolean enabled in order to "
								echo "write to it. This is for public directories containing commmon files with"
								echo "no special access restrictions. Caution! Many people mispell this boolean"
								echo "It is allow_smbd_anon_write NOT allow_smb_anon_write."
								echo ""
								echo ""
curbool=allow_smbd_anon_write
echo "If you would like samba to be able to read  all the files on your system type the number of your selection: : "
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														 break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool samba_export_all_ro 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
								
									done

# cdrecord_read_content

					
					boolPrompt="If you would like the cdrecord command be able to read  Samba (and other network) files on your system choose Yes. Type the number of your selection:"
								
								echo ""
								echo ""
								echo "This one is pretty straightforward."

								curbool="cdrecord_read_content"
					
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					

#qemu_use_cifs
					echo "This boolean controls KVM's access to CIFS or Samba file systems. KVM is the VM supported by RHEL. On by default."
					echo "If you don't know, leave it on."
					
					boolPrompt="Would you like KVM to be able to read  the files on your Samba file system ? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="qemu_use_cifs"
					
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
# samba_create_home_dirs
					
					boolPrompt=" Do you want Samba to be able to create home directories independently? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="samba_create_home_dirs"
					
								echo "Enabling this boolean allows Samba to create home directories independently, usually via PAM." 
								echo "This is disabled by default."
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
# samba_domain_controller					

								boolPrompt=" Do you want to allow Samba to act as a domain controller? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="samba_domain_controller"
								echo "This boolean allows Samba to act as a domain controller. It also gives it permission "
								echo "to execute related commands such as useradd, groupadd, and passwd. This may be just what"
								echo "you want to do, but be aware that this gives Samba the ability to manipulate the password"
								echo "database."
								echo "$boolPrompt"		
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
# samba_run_unconfined
							
					
					boolPrompt=" Do you want to allow samba to run unconfined? The default is no.Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="samba_run_unconfined"
								echo "Some background from the fedora SELinux documentation will help here."
								echo "Unconfined processes run in unconfined domains. Unconfined programs run in"
								echo "initrc_t domain, unconfined kernel processes run in kernel_t and unconfined users in"
								echo "unconfined_t domain. So what does this mean? For unconfined processes, SELinux rules "
								echo "apply but policy rules allow unconfined domains almost all access. We are back to relying"
								echo "on DAC rules for security. The scripts in /var/lib/samba/scripts may need this access."
								echo ""
								echo "These scripts include things like netlogon scripts, shutdown scripts, and root preexec" 									echo "scripts that do things like create home directories."
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
									
# samba_enable_home_dirs	
					boolPrompt=" Would you like to allow Samba to share user's home directories? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="samba_enable_home_dirs"
								echo "If enabled you will need to use DAC measures such as share, file and directory permissions"
								echo "control access."
								echo ""
								echo ""
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
# samba_share_fusefs
					boolPrompt=" Would you like to let Samba share fusefs file systems? Type the number of your selection:"
								
								echo ""
								echo ""
								echo "Fusefs is a filesystem in user space. This means it can be implemented by"
								echo "nonroot users and is a very common way for unix-like OSs to mount NTFS."
								echo " Ports exist for Linux, BSD, Amazon S3, Oracle,"
								echo "android, and Mac OSX. It is off by default. It must be enabled if you use fusefs."
								curbool="samba_share_fusefs"
					
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
# samba_share_nfs

					
					boolPrompt="Would you like to allow Samba to share NFS volumes? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="samba_share_nfs"
								echo "If disabled smbd will not have full access to NFS shares. If enabled, you can share NFS" 
								echo "volumes via Samba."
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""

# use_samba_home_dirs

					
					boolPrompt=" Do you want to allow Samba to use a remote server for home directories? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="use_samba_home_dirs"
								echo "Enable this boolean to use a remote server for home directories."
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					
# virt_use_samba

					
					boolPrompt="Do you want to allow VMs to access files mounted via CIFS? Type the number of your selection:"
								
								echo ""
								echo ""

								curbool="virt_use_samba"
								echo "There is no special security concern here but it's worth noting that Red Hat's"
								echo "virtualization security guide recommends limiting access to entire file systems."
								echo "For example, it is better to limit access to a partition rather than to allow it"
								echo "for an entire device if that access is not needed." "If a host hypervisor were "
								echo "compromised an attacker would have access to any network resources any guest VM had."
								echo "So, if the VM needs access enable it, if not don't."
								echo "$boolPrompt"
								select YN in Yes No
								 do
									case $YN in
										Yes) echo "Do you want this setting (on) to persist between reboots?"
											select YN in Yes No
											 do
												case $YN in 
													Yes) 
														bools[$i]=`echo $curbool$on`
														echo ${bools[$i]} "will be written"
														((i++))
														break
														;;
													No) 
														echo "Setting boolean to on"
														setsebool $curbool 1 
															echo "$curbool set to on"
													 	break
														;;
											
												esac
											done
										break
											;;
										No) 
											echo "Do you want this setting (off) to persist between reboots?"
												select YN in Yes No
											 	do
													case $YN in
														Yes) bools[$i]=`echo $curbool$off`
															 echo ${bools[$i]} "will be written"
															((i++))
															break
															;;
														No) echo "Setting boolean to off"
															setsebool $curbool 0 && echo "$curbool set to off"	
															break
															;;

													esac
												done
											break
												;;
											esac
										done
								echo ""
								echo ""
					

					







								echo "The following values will be written to SELnux : " ${bools[*]}
								echo "The ones indicate the boolean will be switched on and the zeros off."
								echo "This process will fail if a boolean has been removed from the current policy."
								echo ""
								echo "Starting batch process for persistant boolean writes..."
								echo "This will take from one and a half to three minutes."
					
								setsebool -P  `echo ${bools[*]}` 
								echo ""
								echo "Batch process complete!"
								echo ""
								echo ""

# samba boolean section ends here								
								;;			
				
							4) clear
								break
								;;
								
						esac
					done
				
# last line of Samba section				
				;;
# Note NFS Boolean Configuration is still in development
# Several booleans appear to have been removed from RHEL and I need to do additional research to find out why they no longer appear
#	Start NFS Menu
			4) echo "Configure NFS"
				while :
					do
						echo "1 View exports"
						echo "2 Boolean configuration"
						echo "3 Batch write for NFS Booleans"
						echo "4 Up one level"
						echo ""
						read -p "Choose an option from the list   " InnerChoice4
						
						case $InnerChoice4 in
							1)	clear	
								echo "There is usually no reason to give a special SELinux context to an NFS share."
								echo "But it is convenient to be able to see them here and compare them to /etc/exports."							
								echo "Output of showmount -e localhost:"
								echo ""
								showmount -e localhost
								echo ""
								echo "Output of cat /etc/exports:"
								cat /etc/exports

								echo "Note: If you can't get NFS to export your shares, check tcpwrappers before SELinux."
								echo "It's easy enough to set SELinux to permissive but more likely you need to add a line to"
								echo "/etc/hosts.allow"
								;;
							2) clear
								i=0
								declare -a NFSbools
								curbool="allow_gssd_read_tmp"								
								boolPrompt="Do you want to allow the General Security Services daemon to be able to read temporary directories and help protect NFS? Type the number of your selection:"
								 SetNFSbools
								curbool="httpd_use_nfs"								
								boolPrompt="Do you want Apache to be able to access nfs? Type the number of your selection:"
								 SetNFSbools
								curbool="cdrecord_read_content"								
								boolPrompt="Do you want cdrecord to be able  access nfs monunted directories? Type the number of your selection:"
								 SetNFSbools
								curbool="allow_ftpd_use_nfs"								
								boolPrompt="Do you want FTP servers to be able to use shared NFS directories? Type the number of your selection:"
								 SetNFSbools
								curbool="git_system_use_nfs"								
								boolPrompt="Do you want the git revision control system to be able to access nfs? Type the number of your selection:"
								 SetNFSbools
								curbool="nfs_export_all_ro"								
								boolPrompt="Do you want to allow read only acccess to NFS shares? Type the number of your selection:"
								 SetNFSbools
								curbool="nfs_export_all_rw"								
								boolPrompt="Do you want to allow read write access to NFS shares Type the number of your selection:"
								 SetNFSbools
								curbool="allow_nfs_home_dirs"								
								boolPrompt="Do you wantto enable the mounting of /home on remote NFS servers? Type the number of your selection:"
								 SetNFSbools
								curbool="qemu_use_nfs"								
								boolPrompt="Do you want to enable the use of the quick emulator to NFS mounted file systems? Type the number of your selection:"
								 SetNFSbools
								curbool="allow_nfsd_anon_write"								
								boolPrompt="Do you want to allow NFS to modify files shared by multiple network file sharing services (FTP Samba)? Type the number of your selection:"
								 SetNFSbools
								curbool="samba_share_nfs"								
								boolPrompt="Do you want to allow Samba to share NFS mounted directories? Type the number of your selection:"
								 SetNFSbools
								curbool="virt_use_nfs"								
								boolPrompt="Should VMs be able to access nfs? Type the number of your selection:"
								 SetNFSbools
								curbool="xen_use_nfs"								
								boolPrompt="Do you to allow the Xen virtual machine monitor to be able to access nfs? Type the number of your selection:"
								SetNFSbools								
								;;
							3) echo "Writing persistant booleans for service NFS"
								echo "The following values will be written to SELnux : " ${NFSbools[*]}
								echo "The ones indicate the boolean will be switched on and the zeros off."
								echo "This process will fail if a boolean has been removed from the current policy."
								echo ""
								echo "Starting batch process for persistant boolean writes..."
								echo "This will take from one and a half to three minutes."
					
								setsebool -P  `echo ${NFSbools[*]}` 
								echo ""
								echo "Batch process complete!"
								echo ""
								echo ""
								;;
							4) break
								;;
								 
									
						esac
					done

				;;
			5) echo "Configure vsFTP"
				while :
				do
					echo "1 View user_list file"
					echo "2 View vsftpd.conf **  Q to quit  space bar for next page **"
					echo "3 Boolean configuration"
					echo "4 Batch write for NFS Booleans"
					echo "5 Up one level"
					read -p "Choose an option from the list   " InnerChoice5
						
					case $InnerChoice5 in
						1) echo ""
							echo ""
							cat /etc/vsftpd/user_list
							echo ""
							echo ""
							;;
						2) less /etc/vsftpd/vsftpd.conf
							echo ""
							echo ""
						
							;;
						3)		
								i=0
								declare -a FTPbools
								curbool="allow_ftpd_anon_write"								
								boolPrompt="Do you want to set up directories where anonymous users can write files? Type the number of your selection:"
								SetFTPbools
								curbool="allow_ftpd_full_access"								
								boolPrompt="Do you want to users access to all files on the server via FTP? Type the number of your selection:"
								SetFTPbools
								curbool="ftp_home_dir"								
								boolPrompt="Do you want regular users to have full access to their home directories? Type the number of your selection:"
								SetFTPbools
								;;
						4) echo "Writing persistant booleans for service NFS"
							echo "The following values will be written to SELnux : " ${FTPbools[*]}
							echo ""
							echo "The ones indicate the boolean will be switched on and the zeros off."
							echo ""
							echo "This process will fail if a boolean has been removed from the current policy."
							echo ""
							echo "Starting batch process for persistant boolean writes..."
							echo "This will take from one and a half to three minutes."
				
							setsebool -P  `echo ${FTPbools[*]}` 
							echo ""
							echo "Batch process complete!"
							echo ""
							echo ""
								;;
						5) break
							;;
					esac
				done
				;;

			6) echo "Select the desired mode for SELinux"
				echo "Permissive is for troubleshooting. Set to Enforcing as soon as possible."
				echo "Do not disable SELinux"
				select EP in Enforcing Permissive
				do
					case $EP in
						Enforcing) echo "SELinux policies will be enforced"
								setenforce 1
								getenforce
								break
								;;
						Permissive) echo "SELinux policies will not be enforced but exceptions will be logged"
								setenforce 0
								getenforce
								break
								;;
					esac
				done
				;;

			7) echo "Do you want to set the system to relabel SELinux file contexts upon reboot? Choosing No returns to Main Menu."
				select YN in Yes No

				 do
					case $YN in 
						Yes) touch /.autorelabel
							echo "The system will be relabel upon reboot."
							break
							;;
						No) echo "Relabel canceled"
							break
							;;
					esac
				done
				;;

			8) 	clear
				echo "Exiting CINCS"
				break 
				;;
		esac
	done
# use either service servicename status, chkconfig, or rpm to see if a service is installed 
# this snippet can check for a specific run level what services are running # chkconfig | awk ''$5 ~ /on/ {print $1}''
# I want a command or loop that can output just the run levels my specified services are running at
# Desired output: Service Foo is enabled and on for run levels 3,4,5 

#
#	FTP
#	apply to FTP (default is vsFTP) not to sftp
#allow_ftpd_anon_write	#prompt if they want to allow uploads from anonymous users

#allow_ftpd_full_access	#prompt if user wants to allow full access to all directories shared beyond those with public_content_rw_t context and home directories if enabled

#allow_ftpd_use_cifs	#check if there are any mounted samba shares and prompt if the user wants to allow ftp access to them

#allow_ftpd_use_nfs	#check if there are any nfs mounts an prompt user if they want to allow ftp access to them

#ftpd_connect_db	#Prompt if user wants ftp server to be able to initiate connections to a database server. Often used for storing authentication info.

#ftp_home_dir	#Do you want users to be able to access their home directories through ftp?


#
#	NFS
#
#cdrecord_read_content # prompt if the user wants to allow cdrecord to access 

# option 2A choose a service from the list
# option 2B choose a boolean
	# option  view it or change it or more info or up a level
# option 3 view changes recommended based on parsing the config files for those services

# option 4 view the file contexts of a selected service and reccomended changes

#option 5 quit


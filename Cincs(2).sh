####################################################################################################################################
####################################################################################################################################
########       			CINCS (CINCS Is Not a Configuration Script)                                               ##########
########			A utility to configure SELinux for supported services                                     ##########
########			by Jeffrey Kendrick	3/22/2014							  ##########
####################################################################################################################################
#!/bin/bash

#heading#################################   Variable Declarations   ################################################################

# varibales used to check for services and configuration files
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
declare -a bools # array used to store boolean value pairs for semanage batch in samba boolean menu
i=0 # incrementer used for bools array
curbool="" #the name of the current boolean
on="=1"
off="=0"

# Variables for batch setting of persistance flag in samba boolean menu
allow_smb_anon_write_PFlag="allow_smb_anon_write=1"
cdrecord_read_content_PFlag="cdrecord_read_content=1"
qmenu_use_cifs_PFlag="qmenu_use_cifs=1"
samba_create_home_dirs_PFlag="samba_create_home_dirs=1"
samba_domain_controller_PFlag="samba_domain_controller=1"
samba_enable_home_dirs_PFlag="samba_enable_home_dirs=1"
samba_export_all_ro_PFlag="samba_export_all_ro=1"
samba_export_all_rw_PFlag="samba_export_all_rw=1"
samba_run_unconfined_PFlag="samba_run_unconfined=1"
samba_share_fusefs_PFlag="samba_share_fusefs=1"
samba_share_nfs_PFlag="samba_share_nfs=1"
use_samba_home_dirs_PFlag="use_samba_home_dirs=1"
virt_use_samba_PFlag="virt_use_samba=1"

# an odd naming convention, I know, but I need  variables for a seperate array in the case that the user wants the boolean off and the change to persist
allow_smb_anon_write_PFlag_off="allow_smb_anon_write=0"
cdrecord_read_content_PFlag_off="cdrecord_read_content=0"
qmenu_use_cifs_PFlag_off="qmenu_use_cifs=0"
samba_create_home_dirs_PFlag_off="samba_create_home_dirs=0"
samba_domain_controller_PFlag_off="samba_domain_controller=0"
samba_enable_home_dirs_PFlag_off="samba_enable_home_dirs=0"
samba_export_all_ro_PFlag_off="samba_export_all_ro=0"
samba_export_all_rw_PFlag_off="samba_export_all_rw=0"
samba_run_unconfined_PFlag_off="samba_run_unconfined=0"
samba_share_fusefs_PFlag_off="samba_share_fusefs=0"
samba_share_nfs_PFlag_off="samba_share_nfs=0"
use_samba_home_dirs_PFlag_off="use_samba_home_dirs=0"
virt_use_samba_PFlag_off="virt_use_samba=0"
tmpbool="" # just recieves a Y or N before it's converted to uppercase


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
semanage login -l | grep _  | awk 'BEGIN {print "Login id             SELinux User\n"}; {printf("%- 20s %- 20s\n",  $1, $2);}' | tee $CincsDir/users.txt
echo ""
echo ""
}


# function to check the context of the default, root, and system users

function CheckUsers ()
{
 DefaultUser=`awk '{if ($2 ~ "default" && $9 ~ "unconfined_u") print  "YES"}' $CincsDir/users.txt`
 RootUser=`awk '{if ($2 ~ "root" && $9 ~ "unconfined_u") print "YES"}' $CincsDir/users.txt`
 SystemUser=`awk '{if ($2 ~ "system_u" && $9 ~ "system_u") print "YES"}' $CincsDir/users.txt`
}

function CheckServices ()
{

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
#				# Now read the share names into a variable one at a time and check thier contexts
#				echo "The Following shares were found. As a general rule samba shares should be of the "
#				echo "type samba_share_t. "
#				while read Record
#				do
#					fpath=`echo $Record | cut -d: -f2`
#					contx=$(stat $fpath --printf=%C)
#				done < $CincsDir/sambashares.txt

}


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
echo "************************************* MAIN MENU*********************************** ******************************************"
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
echo "Generating a list of services"


#Menu Loop Start

while :

	do


		echo "1  Boolean menu"
		echo "2  User menu"
		echo "3  Configure SELInux for vsFTP"
		echo "4  Configure SELinux for NFS"
		echo "5  Configure SELInux for Samba"
		echo "6  Force relabel upon reboot"
		echo "7  Exit"		
		echo ""
		echo ""
		read -p "Choose an option from the list (type the number)" OuterChoice
		

#	Start Main Menu	
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
								echo "Default user (most regular users) correct?" $DefaultUser
								echo "Root User context correct?" $RootUser
								echo "System User context correct?" $SystemUser
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
						DisplayUsers
				
				;;

#	End User Menu

#	Start NFS Menu
			3) echo "Configure NFS"
				;;
			4) echo "Configure vsFTP"
				;;

#	Start Samba Menu

			5) 	clear
				echo "This Submenu configures Samba for SELinux"
				echo ""
				while :
					do
						echo "1 Get a list of samba shares and their contexts"
						echo "2 Change context of a share"
						echo "3 Boolean configuration"
						echo "4 Exit"
						echo ""
						read -p "Choose an option from the list   " InnerChoice5
						
						case $InnerChoice5 in
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
								read -p "Do you want make this change survive a relabel? (Not sure? choose Y)Y/N" RelabelFlag
								echo "You have chosen to change " $ShareToChange "to type: " $SambaDirType "and said chose " $RelabelFlag 
								read -p "Do you wish to proceed with this? Y/N" ShareChangeConfirm
									case $ShareChangeConfirm in
										Y) if [[ $RelabelFlag == "Y" ]]
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
								echo "and the policy denies samba access. The type cannot be changed if httpd is to use them"
								echo "If both this boolean is on and samba_export_all_rw is off, write access to samba shares"
								echo "is disabled, even if it is explicitly allowed in smb.conf and through Linux permissions."
								echo ""
								i=0
								curbool="samba_export_all_ro"
								while [[ $Samabool != "Y" ]] && [[ $Samabool != "N" ]]
								do
									read -p "If you would like samba to be able to read  all the files on your system type Y: " tmpbool
									Samabool=`echo $tmpbool | tr '[:lower:]' '[:upper:]'`
									tmpbool=""
								done
#								if [[ $Samabool == "Y" ]]
#									then
									while [[ $PersistanceFlag != "Y" ]] && [[ $PersistanceFlag != "N" ]]
									do
									read -p "Would you like to make this change persistant between reboots type Y or N: " tmpbool
									PersistanceFlag=`echo $tmpbool | tr '[:lower:]' '[:upper:]'`
									tmpbool=""
									done
								if [[ $PersistanceFlag == "Y" ]]
									then
										if [[ $Sambabool == "Y" ]]
											then 
												bools[$i]=`echo $curbool$on`
										elif [[ $Sambabool == "N" ]]
											then
												bools[$i]=`echo $curbool$off`
										fi
								else
									if [[ $Samabool == "Y" ]] 
										then
											echo "Setting boolean to on"
											setsebool samba_export_all_ro 1 && echo "$curbool set to on"
										else
											echo "Setting boolean to off"
											setsebool samba_export_all_ro 0 && echo "samba_export_all_ro set to off"
									fi
								fi
								((i++))
#								while [[ $Samabool != "Y" ]] && [[ $Samabool != "N" ]]
#								do
#									read -p "If you would like samba to be able to read all the files on your system type Y: " tmpbool
#									Samabool=`echo $tmpbool | tr '[:lower:]' '[:upper:]'`
#								done
#								if [[ $Samabool == "Y" ]]
#									then
#										echo "Setting boolean to on"
#										setsebool -P samba_export_all_ro 1 && echo "samba_export_all_ro set to on"
#									else
#										echo "Setting boolean to off"
#										setsebool -P samba_export_all_ro 0
#								fi
										

								tmpbool="Maybe"	
								Samabool="Maybe" #reset the variables so we don't get unexpected results if we reenter the menu
# samba_export_all_rw
								echo "The boolean samba_export_all_rw will allow any file or directory to be exported with read" 									echo "and write permissions."
								echo "Dan Walsh, the head of the SELinux project at Red Hat, notes that a "
								echo "compromised server would be 'very dangerous'. However, for someone to write to the files"
								echo "share permissions in smb.conf and Linux permissions would have to permit it."
								echo ""
								curbool="samba_export_all_rw"
								while [[ $Samabool != "Y" ]] && [[ $Samabool != "N" ]]
								do
									read -p "If you would like samba to be able to read and write all the files on your system type Y: " tmpbool
									Samabool=`echo $tmpbool | tr '[:lower:]' '[:upper:]'`
									tmpbool=""
								done
#								if [[ $Samabool == "Y" ]]
#									then
								while [[ $PersistanceFlag != "Y" ]] && [[ $PersistanceFlag != "N" ]]
								do
								read -p "Would you like to make this change persistant between reboots type Y or N: " tmpbool
								PersistanceFlag=`echo $tmpbool | tr '[:lower:]' '[:upper:]'`
								tmpbool=""
								done
								if [[ $PersistanceFlag == "Y" ]]
									then
										if [[ $Sambabool == "Y" ]]
											then 
												bools[$i]=`echo $curbool$on`
												
										elif [[ $Sambabool == "N" ]]
											then
												bools[$i]=`echo $curbool$off`
										fi
								else
									if [[ $Samabool == "Y" ]] 
										then
											echo "Setting boolean to on"
											setsebool samba_export_all_rw 1 && echo "$curbool set to on"
										else
											echo "Setting boolean to off"
											setsebool samba_export_all_rw 0 && echo "samba_export_all_rw set to off"
									fi
								fi
								
								tmpbool="Maybe"
								Samabool="Maybe" #reset the variables so we don't get unexpected results if we reenter the menu
							#	sleep 2
# allow_smbd_anon_write
#								echo "When you create a directory and confgure it to be shared by multiple"
#								echo "file sharing services such as ftp, nfs, and samba by giving it the type"
#								echo "public_content_rw_t, Samba still needs this boolean enabled in order to "
#								echo "write to it. This is for public directories containing commmon files with"
#								echo "no special access restrictions. Caution! Many people mispell this boolean"
#								echo "It is allow_smbd_anon_write NOT allow_smb_anon_write."

#								while [[ $Sambabool3 != "Y" ]] && [[ $Sambabool3 != "N" ]]
#								do
#									read -p "If you would like samba to be able to read and write to public directories on your system type Y: " tmpbool
#									Sambabool3=`echo $tmpbool | tr '[:lower:]' '[:upper:]'`
#								done
#								if [[ $Sambabool3 == "Y" ]]
#									then
#										echo "Setting boolean to on"
#										setsebool -P allow_smbd_anon_write 1 && echo "allow_smbd_anon_write set to on"
#									else
#										echo "Setting boolean to off"
#										setsebool -P allow_smbd_anon_write 0 && echo "allow_smbd_anon_write set to off"
#								fi
#								tmpbool="Maybe"
#								Sambabool3="Maybe" #reset the variables so we don't get unexpected results if we reenter the menu
#								sleep 2

								echo ${bools[*]}
								setsebool -P  `echo ${bools[*]}`
								;;			
				
							4) clear
								break
								;;
								
						esac
					done
				
				# Get rid of any old sambashares lists
#				if [ -e $CincsDir/sambashares.txt ]; then 
#				rm -f $CincsDir/sambashares.txt
#				fi
#				#Get all of the share labels and the paths to the shares in them and output those to a text file
#				readarray -t dirs < <( awk '               /^\[/ { gsub(/[][]/,""); gr=$0; }
#                        	/^[ \t]*path[ \t]*=/ { gsub(/^[ \t]*path[ \t]*=[ \t]*/, "" );
#                                               print gr"|"$0; }' /etc/samba/smb.conf ) 
#				for x in "${dirs[@]}"; do printf -- "%s: %s \n" "${x%%|*}" "${x#*|}"; done >> $CincsDir/sambashares.txt
#				

				#Now that the above more or less works we need to offer to change it
				
				;;

			6) echo "Code to force relabel"
				;;

			7) 	clear
				echo "Exiting CINCS"
				break 
				;;
		esac
	done
# use either service servicename status, chkconfig, or rpm to see if a service is installed 
# this snippet can check for a specific run level what services are running # chkconfig | awk ''$5 ~ /on/ {print $1}''
# I want a command or loop that can output just the run levels my specified services are running at
# Desired output: Service Foo is enabled and on for run levels 3,4,5 

#This might be useful for showing a list of runlevels but needs more work ## pretty happy to have it this far along though
#
## chkconfig | awk 
#{for(i=0; i<=NF; ++i){ if ($i ~ /on/)  print $i}}






#check the existance of the conf file for that service and set a variable based on that

# Generate a list for the main menu of services installed and with config files and use a while loop to choose between the following

# option 1 view all booleans on the system
# option 2 view booleans for supported services
#	Apache
#		allow_httpd_anon_write
#		allow_httpd_mod_auth_ntlm_winbind
#		allow_httpd_mod_auth_pam
#		allow_httpd_sys_script_anon_write
#		httpd_builtin_scripting
#		httpd_can_check_spam
#		httpd_can_network_connect
#		httpd_can_network_connect_cobbler
#		httpd_can_network_connect_db

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






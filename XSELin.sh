#	A utility to configure SELinux for supported services
#	by Jeffrey Kendrick	3/22/2014

#!/bin/bash

# Variable Declarations

Samba_Installed=Maybe


# function to create and refresh a file with boolean infomation which can be read more quickly than the results of the semanage command
function BoolStatus()
{
	mkdir -p /tmp/cincs
	rm -f /tmp/cincs/boolstatus.txt # Not sure why (no clobber is not set in .bashrc) but > results in an empty file
	#have to rm the file and recreate it
	echo "Generating a list of booleans and their statuses. This may take a while."
	semanage boolean -l >> /tmp/cincs/boolstatus.txt
}


#	function to display title, help message, SELinux mode and policy type
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

#	function to map unix logins to selinux users and check context ( assuming time permits)
function DisplayUsers
{
semanage login -l | grep _  | awk '{print "User " $1 "		is running with the security context  	" $2}'
}

function CheckServices
{
 rpm -q samba

if [ $?=0 ]
then
    	Samba_Installed=Yes
else
    	Samba_Installed=No
fi


}


DisplayHeader
echo " "
echo ""
echo "Generating a list of services"



while :

	do


		echo "1  Boolean menu"
		echo "2  Configure SELInux for Samba"
		echo "3  Configure SELinux for NFS"
		echo "4  Configure SELInux for vsFTP"
		echo "5  Force relabel upon reboot"
		echo "6  Exit"		
		echo ""
		echo ""
		read -p "Choose an option from the list (type the number)" OuterChoice
		

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
						echo "4 Go back one level"
						echo ""
						read -p "Choose an option from the list   " InnerChoice1

						case $InnerChoice1 in 


							1)
								BoolStatus
								;;
							2)
								less /tmp/cincs/boolstatus.txt	
								clear
								;;
							3)
								read -p "Enter search string:  " SearchStr
								grep $SearchStr /tmp/cincs/boolstatus.txt
								echo ""
								;;
							4)
								clear
								break
								;;
							esac
					done
					;;	

			
			2) 	clear
				while :

		
					do  
						echo "1 Display context for users"
						echo "2 Check context for users"
						echo "3 Exit"
						echo ""
						read -p "Choose an option from the list   " InnerChoice2
						
						case $InnerChoice2 in
						
							1)
								DisplayUsers
								;;
							2)
								echo "Code to check context goes here"
								;;
							3) 
								clear
								break
								;;
						esac
						done
						DisplayUsers
				#echo "Configure Samba"
				;;

			3) echo "Configure NFS"
				;;
			4) echo "Configure vsFTP"
				;;
			5) echo "Code to force relabel"
				;;
			6) 	clear
				echo "Exiting CINCS"
				break ;;
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






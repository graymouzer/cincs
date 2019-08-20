#	A utility to configure SELinux for supported services
#	by Jeffrey Kendrick	3/22/2014

#!/bin/bash

#	function to display title, help message, SELinux mode and policy type
function DisplayHeader()
{
SEstatus=`echo $(sestatus | grep status | cut -d: -f2)`
SEmode=`getenforce`
SEPolicyType=`echo $(sestatus | grep "Policy from config file:" | cut -d: -f2)`
echo "			XSELin"
echo "This program will help configure SELinux for selected services."
echo ""
echo "SELinux status is:" $SEstatus "  SELinux mode is:" $SEmode "  Policy Type is:" $SEPolicyType
}
clear
DisplayHeader
echo ""
echo "Generating a list of services"
# use either service servicename status, chkconfig, or rpm to see if a service is installed 


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

# option 2A choose a service from the list
# option 2B choose a boolean
	# option  view it or change it or more info or up a level
# option 3 view changes recommended based on parsing the config files for those services

# option 4 view the file contexts of a selected service and reccomended changes

#option 5 quit






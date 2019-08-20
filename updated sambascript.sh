    Files
    Photos
    Sharing
    Links
    Events
    Upgrade
    Try Dropbox for Business!

    Start with 1000GB for 5 people

    Help
    Privacy

Dropbox
Search

    Upload…
    New folder
    Share a folder…
    Show deleted files

6 KB sambascript.bak.sh

sambascript.sh
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
97
98
99
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118
119
120
121
122
123
124
125
126
127
128
129
130
131
132
133
134
135
136
137
138
139
140
141
142
143
144
145
146
147
148
149
150
151
152
153
154
155
156
157
158
159
160
161
162
163
164
165
166
167
168
169
170
171
172
173
174
175
176
177
178
179
180
181
182
183
184
185
186
187
188
189
190
191
192
193
194
195
196
197
198
199
200
201
202
203
204
205
206
207
208
209
210
211
212
213
214
215
216
217
218
219
220
221
222
223
224
225
226
227
228
229
230
231
232
233
234
235
236
237
238
239
240
	
#!/bin/bash
#Title: sambascript.sh
#Created by J.T. Webb on February 7, 2014
#This script will install Samba and configure appropriate settings. 
    
#Declare the variables
declare samba_config
declare user
declare vuser
declare path
declare share
declare pub
#Set the values of the variables
samba_config=/etc/samba/smb.conf
user=user
vuser=vuser
path=path
share=share
pub=public
checkrpm=`rpm -q samba samba-client`
samba_update=`yum list samba samba-client`
#Find out if Samba is installed and which version of Samba is installed.
echo "Hello! How are you today?"
PS3="Please enter your choice: " #Used by select statement to set the text to prompt
options=( "Install Samba" "Update Samba" "Uninstall Samba" "Exit")  #Creates the options array
select opt in "${options[@]}"    #Selects determining value from options array
do
    case $opt in
        "Install Samba") echo "You have chosen to install Samba"
                         read -p "Do you want to continue? " YesNo
                         if [[ $YesNo = "Yes" || $YesNo = "yes" ]]   #Input can be "Yes" or "yes". Case does not matter.
                        then
                            yum install -y samba && yum install -y samba-client
                            echo "Installation of samba and samba-client has been successful!!"
                        elif [[ $YesNo = "No" || $YesNo = "no" ]]  #Input can be "No" or "no". Case does not matter.
                            then
                        #Exits the entire script        
                        echo "Installation of samba and samba-client failed. Exiting..."
                        exit 1
                        fi
                        break
                        ;;
        "Update Samba") echo "You have chosen to upgrade Samba."
                        echo "Your current Samba version is $checkrpm"   #Checks to see which version of Samba is installed
                        echo "These are the available packages you need to update"   #Checks to see which packages are available to update
                        echo $samba_update
                          
                  ;;
        "Uninstall Samba") echo "You have chosen to uninstall Samba."
                           read -p "Are you sure you want to delete? " YesNo
                           if [[ $YesNo = "Yes" || $YesNo = "yes" ]]
                           then
                                yum remove -y samba samba-client      #Uninstalls Samba
                                echo "Samba has been uninstalled"
                                echo " "
                                ;;
        "Exit") echo "Will exit..."
                exit
                ;;
        *) echo "Invalid option. Please choose between services [1-4]"
           ;;
    esac
done
  
#Ask the user if they want to continue
#read -p "Do you want to continue? " YesNo
#if [[ $YesNo = "Yes" || $YesNo = "yes" ]]   #Input can be "Yes" or "yes". Case does not matter.
#then
#        yum install -y samba && yum install -y samba-client
#        echo "Installation of samba and samba-client has been successful!!"
#elif [[ $YesNo = "No" || $YesNo = "no" ]]  #Input can be "No" or "no". Case does not matter.
#then
#Exits the entire script        
#        echo "Installation of samba and samba-client failed. Exiting..."
#        exit 1
#fi
  
#checkrpm=`rpm -q samba samba-client`
#echo 
#Install SELinux Management if it's not already intsalled.
echo "-----SELinux Managament will now install----"
sleep 3
yum install -y policycoreutils-gui
clear
echo -n "Would you like to continue with ? " YesNo
read $YesNo
#If installation succeeds, open the necessary ports for the service.
while true
do
        clear
        #Ask the user if they would like to open the ports
        read -p "Would you like to open the ports for Samba service? " YesNo
        case $YesNo in
            Yes|yes) lokkit -s samba  #Opens up samba ports
                     lokkit -s samba-client
                     echo "----Ports have been opened!----"
                     echo ""
                     #Restart iptables
                     service iptables restart
                     break
                     ;;
            No|no) echo "Ports will not be opened."
                   echo ""
                exit 1 ;;
    esac
done
clear
#Calls adduser script to create system user and password
read -p "Enter username: " username
sh ~/bin/adduser.sh $username
    
#Make a backup of the smb.conf file
cp --backup /etc/samba/smb.conf /etc/samba/smb.conf.bak
  
clear
read -p "What is your workgroup? " workgroup
echo "Your workgroup is $workgroup"
get_ip=`hostname -I`
while true; do
    read -p "Current IP address is $get_ip, do you wish to change? " yn
    case $yn in 
        Yes|yes) read -p "Please enter new IP address: " get_ip
                 sed -i "s/${hostallow_line}/ s/${hostallow_previous} */${get_ip}/" /etc/samba/smb.conf         
                 break
                 ;;
        No|no)  echo "You chose no, so we will stick with $get_ip"
                break 
                 ;;
        *) echo "Please enter a Yes or No"
    esac
done
echo -n "What is the share name? " 
read $share
echo -n "What is the share path? "
read $path
#Create the share directory
mkdir -p $path
#Set the correct permissions for the directory
chmod 1755 $path
echo "--------Share directory has been created--------"
#Once the directory is created, copy files into it
while true
  do
    read -p "Enter a file to be copied: " target
    cp $target $path
    echo "-------Files have been copied into the directory-------"
    break
  done
while true
do
    clear
    echo "PLEASE STAND BY WHILE SMB.CONF FILE IS BEING CONFIGURED"
    sleep 3
    echo "#======================= Global Settings =======================" > /etc/samba/smb.conf
    echo "[global]" >> /etc/samba/smb.conf
    echo "workgroup = WORKGROUP" >> /etc/samba/smb.conf
    echo "hosts allow = $get_ip" >> /etc/samba/smb.conf
    echo "server string = Samba Server Version %v" >> /etc/samba/smb.conf
    echo "wins support = yes" >> /etc/samba/smb.conf
    echo "dns proxy = no" >> /etc/samba/smb.conf  
    
    echo "#### Debugging/Accounting ####" >> /etc/samba/smb.conf
    echo "log file = /var/log/samba/log.%m" >> /etc/samba/smb.conf
    echo "max log size = 1000" >> /etc/samba/smb.conf
    echo "syslog = 0" >> /etc/samba/smb.conf
    echo "panic action = /usr/share/samba/panic-action %d" >> /etc/samba/smb.conf
    
    echo "####### Authentication #######" >> /etc/samba/smb.conf
    echo "security = user" >> /etc/samba/smb.conf
    
    
    echo "#======================= Share Definitions =======================" >> /etc/samba/smb.conf
    echo "[homes]" >> /etc/samba/smb.conf
    
    echo "comment = Home Directories" >> /etc/samba/smb.conf
    echo "browseable = yes" >> /etc/samba/smb.conf
    echo "guest ok = yes" >> /etc/samba/smb.conf
    echo "read only = no" >> /etc/samba/smb.conf
    echo "create mask = 0775" >> /etc/samba/smb.conf
    echo "directory mask = 0775" >> /etc/samba/smb.conf
    echo "writeable = yes" >> /etc/samba/smb.conf
    
    
    echo "[$share]" >> /etc/samba/smb.conf
    echo "path = $path" >> /etc/samba/smb.conf
    echo "guest ok = yes" >> /etc/samba/smb.conf
    echo "browseable = yes" >> /etc/samba/smb.conf
    echo "read only = no" >> /etc/samba/smb.conf
    echo "create mask = 0777" >> /etc/samba/smb.conf
    echo "directory mask = 0777" >> /etc/samba/smb.conf
    echo "writeable = yes" >> /etc/samba/smb.conf
    break
done
    
#After configuring the smb.conf file, restart Samba services and make the services survive a reboot
while true
do
    clear
    echo "Services are being restarted and chkconfig'd"
    sleep 3
    /etc/init.d/smb restart
    /etc/init.d/nmb restart
    /etc/init.d/winbind restart
    chkconfig smb on
    chkconfig nmb on
    chkconfig winbind on
    break
done
    
# Set appropriate SELinux labels for the share    
if [ $? -eq 0 ]
then        
        clear
        echo "Setting SeLinux. This make take a while. Please Stand by."
        chcon -R -t samba_share_t $path
        semanage fcontext -a -t samba_share_t $path
        echo "SELinux has been completed."
else
        echo "Failed to make SELinux changes"
        exit 1
fi
# Set the appropriate SELinux booleans for the share
if [ $? -eq 0 ]
then
        echo "Please be patient as booleans will now be set for the Samba share"
        setsebool -P samba_enable_home_dirs 1
        setsebool -P samba_export_all_rw 1
        echo "-----Booleans have been set successfully-----"
else
        echo "Failed to set booleans"
fi
clear
#Test the share on the host system
smbclient -L $get_ip -U $username
if [[ $? = 0 ]]
then
        clear
        echo "Samba has been successfully installed and configure."
        echo "Have a great day!!"
fi

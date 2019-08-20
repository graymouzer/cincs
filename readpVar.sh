message="Does this look right to you"
echo $message
read -p "$message" foo
curbool=boo_coo_doo_foo
declare -a goo
i=0
goo[$i]=`echo $curbool=1`
echo ${goo[$i]}

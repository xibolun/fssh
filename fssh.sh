#!/bin/bash
####Fast parallel remote command runner. ~120 hosts in ~10s; with fast-ssh options, ~2-3s.
####by laijingli2006@gmail.com
####2014/11/27

work_dir=$(pwd)
script_dir=$(cd "$(dirname "$0")" && pwd)
tmp_dir=$work_dir/tmp
log_dir=$work_dir/log
current_time="date +%Y-%m-%d_%H:%M:%S"

list_file="$work_dir/ip_list_servers.txt"
cmd_inline=""
gray_ip=""
gray_first="0"
env_file="$work_dir/.fssh_env"
transfer_src=""
transfer_dst=""
list_file_from_default="1"

usage() {
   echo "Usage: $0 [-f ip_list_file] [-i command] [-g ip] [-s src -d dst]" >&2
}

die() {
   echo "$1" >&2
   exit 1
}

while getopts ":f:i:g:s:d:" opt; do
   case $opt in
      f)
         list_file="$OPTARG"
         list_file_from_default="0"
         ;;
      i)
         cmd_inline="$OPTARG"
         ;;
      g)
         gray_ip="$OPTARG"
         ;;
      s)
         transfer_src="$OPTARG"
         ;;
      d)
         transfer_dst="$OPTARG"
         ;;
      \?)
         usage
         exit 1
         ;;
      :)
         if [ "$OPTARG" == "g" ] ;then
            gray_first="1"
         else
            die "Option -$OPTARG requires a value."
         fi
         ;;
   esac
done
shift $((OPTIND - 1))

if [ -n "$transfer_src" ] || [ -n "$transfer_dst" ] ;then
   if [ -z "$transfer_src" ] || [ -z "$transfer_dst" ] ;then
      die "Both -s and -d are required for file transfer."
   fi
   if [ ! -e "$transfer_src" ] ;then
      die "Transfer source not found: $transfer_src"
   fi
fi

if [ "$list_file_from_default" == "1" ] && [ ! -f "$list_file" ] && [ -f "$script_dir/ip_list_servers.txt" ] ;then
   list_file="$script_dir/ip_list_servers.txt"
fi
if [ ! -f "$list_file" ] ;then
   die "IP list file not found: $list_file"
fi

mkdir -p "$tmp_dir" "$log_dir"
list2=$(cat "$list_file")
if [ "$gray_first" == "1" ] && [ -z "$gray_ip" ] ;then
  gray_ip=$(echo "$list2" | awk 'NF{print; exit}')
fi
if [ -n "$gray_ip" ] ;then
  echo "$list2" | grep -Fxq "$gray_ip"
  if [ $? != 0 ] ;then
    die "Gray IP not found in list file: $gray_ip"
  fi
  list="$gray_ip"
else
  list=$list2
fi


####Command file path. Writing commands to a file avoids quoting/escaping issues.
cmd=$work_dir/remote_cmd.txt
cmd_mode="file"
if [ -n "$cmd_inline" ] ;then
    cmd="$cmd_inline"
    cmd_mode="inline"
fi

if [ "$cmd_mode" == "file" ] && [ ! -f "$cmd" ] && [ -f "$script_dir/remote_cmd.txt" ] ;then
   cmd="$script_dir/remote_cmd.txt"
fi

if [ "$cmd_mode" == "file" ] && [ ! -f "$cmd" ] ;then
   if [ -n "$transfer_src" ] ;then
      cmd_mode="none"
   else
      die "Command file not found: $cmd"
   fi
fi

####Load SSH user/password config
if [ ! -f "$env_file" ] && [ -f "$script_dir/.fssh_env" ] ;then
   env_file="$script_dir/.fssh_env"
fi
if [ -f "$env_file" ] ;then
   source $env_file
else
   die "Missing $env_file (remote_ssh_user/remote_ssh_user_pass)."
fi

####SSH options
ssh_options="  -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "
if [ -n "$remote_ssh_options" ] ;then
   ssh_options="$ssh_options $remote_ssh_options"
fi
if [ -n "$remote_ssh_user_pass" ] ;then
  ssh_cmd=(/usr/bin/sshpass -p"$remote_ssh_user_pass" /usr/bin/ssh)
else
  ssh_cmd=(/usr/bin/ssh)
fi
ssh_cmd+=($ssh_options)

if [ -n "$remote_ssh_user_pass" ] ;then
   scp_cmd=(/usr/bin/sshpass -p"$remote_ssh_user_pass" /usr/bin/scp)
else
   scp_cmd=(/usr/bin/scp)
fi
scp_cmd+=($ssh_options)


####Init pid/ip arrays and counter
pids=()
pid_exist_value=()
ips=()
num=0
for ip in $list ;do
   if [ -n "$transfer_src" ] ;then
      scp_flags=()
      if [ -d "$transfer_src" ] ;then
         scp_flags=(-r)
      fi
      if [ "$cmd_mode" == "inline" ] ;then
         ("${scp_cmd[@]}" "${scp_flags[@]}" "$transfer_src" ${remote_ssh_user}@$ip:"$transfer_dst" \
            && "${ssh_cmd[@]}" ${remote_ssh_user}@$ip "$cmd") > $tmp_dir/$ip.log 2>&1 &
      elif [ "$cmd_mode" == "file" ] ;then
         ("${scp_cmd[@]}" "${scp_flags[@]}" "$transfer_src" ${remote_ssh_user}@$ip:"$transfer_dst" \
            && "${ssh_cmd[@]}" ${remote_ssh_user}@$ip bash < $cmd) > $tmp_dir/$ip.log 2>&1 &
      else
         ("${scp_cmd[@]}" "${scp_flags[@]}" "$transfer_src" ${remote_ssh_user}@$ip:"$transfer_dst") > $tmp_dir/$ip.log 2>&1 &
      fi
   else
        if [ "$cmd_mode" == "inline" ] ;then
           "${ssh_cmd[@]}" ${remote_ssh_user}@$ip "$cmd" > $tmp_dir/$ip.log 2>&1 &
      elif [ "$cmd_mode" == "file" ] ;then
          "${ssh_cmd[@]}" ${remote_ssh_user}@$ip bash < $cmd > $tmp_dir/$ip.log 2>&1 &
      else
          echo "No command specified" > $tmp_dir/$ip.log 2>&1 &
      fi
   fi
  pids[$num]=$!
  pid_exist_value[$num]=255
  ips[$num]=$ip
  num=$(($num+1))
done

echo ============results report:================
pids_length=${#pids[@]}
echo pids_length:${pids_length}

cmd_execute_start_time=`$current_time`
echo $cmd_execute_start_time execute reslut check loop begin:


array_check () {
   for i in `seq 0 $((${#pids[@]} - 1))` ;do
      if [ ${pids[$i]} == 0 ] ;then
         echo NULL >/dev/null
      else
         ls /proc | grep  ^${pids[$i]}$ 2>&1 >/dev/null
         pidstatus=$?
         if [ $pidstatus != 0 ] ;then
            echo
            echo  "****************************** remote screen results for pids[${pids[$i]}]  ips[${ips[$i]}] ********************************"
            wait ${pids[$i]}
            cmd_excute_status=$?
            if [ ${cmd_excute_status} == 0 ] ;then
               echo -e "\033[32m\033[05mSUCCESS\033[0m"
               printf "\033[32m\033[05m"
               cat "$tmp_dir/${ips[$i]}.log"
               printf "\033[0m\n"
               pid_exist_value[$i]=0
               complete_num_success=$((${complete_num_success}+1))
            else
               echo -e "\033[31m\033[05mFAILURE\033[0m"
               printf "\033[31m\033[05m"
               cat "$tmp_dir/${ips[$i]}.log"
               printf "\033[0m\n"
            fi
            pids[$i]=0
            ips[$i]=0
            return 200
            break
         fi
      fi
 done
}


complete_num=0
while [ ${complete_num} != ${pids_length} ] ;do
   for ((j=0;j<${pids_length};j++)) ;do
      array_check 
      if [ $? == 200 ] ;then
         complete_num=$((${complete_num}+1))
         echo -e "\033[35m\033[05m`$current_time` Report: complete_success_tasks/complete_tasks/total_tasks:[${complete_num_success}/${complete_num}/${pids_length}]\033[0m"
      fi
   done
done

cmd_execute_end_time=`$current_time`
echo
echo start_at: $cmd_execute_start_time
echo end_at: $cmd_execute_end_time
echo
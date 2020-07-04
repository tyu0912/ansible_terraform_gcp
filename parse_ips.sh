generate_new_stack () {

    if [[ ! -z $4 ]]
    then
        instance_counts="instance_count=$4"
    fi

    terraform apply -var username=$1 -var public_key=$2 -var credentials_file=$3 $instance_counts
}

generate_new_ansible_ini () {
    file="test.ini"
    rm $file

    ips=$(terraform output -json ip)
    ips=${ips/[/""}
    ips=${ips/]/""}

    IFS=',' read -ra ADDR <<< "$ips"
    for i in "${ADDR[@]}"; do
        echo "$i ansible_user=$1 ansible_ssh_private_key_file=$2 host_key_checking=False" >> $file
    done
}

get_load_balancer_ip () {
    ip=$(terraform show | grep ip_address | cut -d '"' -f 2)
    echo "Finished. Try `curl http://$ip/` to test"
}

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "This script is to use Terraform and Ansible to deploy a load-balanced API"
      echo " "
      echo "Example run: bash run.sh [options]"
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-p, --public_key=PATH     path of the public key"
      echo "-q, --private_key=PATH    path of the private key"
      echo "-u, --username=STR        name of the account on instances"
      echo "-q, --credentials=PATH    gcp service account json file"
      exit 0
      ;;
    -p|--public_key)
      shift
      if test $# -gt 0; then
        export PUBLICKEY=$1
      else
        echo "no public key location specified"
        exit 1
      fi
      shift
      ;;
    -q|--private_key)
      shift
      if test $# -gt 0; then
        export PRIVATEKEY=$1
      else
        echo "no private key location specified"
        exit 1
      fi
      shift
      ;;
    -u|--username)
      shift
      if test $# -gt 0; then
        export USERNAME=$1
      else
        echo "no private key location specified"
        exit 1
      fi
      shift
      ;;
    -c|--credentials)
      shift
      if test $# -gt 0; then
        export CREDENTIALS=$1
      else
        echo "no private key location specified"
        exit 1
      fi
      shift
      esac
done

if [[ -z $USERNAME ]] ||  [[ -z $PUBLICKEY ]] || [[ -z $CREDENTIALS ]] || [[ -z $PRIVATEKEY ]]
then
    echo "A required variable seems to be missing. Run -h argument to see what is required"
    exit 1
fi

generate_new_stack $USERNAME $PUBLICKEY $CREDENTIALS
generate_new_ansible_ini $USERNAME $PRIVATEKEY
get_load_balancer_ip

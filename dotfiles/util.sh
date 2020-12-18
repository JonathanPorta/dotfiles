#!/bin/zsh


function externaldns () {
  # OpenDNS
  openDNS=("208.67.222.222" "208.67.220.220" "208.67.222.123" "208.67.220.123")
  for openDnsResolver in "${openDNS[@]}"; do
    dig $1 @$openDnsResolver -p 443 +short
  done

  # Quad9
  dig $1 @9.9.9.9 -p 9953 +short

  # Unlocator
  unlocator=("185.37.37.37" "185.37.39.39")
  for unlocatorResolver in "${unlocator[@]}"; do
    dig $1 @$unlocatorResolver -p 54 +short
  done

  # Smart DNS
  smartDNS=("23.21.43.50" "54.229.171.243")
  for smartDnsResolver in "${smartDNS[@]}"; do
    dig $1 @$smartDnsResolver -p 1512 +short
  done
}


function curlr () {
  D=$1 V=$2 H=$3 && curl -vso /dev/null --resolve $D:443:$V -H 'x-tb-debug' "https://$D$H"
}
